import 'package:cal_scanner/core/extensions/context_extension.dart';
import 'package:cal_scanner/core/extensions/num_extension.dart';
import 'package:cal_scanner/core/extensions/widget_extension.dart';
import 'package:cal_scanner/features/calories/presentation/screens/meal_detail_screen.dart';
import 'package:cal_scanner/gen/assets.gen.dart';
import 'package:cal_scanner/theme/app_colors.dart';
import 'package:cal_scanner/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../domain/entities/food.dart';
import '../cubit/food_log_cubit.dart';
import 'meal_list_item.dart';

class MealList extends StatelessWidget {
  final List<Food> meals;

  const MealList({required this.meals, super.key});

  String _formatHourMinute(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final sortedMeals = List.of(meals)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return meals.isEmpty
        ? Padding(
            padding: EdgeInsets.only(top: 24.h, bottom: 24.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  Assets.images.tray.path,
                  height: 42.h,
                  color: context.colors.onSurfaceVariant,
                ),
                15.kH,
                Padding(
                  padding: pagePadding,
                  child: Text(
                    'No hay comidas registradas en este día',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ),
                const Row(),
              ],
            ),
          )
        : ListView.separated(
            padding: pagePadding,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedMeals.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final meal = sortedMeals[index];
              return Dismissible(
                key: ValueKey(meal.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    color: Colors.white,
                  ),
                ),
                onDismissed: (_) {
                  context.read<FoodLogCubit>().deleteMeal(meal);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Registro eliminado',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.kWhite,
                        ),
                      ),
                      backgroundColor: AppColors.kBlack,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MealDetailScreen(meal: meal),
                      ),
                    );
                  },
                  child: MealListItem(
                    meal: meal,
                    timeFormatted: _formatHourMinute(meal.timestamp),
                    onDelete: () {
                      context.read<FoodLogCubit>().deleteMeal(meal);
                    },
                  ),
                ),
              );
            },
          );
  }
}
