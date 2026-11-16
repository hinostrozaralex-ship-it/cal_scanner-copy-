import 'dart:math' as math;

import 'package:cal_scanner/app_widgets/buttons/back_button.dart';
import 'package:cal_scanner/core/di/service_locator.dart';
import 'package:cal_scanner/core/storage/local_storage_service.dart';
import 'package:cal_scanner/core/utils/calorie_calculator.dart';
import 'package:cal_scanner/theme/app_colors.dart';
import 'package:cal_scanner/theme/app_typography.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class _DailySummary {
  final DateTime date;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final int mealCount;

  const _DailySummary({
    required this.date,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.mealCount,
  });
}

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  bool _isLoading = true;
  UserProfile? _profile;
  List<_DailySummary> _last7Days = [];
  int _touchedBarIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadProgressData();
  }

  Future<void> _loadProgressData() async {
    final storage = sl<LocalStorageService>();
    final profile = await storage.getUserProfile();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final summaries = <_DailySummary>[];

    for (int i = 6; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final meals = await storage.getMealsByDate(day);
      double cal = 0;
      double prot = 0;
      double carbs = 0;
      double fat = 0;
      for (final m in meals) {
        cal += m.calories;
        prot += m.protein;
        carbs += m.carbs;
        fat += m.fat;
      }
      summaries.add(
        _DailySummary(
          date: day,
          calories: cal,
          protein: prot,
          carbs: carbs,
          fat: fat,
          mealCount: meals.length,
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _profile = profile;
      _last7Days = summaries;
      _isLoading = false;
    });
  }

  Map<String, int> _resolveGoals() {
    final profile = _profile;
    if (profile == null) {
      return const {
        'targetCalories': 2000,
        'proteinGoal': 125,
        'carbsGoal': 250,
        'fatGoal': 55,
      };
    }

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

  String _shortDayName(DateTime d) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[d.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final goals = _resolveGoals();
    final targetCalories = (goals['targetCalories'] ?? 2000).toDouble();
    final proteinGoal = (goals['proteinGoal'] ?? 125).toDouble();
    final carbsGoal = (goals['carbsGoal'] ?? 250).toDouble();
    final fatGoal = (goals['fatGoal'] ?? 55).toDouble();

    final loggedDays = _last7Days.where((d) => d.mealCount > 0).toList();
    final totalWeekCalories =
        _last7Days.fold<double>(0, (sum, d) => sum + d.calories);
    final avgDailyCalories = loggedDays.isNotEmpty
        ? totalWeekCalories / loggedDays.length
        : 0.0;
    final totalMealsLogged =
        _last7Days.fold<int>(0, (sum, d) => sum + d.mealCount);

    final avgProtein = loggedDays.isNotEmpty
        ? loggedDays.fold<double>(0, (s, d) => s + d.protein) /
            loggedDays.length
        : 0.0;
    final avgCarbs = loggedDays.isNotEmpty
        ? loggedDays.fold<double>(0, (s, d) => s + d.carbs) / loggedDays.length
        : 0.0;
    final avgFat = loggedDays.isNotEmpty
        ? loggedDays.fold<double>(0, (s, d) => s + d.fat) / loggedDays.length
        : 0.0;

    return Scaffold(
      backgroundColor: AppColors.kScaffold,
      appBar: AppBar(
        backgroundColor: AppColors.kScaffold,
        leading: const AppBackButton(),
        centerTitle: true,
        title: Text(
          'Progress & Analytics',
          style: AppTypography.displaySmall.copyWith(fontSize: 19.sp),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── TOP SUMMARY KPI CARDS ─────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _KpiSummaryCard(
                            icon: Icons.local_fire_department_rounded,
                            iconColor: AppColors.kOrange,
                            label: 'Daily Average',
                            value: '${avgDailyCalories.round()} kcal',
                            subtitle: 'Goal: ${targetCalories.round()} kcal',
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: _KpiSummaryCard(
                            icon: Icons.calendar_today_rounded,
                            iconColor: const Color(0xFF4A90D9),
                            label: 'Active Days',
                            value: '${loggedDays.length} / 7 days',
                            subtitle: '$totalMealsLogged meals logged',
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 18.h),

                    // ─── WEEKLY CALORIE BAR CHART ──────────────────────────
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(18.w),
                      decoration: BoxDecoration(
                        color: AppColors.kWhite,
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: AppColors.kBlack.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Last 7 Days Calories',
                                      style:
                                          AppTypography.titleMedium.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.kBlack,
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      'Tap any bar to inspect daily intake vs goal',
                                      style: AppTypography.bodySmall.copyWith(
                                        fontSize: 11.5.sp,
                                        color: AppColors.kBlack.withValues(
                                          alpha: 0.55,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10.w,
                                  vertical: 5.h,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.kOrange.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8.w,
                                      height: 2.h,
                                      color: AppColors.kOrange,
                                    ),
                                    SizedBox(width: 5.w),
                                    Text(
                                      'Goal ${targetCalories.round()}',
                                      style: AppTypography.bodySmall.copyWith(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.kOrange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 22.h),
                          SizedBox(
                            height: 210.h,
                            child: _buildWeeklyBarChart(targetCalories),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 18.h),

                    // ─── MACRONUTRIENT DISTRIBUTION (PIE + BARS) ───────────
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(18.w),
                      decoration: BoxDecoration(
                        color: AppColors.kWhite,
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: AppColors.kBlack.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily Macro Average vs Target',
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.kBlack,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Based on your active days over the last 7 days',
                            style: AppTypography.bodySmall.copyWith(
                              fontSize: 11.5.sp,
                              color: AppColors.kBlack.withValues(alpha: 0.55),
                            ),
                          ),
                          SizedBox(height: 18.h),
                          Row(
                            children: [
                              SizedBox(
                                width: 115.w,
                                height: 115.w,
                                child: _buildMacroPieChart(
                                  avgProtein,
                                  avgCarbs,
                                  avgFat,
                                ),
                              ),
                              SizedBox(width: 18.w),
                              Expanded(
                                child: Column(
                                  children: [
                                    _MacroProgressRow(
                                      label: 'Protein',
                                      current: avgProtein,
                                      goal: proteinGoal,
                                      color: Colors.green,
                                    ),
                                    SizedBox(height: 12.h),
                                    _MacroProgressRow(
                                      label: 'Carbs',
                                      current: avgCarbs,
                                      goal: carbsGoal,
                                      color: Colors.amber.shade700,
                                    ),
                                    SizedBox(height: 12.h),
                                    _MacroProgressRow(
                                      label: 'Fat',
                                      current: avgFat,
                                      goal: fatGoal,
                                      color: AppColors.kOrange,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    if (_profile != null) ...[
                      SizedBox(height: 18.h),
                      _GoalPlanCard(profile: _profile!),
                    ],
                    SizedBox(height: 20.h),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWeeklyBarChart(double targetCalories) {
    final maxLogged = _last7Days.fold<double>(
      0.0,
      (maxVal, d) => math.max(maxVal, d.calories),
    );
    final maxY = math.max(targetCalories * 1.25, maxLogged * 1.2).clamp(
      1500.0,
      6000.0,
    );
    final interval = (maxY / 4).roundToDouble();

    return BarChart(
      BarChartData(
        maxY: maxY,
        minY: 0,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.kBlack,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final day = _last7Days[group.x];
              return BarTooltipItem(
                '${_shortDayName(day.date)} ${day.date.day}\n',
                TextStyle(
                  color: Colors.white70,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                ),
                children: [
                  TextSpan(
                    text: '${day.calories.round()} kcal',
                    style: TextStyle(
                      color: AppColors.kOrange,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              );
            },
          ),
          touchCallback: (event, response) {
            setState(() {
              if (!event.isInterestedForInteractions ||
                  response == null ||
                  response.spot == null) {
                _touchedBarIndex = -1;
                return;
              }
              _touchedBarIndex = response.spot!.touchedBarGroupIndex;
            });
          },
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40.w,
              interval: interval > 0 ? interval : 500,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Text(
                  '${value.toInt()}',
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 10.sp,
                    color: AppColors.kBlack.withValues(alpha: 0.45),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32.h,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= _last7Days.length) {
                  return const SizedBox.shrink();
                }
                final d = _last7Days[idx].date;
                final isToday = idx == _last7Days.length - 1;
                return Padding(
                  padding: EdgeInsets.only(top: 8.h),
                  child: Text(
                    isToday ? 'Today' : _shortDayName(d),
                    style: AppTypography.bodySmall.copyWith(
                      fontSize: 11.sp,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                      color: isToday
                          ? AppColors.kOrange
                          : AppColors.kBlack.withValues(alpha: 0.65),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval > 0 ? interval : 500,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppColors.kBlack.withValues(alpha: 0.06),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: targetCalories,
              color: AppColors.kOrange.withValues(alpha: 0.75),
              strokeWidth: 1.8,
              dashArray: [6, 4],
            ),
          ],
        ),
        barGroups: List.generate(_last7Days.length, (index) {
          final item = _last7Days[index];
          final isTouched = index == _touchedBarIndex;
          final isOverGoal = item.calories > targetCalories * 1.1;
          final barColor = isOverGoal
              ? Colors.redAccent
              : (item.calories > 0 ? AppColors.kOrange : AppColors.kPrimaryGrey);

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: item.calories > 0 ? item.calories : maxY * 0.02,
                color: isTouched ? AppColors.kBlack : barColor,
                width: 18.w,
                borderRadius: BorderRadius.vertical(top: Radius.circular(6.r)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY,
                  color: AppColors.kScaffold,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildMacroPieChart(double protein, double carbs, double fat) {
    final protCal = protein * 4;
    final carbsCal = carbs * 4;
    final fatCal = fat * 9;
    final totalMacroCal = protCal + carbsCal + fatCal;

    if (totalMacroCal <= 0) {
      return Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 0,
              centerSpaceRadius: 34.r,
              sections: [
                PieChartSectionData(
                  value: 1,
                  color: AppColors.kPrimaryGrey,
                  radius: 16.r,
                  showTitle: false,
                ),
              ],
            ),
          ),
          Text(
            'No data',
            style: AppTypography.bodySmall.copyWith(
              fontSize: 11.sp,
              color: AppColors.kgrey,
            ),
          ),
        ],
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sectionsSpace: 3,
            centerSpaceRadius: 32.r,
            sections: [
              PieChartSectionData(
                value: protCal,
                color: Colors.green,
                radius: 18.r,
                showTitle: false,
              ),
              PieChartSectionData(
                value: carbsCal,
                color: Colors.amber.shade700,
                radius: 18.r,
                showTitle: false,
              ),
              PieChartSectionData(
                value: fatCal,
                color: AppColors.kOrange,
                radius: 18.r,
                showTitle: false,
              ),
            ],
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Macros',
              style: AppTypography.bodySmall.copyWith(
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.kBlack,
              ),
            ),
            Text(
              'split',
              style: AppTypography.bodySmall.copyWith(
                fontSize: 9.5.sp,
                color: AppColors.kBlack.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KpiSummaryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String subtitle;

  const _KpiSummaryCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.kWhite,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.kBlack.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, color: iconColor, size: 20.sp),
          ),
          SizedBox(height: 12.h),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              fontSize: 11.5.sp,
              color: AppColors.kBlack.withValues(alpha: 0.55),
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            value,
            style: AppTypography.headlineSmall.copyWith(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.kBlack,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            subtitle,
            style: AppTypography.bodySmall.copyWith(
              fontSize: 11.sp,
              color: AppColors.kBlack.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroProgressRow extends StatelessWidget {
  final String label;
  final double current;
  final double goal;
  final Color color;

  const _MacroProgressRow({
    required this.label,
    required this.current,
    required this.goal,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.kBlack,
              ),
            ),
            Text(
              '${current.round()}g / ${goal.round()}g',
              style: AppTypography.bodySmall.copyWith(
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.kBlack.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        SizedBox(height: 5.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(6.r),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 7.h,
            backgroundColor: AppColors.kScaffold,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _GoalPlanCard extends StatelessWidget {
  final UserProfile profile;

  const _GoalPlanCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final unit = profile.unitSystem == 'imperial' ? 'lbs' : 'kg';
    final isMaintenance = profile.goal == 'Maintenance';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.kWhite,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.kOrange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: AppColors.kOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              Icons.flag_rounded,
              color: AppColors.kOrange,
              size: 22.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Plan: ${profile.goal}',
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5.sp,
                    color: AppColors.kBlack,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  isMaintenance
                      ? 'Maintaining weight at ${profile.weight.toStringAsFixed(1)} $unit'
                      : 'From ${profile.weight.toStringAsFixed(1)} $unit → ${profile.targetWeight.toStringAsFixed(1)} $unit (${profile.goalWeeks} weeks)',
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 12.sp,
                    color: AppColors.kBlack.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
