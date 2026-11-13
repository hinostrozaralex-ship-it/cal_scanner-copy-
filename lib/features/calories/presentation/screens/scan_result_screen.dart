import 'dart:io';

import 'package:cal_scanner/app_widgets/buttons/app_button.dart';
import 'package:cal_scanner/app_widgets/buttons/back_button.dart';
import 'package:cal_scanner/core/extensions/capital_first_extension.dart';
import 'package:cal_scanner/core/extensions/context_extension.dart';
import 'package:cal_scanner/core/extensions/num_extension.dart';
import 'package:cal_scanner/core/extensions/widget_extension.dart';
import 'package:cal_scanner/features/calories/presentation/widgets/macros_card.dart';
import 'package:cal_scanner/features/calories/presentation/widgets/meal_ingredients_editor.dart';
import 'package:cal_scanner/theme/app_colors.dart';
import 'package:cal_scanner/theme/app_typography.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' hide VerticalDivider;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/entities/food.dart';
import '../cubit/food_log_cubit.dart';
import '../cubit/food_log_state.dart';

class ScanResultScreen extends StatefulWidget {
  final File imageFile;
  const ScanResultScreen({super.key, required this.imageFile});

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> {
  bool _dialogShown = false;
  late File _currentImageFile;
  Food? _meal;
  List<FoodIngredient> _ingredients = [];
  String? _error;
  bool _scanStarted = false;
  bool _isLogging = false;
  double _currentQuantity = 100.0;
  final TextEditingController _quantityController = TextEditingController(
    text: '100',
  );
  final TextEditingController _hintController = TextEditingController();

  void _showDialog(BuildContext context) {
    _dialogShown = true;
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CupertinoAlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 8),
            CupertinoActivityIndicator(radius: 14),
            SizedBox(height: 16),
            Text(
              'Analyzing your food...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 6),
            Text(
              'Identifying dish, ingredients & estimating nutrition',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _dismissDialog(BuildContext context) {
    if (_dialogShown) {
      _dialogShown = false;
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  String _formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  double _stepForMeal(Food meal) {
    final unit = meal.servingUnit.toLowerCase();
    if (unit == 'ml' || unit == 'g' || meal.servingSize >= 25) {
      return 10.0;
    }
    return 0.5;
  }

  void _adjustQuantity(double delta, Food meal) {
    final step = _stepForMeal(meal);
    final minVal = step >= 10.0 ? 5.0 : 0.5;
    final prevQty = _currentQuantity > 0 ? _currentQuantity : 100.0;
    final updated = (_currentQuantity + delta).clamp(minVal, 10000.0);
    final scaleFactor = updated / prevQty;

    setState(() {
      _currentQuantity = updated;
      _quantityController.text = _formatQuantity(updated);
      _quantityController.selection = TextSelection.fromPosition(
        TextPosition(offset: _quantityController.text.length),
      );
      if (_ingredients.isNotEmpty) {
        _ingredients = _ingredients
            .map((ing) => ing.withQuantity(ing.quantity * scaleFactor))
            .toList();
      }
    });
  }

  void _onQuantityTextChanged(String text) {
    final normalized = text.trim().replaceAll(',', '.');
    final parsed = double.tryParse(normalized);
    if (parsed != null && parsed > 0) {
      final prevQty = _currentQuantity > 0 ? _currentQuantity : 100.0;
      final scaleFactor = parsed / prevQty;
      setState(() {
        _currentQuantity = parsed;
        if (_ingredients.isNotEmpty) {
          _ingredients = _ingredients
              .map((ing) => ing.withQuantity(ing.quantity * scaleFactor))
              .toList();
        }
      });
    }
  }

  void _onIngredientsChanged(List<FoodIngredient> updatedIngredients) {
    setState(() {
      _ingredients = updatedIngredients;
      if (_ingredients.isNotEmpty) {
        final totalQty = _ingredients.fold<double>(
          0.0,
          (sum, item) => sum + item.quantity,
        );
        if (totalQty > 0) {
          _currentQuantity = totalQty;
          _quantityController.text = _formatQuantity(totalQty);
        }
      }
    });
  }

  void _handleReanalyzeWithHint() {
    final hint = _hintController.text.trim();
    if (hint.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please write a hint for the AI (e.g. "Arroz con pollo y media palta").',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.kWhite),
          ),
          backgroundColor: AppColors.kBlack,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    context.read<FoodLogCubit>().addMealFromImage(
          _currentImageFile,
          userHint: hint,
        );
  }

  Future<void> _handleTryAgain() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 60,
      );
      if (!mounted) return;
      if (picked != null) {
        final newFile = File(picked.path);
        setState(() {
          _currentImageFile = newFile;
          _meal = null;
          _ingredients = [];
          _error = null;
        });
        context.read<FoodLogCubit>().addMealFromImage(newFile);
      } else {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  double _calculatedCalories(Food meal) {
    if (_ingredients.isNotEmpty) {
      return _ingredients.fold(0.0, (sum, i) => sum + i.calories);
    }
    final baseServingSize = meal.servingSize > 0 ? meal.servingSize : 100.0;
    return meal.baseCalories * (_currentQuantity / baseServingSize);
  }

  double _calculatedProtein(Food meal) {
    if (_ingredients.isNotEmpty) {
      return _ingredients.fold(0.0, (sum, i) => sum + i.protein);
    }
    final baseServingSize = meal.servingSize > 0 ? meal.servingSize : 100.0;
    return meal.baseProtein * (_currentQuantity / baseServingSize);
  }

  double _calculatedCarbs(Food meal) {
    if (_ingredients.isNotEmpty) {
      return _ingredients.fold(0.0, (sum, i) => sum + i.carbs);
    }
    final baseServingSize = meal.servingSize > 0 ? meal.servingSize : 100.0;
    return meal.baseCarbs * (_currentQuantity / baseServingSize);
  }

  double _calculatedFat(Food meal) {
    if (_ingredients.isNotEmpty) {
      return _ingredients.fold(0.0, (sum, i) => sum + i.fat);
    }
    final baseServingSize = meal.servingSize > 0 ? meal.servingSize : 100.0;
    return meal.baseFat * (_currentQuantity / baseServingSize);
  }

  Future<void> _handleLogMeal() async {
    final meal = _meal;
    if (meal == null || _isLogging) return;

    setState(() {
      _isLogging = true;
    });

    final totalCal = _calculatedCalories(meal);
    final totalProt = _calculatedProtein(meal);
    final totalCarbs = _calculatedCarbs(meal);
    final totalFat = _calculatedFat(meal);

    final loggedMeal = meal.copyWith(
      quantity: _currentQuantity,
      servingSize: _currentQuantity > 0 ? _currentQuantity : meal.servingSize,
      calories: totalCal,
      protein: totalProt,
      carbs: totalCarbs,
      fat: totalFat,
      baseCalories: totalCal,
      baseProtein: totalProt,
      baseCarbs: totalCarbs,
      baseFat: totalFat,
      ingredients: _ingredients,
    );

    final cubit = context.read<FoodLogCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    await cubit.addMeal(loggedMeal);
    if (!mounted) return;

    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Meal logged: ${loggedMeal.name.capitalizeFirst()} (${loggedMeal.calories.toStringAsFixed(0)} kcal)',
          style: AppTypography.bodyMedium.copyWith(color: Colors.white),
        ),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _currentImageFile = widget.imageFile;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _scanStarted) return;
      _scanStarted = true;
      context.read<FoodLogCubit>().addMealFromImage(_currentImageFile);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.read<FoodLogCubit>().state;
    if (state.isScanning && !_dialogShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showDialog(context);
      });
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _hintController.dispose();
    if (_dialogShown) {
      try {
        Navigator.of(context, rootNavigator: true).pop();
      } catch (_) {
        // no-op
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FoodLogCubit, FoodLogState>(
      listener: (context, state) {
        if (state.isScanning && !_dialogShown) {
          _showDialog(context);
        } else if (!state.isScanning && _dialogShown) {
          _dismissDialog(context);

          if (state.scannedMeal != null) {
            final detected = state.scannedMeal!;
            final initialQty =
                detected.servingSize > 0 ? detected.servingSize : 100.0;
            setState(() {
              _meal = detected;
              _ingredients = List<FoodIngredient>.from(detected.ingredients);
              _currentQuantity = initialQty;
              _quantityController.text = _formatQuantity(initialQty);
              _error = null;
            });
            return;
          }

          if (state.error != null) {
            setState(() {
              _error = state.error;
            });
          }
        }
      },
      builder: (context, state) {
        final meal = _meal;
        final calcCalories = meal != null ? _calculatedCalories(meal) : 0.0;
        final calcProtein = meal != null ? _calculatedProtein(meal) : 0.0;
        final calcCarbs = meal != null ? _calculatedCarbs(meal) : 0.0;
        final calcFat = meal != null ? _calculatedFat(meal) : 0.0;

        return Scaffold(
          backgroundColor: context.colors.surface,
          appBar: AppBar(
            backgroundColor: context.colors.surface,
            leading: const AppBackButton(),
            centerTitle: false,
          ),
          body: SafeArea(
            child: Column(
              children: [
                if (_error != null) ...[
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 24,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 48,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: _handleTryAgain,
                              icon: const Icon(Icons.camera_alt_outlined),
                              label: const Text('Try Again'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ] else if (meal != null && !meal.isFood) ...[
                  // ─── NON-EDIBLE FLOW (isFood == false) ─────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24.w,
                        vertical: 16.h,
                      ),
                      child: Column(
                        children: [
                          Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20.r),
                              child: _currentImageFile.existsSync()
                                  ? Image.file(
                                      _currentImageFile,
                                      height: 200.h,
                                      width: 180.w,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      height: 200.h,
                                      width: 180.w,
                                      color: AppColors.kPrimaryGrey,
                                      child: const Icon(
                                        Icons.image_not_supported_outlined,
                                        size: 48,
                                      ),
                                    ),
                            ),
                          ),
                          SizedBox(height: 20.h),
                          Text(
                            meal.name.capitalizeFirst(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 20.h),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(20.w),
                            decoration: BoxDecoration(
                              color: AppColors.kOrange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(18.r),
                              border: Border.all(
                                color: AppColors.kOrange.withValues(alpha: 0.35),
                                width: 1.2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.sentiment_very_satisfied_rounded,
                                  color: AppColors.kOrange,
                                  size: 38.sp,
                                ),
                                SizedBox(height: 12.h),
                                Text(
                                  'Not Edible!',
                                  style: AppTypography.titleMedium.copyWith(
                                    color: AppColors.kOrange,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16.sp,
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                Text(
                                  meal.nonFoodMessage ??
                                      "That doesn't look like food! Please scan an edible meal or drink.",
                                  textAlign: TextAlign.center,
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontSize: 14.5.sp,
                                    color: AppColors.kBlack.withValues(
                                      alpha: 0.85,
                                    ),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 18.h),
                          _AiRefineHintCard(
                            controller: _hintController,
                            onReanalyze: _handleReanalyzeWithHint,
                          ),
                          SizedBox(height: 20.h),
                          AppButton(
                            text: 'Try Another Photo',
                            onTap: _handleTryAgain,
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else if (meal != null) ...[
                  // ─── EDIBLE FLOW (isFood == true) ──────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: _currentImageFile.existsSync()
                                  ? Image.file(
                                      _currentImageFile,
                                      height: 130.h,
                                      width: 120.w,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      height: 130.h,
                                      width: 120.w,
                                      color: AppColors.kPrimaryGrey,
                                      child: const Icon(
                                        Icons.fastfood_outlined,
                                        size: 40,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              meal.name.capitalizeFirst(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          14.kH,
                          Text(
                            calcCalories.toStringAsFixed(0),
                            style: const TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF8C00),
                              height: 1,
                            ),
                          ),
                          const Text(
                            'calories',
                            style: TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 18),
                          _FoodMacros(
                            protein: calcProtein,
                            carbs: calcCarbs,
                            fat: calcFat,
                          ),
                          const SizedBox(height: 16),

                          // AI Suggestion / Refine Card
                          Padding(
                            padding: pagePadding,
                            child: _AiRefineHintCard(
                              controller: _hintController,
                              onReanalyze: _handleReanalyzeWithHint,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Ingredients Breakdown & Editor
                          Padding(
                            padding: pagePadding,
                            child: MealIngredientsEditor(
                              ingredients: _ingredients,
                              onIngredientsChanged: _onIngredientsChanged,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Interactive Total Portion Selector
                          Padding(
                            padding: pagePadding,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 14.h,
                              ),
                              decoration: BoxDecoration(
                                color: context.colors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: context.colors.outlineVariant,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Total Meal Weight / Portion (Scales all items)',
                                    style: AppTypography.bodySmall.copyWith(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.kBlack.withValues(
                                        alpha: 0.65,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 10.h),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _PortionStepButton(
                                        icon: Icons.remove,
                                        onTap: () => _adjustQuantity(
                                          -_stepForMeal(meal),
                                          meal,
                                        ),
                                      ),
                                      SizedBox(width: 12.w),
                                      SizedBox(
                                        width: 95.w,
                                        child: TextField(
                                          controller: _quantityController,
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                          textAlign: TextAlign.center,
                                          onChanged: _onQuantityTextChanged,
                                          style: AppTypography.titleMedium
                                              .copyWith(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16.sp,
                                          ),
                                          decoration: InputDecoration(
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                              horizontal: 8.w,
                                              vertical: 10.h,
                                            ),
                                            filled: true,
                                            fillColor: AppColors.kScaffold,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12.r),
                                              borderSide: BorderSide.none,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 12.w),
                                      _PortionStepButton(
                                        icon: Icons.add,
                                        onTap: () => _adjustQuantity(
                                          _stepForMeal(meal),
                                          meal,
                                        ),
                                      ),
                                      SizedBox(width: 10.w),
                                      Text(
                                        meal.servingUnit,
                                        style:
                                            AppTypography.titleMedium.copyWith(
                                          color: AppColors.kOrange,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 22),
                          Padding(
                            padding: pagePadding,
                            child: AppButton(
                              text: 'Log Meal',
                              onTap: _handleLogMeal,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AiRefineHintCard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onReanalyze;

  const _AiRefineHintCard({
    required this.controller,
    required this.onReanalyze,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.kWhite,
        borderRadius: BorderRadius.circular(16.r),
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
                size: 17.sp,
                color: AppColors.kOrange,
              ),
              SizedBox(width: 6.w),
              Text(
                'Wrong or missing items? Give AI a hint',
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.kBlack,
                  fontSize: 13.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 13.sp,
                    color: AppColors.kBlack,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. Es arroz con pollo y lleva media palta',
                    hintStyle: AppTypography.bodySmall.copyWith(
                      fontSize: 12.sp,
                      color: AppColors.kBlack.withValues(alpha: 0.45),
                    ),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 10.h,
                    ),
                    filled: true,
                    fillColor: AppColors.kScaffold,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              ElevatedButton(
                onPressed: onReanalyze,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.kOrange,
                  foregroundColor: AppColors.kWhite,
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 10.h,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  'Refine',
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.kWhite,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5.sp,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PortionStepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _PortionStepButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        width: 38.w,
        height: 38.w,
        decoration: BoxDecoration(
          color: AppColors.kBlack,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Icon(
          icon,
          color: AppColors.kWhite,
          size: 20.sp,
        ),
      ),
    );
  }
}

class _FoodMacros extends StatelessWidget {
  final double protein;
  final double carbs;
  final double fat;

  const _FoodMacros({
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: pagePadding,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.outlineVariant),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              MacroItem(
                value: '${protein.round()}g',
                label: 'Protein',
                color: const Color(0xFF4A90D9),
              ),
              const VerticalDivider(),
              MacroItem(
                value: '${carbs.round()}g',
                label: 'Carbs',
                color: const Color(0xFFF5A623),
              ),
              const VerticalDivider(),
              MacroItem(
                value: '${fat.round()}g',
                label: 'Fat',
                color: const Color(0xFFE05C5C),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
