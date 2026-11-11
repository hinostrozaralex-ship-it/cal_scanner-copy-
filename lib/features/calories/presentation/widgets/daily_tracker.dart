import 'package:cal_scanner/core/di/service_locator.dart';
import 'package:cal_scanner/core/extensions/widget_extension.dart';
import 'package:cal_scanner/core/storage/local_storage_service.dart';
import 'package:cal_scanner/theme/app_colors.dart';
import 'package:cal_scanner/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../onboarding/data/local/preference_manager.dart';
import '../../../onboarding/data/models/user_data.dart';
import 'macro_indicator.dart';

class DailyTracker extends StatefulWidget {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  const DailyTracker({
    super.key,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  @override
  State<DailyTracker> createState() => _DailyTrackerState();
}

class _DailyTrackerState extends State<DailyTracker> {
  UserData? userData;
  UserProfile? userProfile;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final prefManager = PreferenceManager(prefs);
    userData = prefManager.getUserData();

    if (sl.isRegistered<LocalStorageService>()) {
      userProfile = await sl<LocalStorageService>().getUserProfile();
    }

    if (mounted) setState(() {});
  }

  String _formattedUnitSummary() {
    final profile = userProfile;
    if (profile == null) return '';
    final isMetric = profile.unitSystem == 'metric';
    final weightUnit = isMetric ? 'kg' : 'lbs';
    final heightUnit = isMetric ? 'cm' : 'in';
    final namePrefix =
        profile.name.isNotEmpty ? '${profile.name}  •  ' : '';
    return '$namePrefix${profile.weight.toStringAsFixed(1)} $weightUnit  •  ${profile.height.toStringAsFixed(1)} $heightUnit';
  }

  @override
  Widget build(BuildContext context) {
    final targetCalories = userData?.estimatedCalories.toDouble() ?? 2000.0;
    final unitSummary = _formattedUnitSummary();

    return Column(
      children: [
        if (unitSummary.isNotEmpty) ...[
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: AppColors.kWhite,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: AppColors.kBlack.withValues(alpha: 0.08),
              ),
            ),
            child: Text(
              unitSummary,
              style: AppTypography.bodySmall.copyWith(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.kBlack.withValues(alpha: 0.7),
              ),
            ),
          ),
          SizedBox(height: 16.h),
        ],
        CircularPercentIndicator(
          backgroundColor: AppColors.kPrimaryGrey,
          radius: 90.sp,
          lineWidth: 14.0,
          percent: (widget.calories / targetCalories.toDouble()).clamp(
            0.0,
            1.0,
          ),
          center: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.calories.toInt().toString(),
                style: AppTypography.displayLarge,
              ),
              SizedBox(height: 5.h),
              Text(
                'of ${targetCalories.toInt()} kcal',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.kgrey,
                ),
              ),
            ],
          ),
          progressColor: Colors.orange,
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            MacroIndicator(
              label: 'Protein',
              value: widget.protein,
              goal: (userData?.proteinGoal ?? 125).toDouble(),
              color: Colors.green,
            ),
            MacroIndicator(
              label: 'Carbs',
              value: widget.carbs,
              goal: (userData?.carbsGoal ?? 250).toDouble(),
              color: Colors.amber,
            ),
            MacroIndicator(
              label: 'Fat',
              value: widget.fat,
              goal: (userData?.fatGoal ?? 55).toDouble(),
              color: Colors.orange,
            ),
          ],
        ).paddingSymmetric(horizontal: 10),
      ],
    );
  }
}
