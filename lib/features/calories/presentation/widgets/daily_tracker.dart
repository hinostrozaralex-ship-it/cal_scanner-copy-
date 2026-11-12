import 'package:cal_scanner/core/di/service_locator.dart';
import 'package:cal_scanner/core/extensions/widget_extension.dart';
import 'package:cal_scanner/core/storage/local_storage_service.dart';
import 'package:cal_scanner/core/utils/calorie_calculator.dart';
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

    if (profile.goal != 'Maintenance' &&
        (profile.targetWeight - profile.weight).abs() >= 0.1) {
      final weeksText =
          profile.goalWeeks > 0 ? ' (${profile.goalWeeks}w)' : '';
      return '$namePrefix${profile.weight.toStringAsFixed(1)} → ${profile.targetWeight.toStringAsFixed(1)} $weightUnit$weeksText  •  ${profile.height.toStringAsFixed(1)} $heightUnit';
    }

    return '$namePrefix${profile.weight.toStringAsFixed(1)} $weightUnit  •  ${profile.height.toStringAsFixed(1)} $heightUnit';
  }

  Map<String, int>? _profilePlanFallback() {
    final profile = userProfile;
    if (profile == null) return null;
    final isImperial = profile.unitSystem == 'imperial';
    final weightKg = isImperial ? profile.weight / 2.20462262 : profile.weight;
    final targetWeightKg =
        isImperial ? profile.targetWeight / 2.20462262 : profile.targetWeight;
    final heightCm = isImperial ? profile.height * 2.54 : profile.height;

    return CalorieCalculator.calculatePlanForProfile(
      weightKg: weightKg,
      heightCm: heightCm,
      age: profile.age,
      gender: profile.gender,
      goal: profile.goal,
      targetWeightKg: targetWeightKg,
      goalWeeks: profile.goalWeeks,
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = _profilePlanFallback();
    final targetCalories =
        (plan?['targetCalories'] ?? userData?.estimatedCalories ?? 2000)
            .toDouble();
    final proteinGoal =
        (plan?['proteinGoal'] ?? userData?.proteinGoal ?? 125).toDouble();
    final carbsGoal =
        (plan?['carbsGoal'] ?? userData?.carbsGoal ?? 250).toDouble();
    final fatGoal = (plan?['fatGoal'] ?? userData?.fatGoal ?? 55).toDouble();
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
              goal: proteinGoal,
              color: Colors.green,
            ),
            MacroIndicator(
              label: 'Carbs',
              value: widget.carbs,
              goal: carbsGoal,
              color: Colors.amber,
            ),
            MacroIndicator(
              label: 'Fat',
              value: widget.fat,
              goal: fatGoal,
              color: Colors.orange,
            ),
          ],
        ).paddingSymmetric(horizontal: 10),
      ],
    );
  }
}
