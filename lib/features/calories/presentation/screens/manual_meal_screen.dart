import 'package:cal_scanner/app_widgets/buttons/app_button.dart';
import 'package:cal_scanner/app_widgets/buttons/back_button.dart';
import 'package:cal_scanner/core/di/service_locator.dart';
import 'package:cal_scanner/core/extensions/capital_first_extension.dart';
import 'package:cal_scanner/features/calories/data/datasources/food_remote_datasource.dart';
import 'package:cal_scanner/features/calories/domain/entities/food.dart';
import 'package:cal_scanner/features/calories/presentation/cubit/food_log_cubit.dart';
import 'package:cal_scanner/features/calories/presentation/widgets/macros_card.dart';
import 'package:cal_scanner/features/calories/presentation/widgets/meal_ingredients_editor.dart';
import 'package:cal_scanner/theme/app_colors.dart';
import 'package:cal_scanner/theme/app_typography.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' hide VerticalDivider;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ManualMealScreen extends StatefulWidget {
  const ManualMealScreen({super.key});

  @override
  State<ManualMealScreen> createState() => _ManualMealScreenState();
}

class _ManualMealScreenState extends State<ManualMealScreen> {
  final TextEditingController _aiDescriptionController =
      TextEditingController();
  final TextEditingController _mealNameController = TextEditingController();
  final TextEditingController _manualCaloriesController =
      TextEditingController(text: '0');
  final TextEditingController _manualProteinController =
      TextEditingController(text: '0');
  final TextEditingController _manualCarbsController =
      TextEditingController(text: '0');
  final TextEditingController _manualFatController =
      TextEditingController(text: '0');

  List<FoodIngredient> _ingredients = [];
  bool _isGeneratingAi = false;
  String? _aiError;
  bool _isLogging = false;

  @override
  void dispose() {
    _aiDescriptionController.dispose();
    _mealNameController.dispose();
    _manualCaloriesController.dispose();
    _manualProteinController.dispose();
    _manualCarbsController.dispose();
    _manualFatController.dispose();
    super.dispose();
  }

  double get _totalCalories {
    if (_ingredients.isNotEmpty) {
      return _ingredients.fold(0.0, (sum, i) => sum + i.calories);
    }
    return double.tryParse(
          _manualCaloriesController.text.trim().replaceAll(',', '.'),
        ) ??
        0.0;
  }

  double get _totalProtein {
    if (_ingredients.isNotEmpty) {
      return _ingredients.fold(0.0, (sum, i) => sum + i.protein);
    }
    return double.tryParse(
          _manualProteinController.text.trim().replaceAll(',', '.'),
        ) ??
        0.0;
  }

  double get _totalCarbs {
    if (_ingredients.isNotEmpty) {
      return _ingredients.fold(0.0, (sum, i) => sum + i.carbs);
    }
    return double.tryParse(
          _manualCarbsController.text.trim().replaceAll(',', '.'),
        ) ??
        0.0;
  }

  double get _totalFat {
    if (_ingredients.isNotEmpty) {
      return _ingredients.fold(0.0, (sum, i) => sum + i.fat);
    }
    return double.tryParse(
          _manualFatController.text.trim().replaceAll(',', '.'),
        ) ??
        0.0;
  }

  double get _totalQuantity {
    if (_ingredients.isNotEmpty) {
      return _ingredients.fold(0.0, (sum, i) => sum + i.quantity);
    }
    return 100.0;
  }

  Future<void> _generateWithAi() async {
    final desc = _aiDescriptionController.text.trim();
    if (desc.isEmpty) {
      setState(() {
        _aiError =
            'Describe what you ate (e.g. "Arroz con pollo, media palta y ensalada").';
      });
      return;
    }

    setState(() {
      _isGeneratingAi = true;
      _aiError = null;
    });

    final result = await sl<FoodRemoteDataSource>().estimateFoodFromText(desc);

    if (!mounted) return;
    result.fold(
      (failure) {
        setState(() {
          _isGeneratingAi = false;
          _aiError = failure.message;
        });
      },
      (food) {
        setState(() {
          _isGeneratingAi = false;
          _mealNameController.text = food.name;
          _ingredients = List<FoodIngredient>.from(food.ingredients);
          _syncManualControllersFromTotals();
        });
      },
    );
  }

  void _syncManualControllersFromTotals() {
    _manualCaloriesController.text = _totalCalories.round().toString();
    _manualProteinController.text = _totalProtein.round().toString();
    _manualCarbsController.text = _totalCarbs.round().toString();
    _manualFatController.text = _totalFat.round().toString();
  }

