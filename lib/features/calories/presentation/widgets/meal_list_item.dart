import 'dart:io';

import 'package:cal_scanner/app_widgets/buttons/app_button.dart';
import 'package:cal_scanner/core/extensions/capital_first_extension.dart';
import 'package:cal_scanner/core/extensions/context_extension.dart';
import 'package:cal_scanner/features/calories/presentation/cubit/food_log_cubit.dart';
import 'package:cal_scanner/theme/app_colors.dart';
import 'package:cal_scanner/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../domain/entities/food.dart';

Future<void> showEditMealBottomSheet(BuildContext context, Food meal) {
  final cubit = context.read<FoodLogCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => BlocProvider.value(
      value: cubit,
      child: EditMealBottomSheet(meal: meal),
    ),
  );
}

class MealListItem extends StatelessWidget {
  final Food meal;
  final String timeFormatted;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const MealListItem({
    super.key,
    required this.meal,
    required this.timeFormatted,
    this.onDelete,
    this.onTap,
  });

  String _formatQty(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () => showEditMealBottomSheet(context, meal),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border.all(color: context.colors.outlineVariant),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _MealThumbnail(imageUrl: meal.imageUrl, size: 46.w),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          meal.name.capitalizeFirst(),
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.displaySmall.copyWith(
                            fontSize: 16.sp,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 3.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.kScaffold,
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          '${_formatQty(meal.quantity)} ${meal.servingUnit} • $timeFormatted',
                          style: AppTypography.bodySmall.copyWith(
                            fontSize: 11.5.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.kBlack.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Row(
                    children: [
                      Text(
                        '${meal.calories.toStringAsFixed(0)} kcal',
                        style: AppTypography.titleSmall.copyWith(
                          color: AppColors.kOrange,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.sp,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          'P: ${meal.protein.toStringAsFixed(0)}g  •  C: ${meal.carbs.toStringAsFixed(0)}g  •  F: ${meal.fat.toStringAsFixed(0)}g',
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall.copyWith(
                            fontSize: 12.sp,
                            color: AppColors.kBlack.withValues(alpha: 0.65),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (onDelete != null) ...[
              SizedBox(width: 6.w),
              IconButton(
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                  size: 20.sp,
                ),
                tooltip: 'Delete meal',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EditMealBottomSheet extends StatefulWidget {
  final Food meal;

  const EditMealBottomSheet({super.key, required this.meal});

  @override
  State<EditMealBottomSheet> createState() => _EditMealBottomSheetState();
}

class _EditMealBottomSheetState extends State<EditMealBottomSheet> {
  late double _quantity;
  late final TextEditingController _quantityController;
  late final TextEditingController _caloriesController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatController;

  @override
  void initState() {
    super.initState();
    _quantity = widget.meal.quantity > 0
        ? widget.meal.quantity
        : (widget.meal.servingSize > 0 ? widget.meal.servingSize : 100.0);

    _quantityController = TextEditingController(text: _formatNumber(_quantity));
    _caloriesController = TextEditingController(
      text: widget.meal.calories.toStringAsFixed(0),
    );
    _proteinController = TextEditingController(
      text: widget.meal.protein.toStringAsFixed(1),
    );
    _carbsController = TextEditingController(
      text: widget.meal.carbs.toStringAsFixed(1),
    );
    _fatController = TextEditingController(
      text: widget.meal.fat.toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  String _formatNumber(double val) {
    if (val == val.roundToDouble()) {
      return val.toInt().toString();
    }
    return val.toStringAsFixed(1);
  }

  double _stepSize() {
    final unit = widget.meal.servingUnit.toLowerCase();
    if (unit == 'ml' || unit == 'g' || widget.meal.servingSize >= 25) {
      return 10.0;
    }
    return 0.5;
  }

  void _recalculateFromPortion(double newQuantity, {bool updateQtyField = true}) {
    final baseServing =
        widget.meal.servingSize > 0 ? widget.meal.servingSize : 100.0;
    final ratio = newQuantity / baseServing;

    setState(() {
      _quantity = newQuantity;
      if (updateQtyField) {
        _quantityController.text = _formatNumber(newQuantity);
      }
      _caloriesController.text =
          (widget.meal.baseCalories * ratio).toStringAsFixed(0);
      _proteinController.text =
          (widget.meal.baseProtein * ratio).toStringAsFixed(1);
      _carbsController.text =
          (widget.meal.baseCarbs * ratio).toStringAsFixed(1);
      _fatController.text = (widget.meal.baseFat * ratio).toStringAsFixed(1);
    });
  }

  void _stepPortion(double delta) {
    final minVal = _stepSize() >= 10.0 ? 5.0 : 0.5;
    final next = (_quantity + delta).clamp(minVal, 10000.0);
    _recalculateFromPortion(next);
  }

  double _parseField(TextEditingController controller, double fallback) {
    final parsed = double.tryParse(
      controller.text.trim().replaceAll(',', '.'),
    );
    if (parsed == null || parsed < 0 || parsed.isNaN || parsed.isInfinite) {
      return fallback;
    }
    return parsed;
  }

  Future<void> _saveChanges() async {
    final updatedQty = _parseField(_quantityController, _quantity);
    final updatedCalories = _parseField(
      _caloriesController,
      widget.meal.calories,
    );
    final updatedProtein = _parseField(_proteinController, widget.meal.protein);
    final updatedCarbs = _parseField(_carbsController, widget.meal.carbs);
    final updatedFat = _parseField(_fatController, widget.meal.fat);

    final updatedMeal = widget.meal.copyWith(
      quantity: updatedQty,
      calories: updatedCalories,
      protein: updatedProtein,
      carbs: updatedCarbs,
      fat: updatedFat,
    );

    final cubit = context.read<FoodLogCubit>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    await cubit.updateMeal(updatedMeal);
    if (!mounted) return;

    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Meal updated: ${updatedMeal.name.capitalizeFirst()} (${updatedMeal.calories.toStringAsFixed(0)} kcal)',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.kWhite),
        ),
        backgroundColor: AppColors.kBlack,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 24.w,
        right: 24.w,
        top: 16.h,
        bottom: bottomInset + 24.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.kWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.kBlack.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _MealThumbnail(imageUrl: widget.meal.imageUrl, size: 42.w),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    'Edit Meal: ${widget.meal.name.capitalizeFirst()}',
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.headlineSmall.copyWith(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.kBlack,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            SizedBox(height: 16.h),

            // Portion adjuster
            Text(
              'Portion (${widget.meal.servingUnit})',
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.kBlack.withValues(alpha: 0.75),
              ),
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                _EditStepBtn(
                  icon: Icons.remove,
                  onTap: () => _stepPortion(-_stepSize()),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    onChanged: (value) {
                      final parsed = double.tryParse(
                        value.trim().replaceAll(',', '.'),
                      );
                      if (parsed != null && parsed >= 0) {
                        _recalculateFromPortion(parsed, updateQtyField: false);
                      }
                    },
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      suffixText: widget.meal.servingUnit,
                      filled: true,
                      fillColor: AppColors.kScaffold,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 12.h,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                _EditStepBtn(
                  icon: Icons.add,
                  onTap: () => _stepPortion(_stepSize()),
                ),
              ],
            ),

            SizedBox(height: 18.h),
            Text(
              'Calories & Macros (Direct Edit)',
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.kBlack.withValues(alpha: 0.75),
              ),
            ),
            SizedBox(height: 10.h),

            Row(
              children: [
                Expanded(
                  child: _MacroInputField(
                    label: 'Calories',
                    suffix: 'kcal',
                    controller: _caloriesController,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _MacroInputField(
                    label: 'Protein',
                    suffix: 'g',
                    controller: _proteinController,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: _MacroInputField(
                    label: 'Carbs',
                    suffix: 'g',
                    controller: _carbsController,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _MacroInputField(
                    label: 'Fat',
                    suffix: 'g',
                    controller: _fatController,
                  ),
                ),
              ],
            ),

            SizedBox(height: 24.h),
            AppButton(
              text: 'Save Changes',
              onTap: _saveChanges,
            ),
          ],
        ),
      ),
    );
  }
}

class _EditStepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _EditStepBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        width: 42.w,
        height: 42.w,
        decoration: BoxDecoration(
          color: AppColors.kBlack,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Icon(icon, color: AppColors.kWhite, size: 20.sp),
      ),
    );
  }
}

class _MacroInputField extends StatelessWidget {
  final String label;
  final String suffix;
  final TextEditingController controller;

  const _MacroInputField({
    required this.label,
    required this.suffix,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.kBlack.withValues(alpha: 0.65),
          ),
        ),
        SizedBox(height: 4.h),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: AppTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 14.sp,
          ),
          decoration: InputDecoration(
            suffixText: suffix,
            filled: true,
            fillColor: AppColors.kScaffold,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12.w,
              vertical: 10.h,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _MealThumbnail extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const _MealThumbnail({
    required this.imageUrl,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final path = imageUrl?.trim();
    final hasLocalFile =
        path != null &&
        path.isNotEmpty &&
        !path.startsWith('http') &&
        File(path).existsSync();

    return ClipRRect(
      borderRadius: BorderRadius.circular(10.r),
      child: hasLocalFile
          ? Image.file(
              File(path),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _placeholder(),
            )
          : _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      width: size,
      height: size,
      color: AppColors.kOrange.withValues(alpha: 0.12),
      child: Icon(
        Icons.restaurant_rounded,
        color: AppColors.kOrange,
        size: size * 0.5,
      ),
    );
  }
}
