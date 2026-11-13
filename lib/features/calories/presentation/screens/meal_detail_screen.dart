import 'dart:io';

import 'package:cal_scanner/app_widgets/buttons/app_button.dart';
import 'package:cal_scanner/app_widgets/buttons/back_button.dart';
import 'package:cal_scanner/core/extensions/capital_first_extension.dart';
import 'package:cal_scanner/core/extensions/context_extension.dart';
import 'package:cal_scanner/core/extensions/widget_extension.dart';
import 'package:cal_scanner/features/calories/presentation/cubit/food_log_cubit.dart';
import 'package:cal_scanner/features/calories/presentation/widgets/macros_card.dart';
import 'package:cal_scanner/features/calories/presentation/widgets/meal_ingredients_editor.dart';
import 'package:cal_scanner/theme/app_colors.dart';
import 'package:cal_scanner/theme/app_typography.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' hide VerticalDivider;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../domain/entities/food.dart';

class MealDetailScreen extends StatefulWidget {
  final Food meal;

  const MealDetailScreen({super.key, required this.meal});

  @override
  State<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends State<MealDetailScreen> {
  late TextEditingController _nameController;
  late List<FoodIngredient> _ingredients;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.meal.name);
    if (widget.meal.ingredients.isNotEmpty) {
      _ingredients = List<FoodIngredient>.from(widget.meal.ingredients);
    } else {
      final qty = widget.meal.quantity > 0 ? widget.meal.quantity : 100.0;
      _ingredients = [
        FoodIngredient(
          id: '${widget.meal.id}_0',
          name: widget.meal.name,
          quantity: qty,
          servingSize:
              widget.meal.servingSize > 0 ? widget.meal.servingSize : qty,
          servingUnit: widget.meal.servingUnit,
          calories: widget.meal.calories,
          protein: widget.meal.protein,
          carbs: widget.meal.carbs,
          fat: widget.meal.fat,
          baseCalories: widget.meal.baseCalories,
          baseProtein: widget.meal.baseProtein,
          baseCarbs: widget.meal.baseCarbs,
          baseFat: widget.meal.baseFat,
        ),
      ];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  double get _totalCalories =>
      _ingredients.fold(0.0, (sum, i) => sum + i.calories);
  double get _totalProtein =>
      _ingredients.fold(0.0, (sum, i) => sum + i.protein);
  double get _totalCarbs => _ingredients.fold(0.0, (sum, i) => sum + i.carbs);
  double get _totalFat => _ingredients.fold(0.0, (sum, i) => sum + i.fat);
  double get _totalQuantity =>
      _ingredients.fold(0.0, (sum, i) => sum + i.quantity);

  void _deleteMeal(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Meal'),
        content: const Text('Are you sure you want to delete this meal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () {
              context.read<FoodLogCubit>().deleteMeal(widget.meal);
              Navigator.pop(dialogContext);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveMealChanges() async {
    if (_isSaving) return;
    final updatedName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : widget.meal.name;

    setState(() => _isSaving = true);

    final totalCal = _totalCalories;
    final totalProt = _totalProtein;
    final totalCarbs = _totalCarbs;
    final totalFat = _totalFat;
    final totalQty = _totalQuantity > 0 ? _totalQuantity : widget.meal.quantity;

    final updatedMeal = widget.meal.copyWith(
      name: updatedName,
      calories: totalCal,
      protein: totalProt,
      carbs: totalCarbs,
      fat: totalFat,
      baseCalories: totalCal,
      baseProtein: totalProt,
      baseCarbs: totalCarbs,
      baseFat: totalFat,
      quantity: totalQty,
      servingSize: totalQty,
      ingredients: _ingredients,
    );

    final cubit = context.read<FoodLogCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    await cubit.updateMeal(updatedMeal);
    if (!mounted) return;

    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Updated: ${updatedMeal.name.capitalizeFirst()} (${updatedMeal.calories.toStringAsFixed(0)} kcal)',
          style: AppTypography.bodyMedium.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.kBlack,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meal = widget.meal;
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: context.colors.surface,
        iconTheme: IconThemeData(color: context.colors.onSurface),
        leading: const AppBackButton(),
        title: Text(
          'Meal Details & Edit',
          style: AppTypography.displaySmall.copyWith(fontSize: 18.sp),
        ),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.delete, color: Colors.red),
            onPressed: () => _deleteMeal(context),
          ).paddingOnly(right: 10),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (meal.imageUrl != null && meal.imageUrl!.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14.r),
                  child: meal.imageUrl!.startsWith('http')
                      ? Image.network(
                          meal.imageUrl!,
                          height: 160.h,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        )
                      : File(meal.imageUrl!).existsSync()
                      ? Image.file(
                          File(meal.imageUrl!),
                          height: 160.h,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : const SizedBox.shrink(),
                ),
                SizedBox(height: 16.h),
              ],

              // Editable Meal Name
              TextField(
                controller: _nameController,
                textAlign: TextAlign.center,
                style: AppTypography.headlineMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  suffixIcon: Icon(
                    Icons.edit_outlined,
                    size: 18.sp,
                    color: AppColors.kBlack.withValues(alpha: 0.45),
                  ),
                  filled: true,
                  fillColor: AppColors.kScaffold,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 10.h,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: 18.h),

              Text(
                _totalCalories.toStringAsFixed(0),
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'calories',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w400,
                ),
              ),

              SizedBox(height: 20.h),

              // Macros card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    MacroItem(
                      value: '${_totalProtein.toStringAsFixed(0)}g',
                      label: 'Protein',
                      color: Colors.blue,
                    ),
                    const VerticalDivider(),
                    MacroItem(
                      value: '${_totalCarbs.toStringAsFixed(0)}g',
                      label: 'Carbs',
                      color: Colors.orange,
                    ),
                    const VerticalDivider(),
                    MacroItem(
                      value: '${_totalFat.toStringAsFixed(0)}g',
                      label: 'Fat',
                      color: Colors.redAccent,
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20.h),

              // Ingredients breakdown & editor
              MealIngredientsEditor(
                ingredients: _ingredients,
                onIngredientsChanged: (updated) {
                  setState(() {
                    _ingredients = updated;
                  });
                },
              ),

              SizedBox(height: 16.h),

              _DetailRow(
                icon: Icons.access_time,
                label: 'Logged',
                value: timeago.format(meal.timestamp),
              ),

              SizedBox(height: 16.h),
              AppButton(
                text: 'Save Changes',
                onTap: _saveMealChanges,
              ),
              SizedBox(height: 16.h),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          Icon(icon, size: 22, color: context.colors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: context.colors.onSurface,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