  Future<void> _handleLogMeal() async {
    if (_isLogging) return;
    final name = _mealNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter a meal name (or generate one with AI).',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.kWhite),
          ),
          backgroundColor: AppColors.kBlack,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLogging = true);

    final cal = _totalCalories;
    final prot = _totalProtein;
    final carbs = _totalCarbs;
    final fat = _totalFat;
    final qty = _totalQuantity > 0 ? _totalQuantity : 100.0;

    final finalIngredients = _ingredients.isNotEmpty
        ? _ingredients
        : [
            FoodIngredient(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              name: name,
              quantity: qty,
              servingSize: qty,
              servingUnit: 'g',
              calories: cal,
              protein: prot,
              carbs: carbs,
              fat: fat,
            ),
          ];

    final meal = Food(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      calories: cal,
      protein: prot,
      carbs: carbs,
      fat: fat,
      quantity: qty,
      servingSize: qty,
      servingUnit: 'g',
      baseCalories: cal,
      baseProtein: prot,
      baseCarbs: carbs,
      baseFat: fat,
      timestamp: DateTime.now(),
      isFood: true,
      ingredients: finalIngredients,
    );

    final cubit = context.read<FoodLogCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    await cubit.addMeal(meal);
    if (!mounted) return;

    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Meal logged: ${meal.name.capitalizeFirst()} (${meal.calories.toStringAsFixed(0)} kcal)',
          style: AppTypography.bodyMedium.copyWith(color: Colors.white),
        ),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kScaffold,
      appBar: AppBar(
        backgroundColor: AppColors.kScaffold,
        leading: const AppBackButton(),
        centerTitle: true,
        title: Text(
          'Add Meal Manually',
          style: AppTypography.displaySmall.copyWith(fontSize: 19.sp),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── OPTION A: AI ASSISTED TEXT ENTRY ──────────────────────
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: AppColors.kWhite,
                  borderRadius: BorderRadius.circular(18.r),
                  border: Border.all(
                    color: AppColors.kOrange.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          color: AppColors.kOrange,
                          size: 19.sp,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          'Describe Meal with AI (Optional)',
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.kBlack,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Type what you ate and AI will automatically break down the ingredients, portions, and macros below.',
                      style: AppTypography.bodySmall.copyWith(
                        fontSize: 11.5.sp,
                        color: AppColors.kBlack.withValues(alpha: 0.6),
                      ),
                    ),
                    SizedBox(height: 10.h),
                    TextField(
                      controller: _aiDescriptionController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText:
                            'e.g. Arroz con pollo, media palta y 1 huevo frito',
                        hintStyle: AppTypography.bodySmall.copyWith(
                          color: AppColors.kBlack.withValues(alpha: 0.4),
                        ),
                        filled: true,
                        fillColor: AppColors.kScaffold,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.r),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    if (_aiError != null) ...[
                      SizedBox(height: 6.h),
                      Text(
                        _aiError!,
                        style: TextStyle(color: Colors.red, fontSize: 12.sp),
                      ),
                    ],
                    SizedBox(height: 10.h),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isGeneratingAi ? null : _generateWithAi,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.kOrange,
                          foregroundColor: AppColors.kWhite,
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                        ),
                        icon: _isGeneratingAi
                            ? const CupertinoActivityIndicator(
                                color: Colors.white,
                                radius: 9,
                              )
                            : Icon(Icons.bolt_rounded, size: 19.sp),
                        label: Text(
                          _isGeneratingAi
                              ? 'Analyzing Meal...'
                              : 'Auto-Fill with AI',
                          style: AppTypography.titleSmall.copyWith(
                            color: AppColors.kWhite,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 18.h),

              // ─── OPTION B: MANUAL / EDITABLE DETAILS ───────────────────
              Text(
                'Meal Name',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.kBlack,
                ),
              ),
              SizedBox(height: 6.h),
              TextField(
                controller: _mealNameController,
                decoration: InputDecoration(
                  hintText: 'e.g. Chicken & Rice Bowl',
                  prefixIcon: const Icon(Icons.fastfood_outlined),
                  filled: true,
                  fillColor: AppColors.kWhite,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16.r),
                    borderSide: BorderSide(
                      color: AppColors.kBlack.withValues(alpha: 0.12),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16.r),
                    borderSide: BorderSide(
                      color: AppColors.kBlack.withValues(alpha: 0.12),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 18.h),

              // Live Totals Display
              Center(
                child: Column(
                  children: [
                    Text(
                      _totalCalories.round().toString(),
                      style: const TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF8C00),
                        height: 1,
                      ),
                    ),
                    const Text(
                      'total calories',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 14.h),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.kWhite,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: AppColors.kBlack.withValues(alpha: 0.1),
                  ),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      MacroItem(
                        value: '${_totalProtein.round()}g',
                        label: 'Protein',
                        color: const Color(0xFF4A90D9),
                      ),
                      const VerticalDivider(),
                      MacroItem(
                        value: '${_totalCarbs.round()}g',
                        label: 'Carbs',
                        color: const Color(0xFFF5A623),
                      ),
                      const VerticalDivider(),
                      MacroItem(
                        value: '${_totalFat.round()}g',
                        label: 'Fat',
                        color: const Color(0xFFE05C5C),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 18.h),

              // Ingredients Editor
              MealIngredientsEditor(
                ingredients: _ingredients,
                onIngredientsChanged: (updated) {
                  setState(() {
                    _ingredients = updated;
                    _syncManualControllersFromTotals();
                  });
                },
              ),

              if (_ingredients.isEmpty) ...[
                SizedBox(height: 16.h),
                Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: AppColors.kWhite,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: AppColors.kBlack.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Or Enter Total Macros Directly',
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Row(
                        children: [
                          Expanded(
                            child: _DirectMacroInput(
                              controller: _manualCaloriesController,
                              label: 'Calories',
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: _DirectMacroInput(
                              controller: _manualProteinController,
                              label: 'Protein (g)',
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: _DirectMacroInput(
                              controller: _manualCarbsController,
                              label: 'Carbs (g)',
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: _DirectMacroInput(
                              controller: _manualFatController,
                              label: 'Fat (g)',
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: 24.h),
              AppButton(
                text: 'Log Meal',
                onTap: _handleLogMeal,
              ),
              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectMacroInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;

  const _DirectMacroInput({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      onChanged: onChanged,
      style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 10.5.sp),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 10.h),
        filled: true,
        fillColor: AppColors.kScaffold,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
