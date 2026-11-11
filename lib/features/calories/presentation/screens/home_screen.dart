// home_screen.dart

import 'dart:io';

import 'package:cal_scanner/core/extensions/context_extension.dart';
import 'package:cal_scanner/core/extensions/widget_extension.dart';
import 'package:cal_scanner/features/calories/presentation/cubit/food_log_cubit.dart';
import 'package:cal_scanner/features/calories/presentation/cubit/food_log_state.dart';
import 'package:cal_scanner/features/calories/presentation/screens/scan_result_screen.dart';
import 'package:cal_scanner/features/calories/presentation/screens/settings_screen.dart';
import 'package:cal_scanner/features/calories/presentation/widgets/weekly_date_picker.dart';
import 'package:cal_scanner/theme/app_colors.dart';
import 'package:cal_scanner/theme/app_typography.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/daily_tracker.dart';
import '../widgets/meal_list.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _profileRefreshTick = 0;

  Future<void> _pickAndScanImage(
    BuildContext context,
    ImageSource source,
  ) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 60,
    );
    if (picked == null) return;
    final file = File(picked.path);
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<FoodLogCubit>(),
          child: ScanResultScreen(imageFile: file),
        ),
      ),
    );
  }

  void _showImageSourceSelector(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.kWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.kBlack.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
              SizedBox(height: 14.h),
              Text(
                'Scan Food',
                style: AppTypography.headlineSmall.copyWith(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 12.h),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: AppColors.kOrange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    CupertinoIcons.camera_fill,
                    color: AppColors.kOrange,
                    size: 22.sp,
                  ),
                ),
                title: Text(
                  'Take a Photo',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Use camera to scan your meal right now',
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 12.sp,
                    color: AppColors.kBlack.withValues(alpha: 0.6),
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickAndScanImage(context, ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: AppColors.kBlack.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    CupertinoIcons.photo_fill,
                    color: AppColors.kBlack,
                    size: 22.sp,
                  ),
                ),
                title: Text(
                  'Choose from Gallery',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Pick an existing photo from your device',
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 12.sp,
                    color: AppColors.kBlack.withValues(alpha: 0.6),
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickAndScanImage(context, ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Calorie Tracker',
          style: AppTypography.displaySmall.copyWith(fontSize: 19.sp),
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(
              Icons.settings,
              color: AppColors.kBlack,
              size: 24.sp,
            ),
            tooltip: 'Settings & Profile',
            onPressed: () async {
              final updated = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
              if (updated == true && mounted) {
                setState(() {
                  _profileRefreshTick++;
                });
              }
            },
          ),
          SizedBox(width: 8.w),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BlocBuilder<FoodLogCubit, FoodLogState>(
                builder: (context, state) {
                  return WeekDatePicker(
                    selectedDate: state.selectedDate,
                    onDateSelected: (date) {
                      context.read<FoodLogCubit>().selectDate(date);
                    },
                  );
                },
              ),

              BlocBuilder<FoodLogCubit, FoodLogState>(
                builder: (context, state) {
                  if (state.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      DailyTracker(
                        key: ValueKey(_profileRefreshTick),
                        calories: state.totalCalories,
                        protein: state.totalProtein,
                        carbs: state.totalCarbs,
                        fat: state.totalFat,
                      ),
                      SizedBox(height: 30.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Meals',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '${state.meals.length} items',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ).paddingSymmetric(horizontal: 20.w),
                      const SizedBox(height: 16),
                      MealList(meals: state.meals),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.kOrange,
        onPressed: () => _showImageSourceSelector(context),
        child: Icon(
          CupertinoIcons.camera_viewfinder,
          size: 30.sp,
          color: context.colors.onPrimary,
        ),
      ),
    );
  }
}
