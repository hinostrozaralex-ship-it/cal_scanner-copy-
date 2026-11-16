import 'dart:io';

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
      onTap: onTap,
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
