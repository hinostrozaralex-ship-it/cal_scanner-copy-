import 'package:cal_scanner/core/extensions/capital_first_extension.dart';
import 'package:cal_scanner/core/extensions/context_extension.dart';
import 'package:cal_scanner/theme/app_colors.dart';
import 'package:cal_scanner/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../domain/entities/food.dart';

class MealListItem extends StatelessWidget {
  final Food meal;
  final String timeFormatted;
  final VoidCallback? onDelete;

  const MealListItem({
    super.key,
    required this.meal,
    required this.timeFormatted,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border.all(color: context.colors.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
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
                        timeFormatted,
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
                        'P: ${meal.protein.toStringAsFixed(0)}g  •  C: ${meal.carbs.toStringAsFixed(0)}g  •  G: ${meal.fat.toStringAsFixed(0)}g',
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
              tooltip: 'Eliminar registro',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }
}
