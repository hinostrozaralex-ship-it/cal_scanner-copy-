import 'package:cal_scanner/app_widgets/buttons/app_button.dart';
import 'package:cal_scanner/app_widgets/buttons/back_button.dart';
import 'package:cal_scanner/core/di/service_locator.dart';
import 'package:cal_scanner/core/storage/local_storage_service.dart';
import 'package:cal_scanner/core/utils/calorie_calculator.dart';
import 'package:cal_scanner/theme/app_colors.dart';
import 'package:cal_scanner/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _targetWeightController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();

  String _unitSystem = 'metric';
  String _gender = 'Male';
  String _goal = 'Maintenance';
  int _goalWeeks = 8;
  bool _obscureApiKey = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final storage = sl<LocalStorageService>();
    final profile = await storage.getUserProfile();
    final storedKey = await storage.getApiKey();

    if (!mounted) return;
    setState(() {
      if (profile != null) {
        _nameController.text = profile.name;
        _ageController.text = profile.age.toString();
        _weightController.text = profile.weight.toStringAsFixed(1);
        _heightController.text = profile.height.toStringAsFixed(1);
        _unitSystem = profile.unitSystem;
        _gender = profile.gender;
        _goal = profile.goal;
        _targetWeightController.text = profile.targetWeight.toStringAsFixed(1);
        _goalWeeks = profile.goalWeeks > 0 ? profile.goalWeeks : 8;
        _apiKeyController.text = profile.apiKey ?? '';
      } else {
        _ageController.text = '25';
        _weightController.text = '70.0';
        _heightController.text = '170.0';
        _targetWeightController.text = '70.0';
        _apiKeyController.text = storedKey ?? '';
      }
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _targetWeightController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  double _currentWeightKg() {
    final w = double.tryParse(
          _weightController.text.trim().replaceAll(',', '.'),
        ) ??
        (_unitSystem == 'metric' ? 70.0 : 154.0);
    return _unitSystem == 'imperial' ? w / 2.20462262 : w;
  }

  double _currentHeightCm() {
    final h = double.tryParse(
          _heightController.text.trim().replaceAll(',', '.'),
        ) ??
        (_unitSystem == 'metric' ? 170.0 : 67.0);
    return _unitSystem == 'imperial' ? h * 2.54 : h;
  }

  double _currentTargetWeightKg() {
    final tw = double.tryParse(
          _targetWeightController.text.trim().replaceAll(',', '.'),
        ) ??
        (_unitSystem == 'metric' ? 70.0 : 154.0);
    return _unitSystem == 'imperial' ? tw / 2.20462262 : tw;
  }

  double _kgToDisplayUnit(double kg) {
    return _unitSystem == 'imperial' ? kg * 2.20462262 : kg;
  }

  void _applySuggestedTargetForWeeks(int weeks) {
    final weightKg = _currentWeightKg();
    final heightCm = _currentHeightCm();
    final suggestedKg = CalorieCalculator.suggestTargetWeightForWeeks(
      currentWeightKg: weightKg,
      heightCm: heightCm,
      goal: _goal,
      weeks: weeks,
    );
    final displayTarget = _kgToDisplayUnit(suggestedKg);
    setState(() {
      _goalWeeks = weeks;
      _targetWeightController.text = displayTarget.toStringAsFixed(1);
    });
  }

  void _onTargetWeightChanged(String value) {
    final targetKg = _currentTargetWeightKg();
    final weightKg = _currentWeightKg();
    final weeks = CalorieCalculator.suggestWeeksForTargetWeight(
      currentWeightKg: weightKg,
      targetWeightKg: targetKg,
      goal: _goal,
    );
    setState(() {
      if (weeks > 0) {
        _goalWeeks = weeks;
      }
    });
  }

  void _onGoalChanged(String newGoal) {
    if (_goal == newGoal) return;
    setState(() {
      _goal = newGoal;
      if (_goal == 'Maintenance') {
        _targetWeightController.text = _weightController.text;
      } else {
        if (_goalWeeks <= 0) _goalWeeks = 8;
        final suggestedKg = CalorieCalculator.suggestTargetWeightForWeeks(
          currentWeightKg: _currentWeightKg(),
          heightCm: _currentHeightCm(),
          goal: _goal,
          weeks: _goalWeeks,
        );
        _targetWeightController.text =
            _kgToDisplayUnit(suggestedKg).toStringAsFixed(1);
      }
    });
  }

  void _toggleUnitSystem(String targetSystem) {
    if (_unitSystem == targetSystem) return;

    final currentWeight = double.tryParse(
      _weightController.text.replaceAll(',', '.'),
    );
    final currentHeight = double.tryParse(
      _heightController.text.replaceAll(',', '.'),
    );
    final currentTargetWeight = double.tryParse(
      _targetWeightController.text.replaceAll(',', '.'),
    );

    setState(() {
      _unitSystem = targetSystem;
      if (currentWeight != null && currentWeight > 0) {
        final convertedWeight = targetSystem == 'imperial'
            ? currentWeight * 2.20462262
            : currentWeight / 2.20462262;
        _weightController.text = convertedWeight.toStringAsFixed(1);
      }
      if (currentHeight != null && currentHeight > 0) {
        final convertedHeight = targetSystem == 'imperial'
            ? currentHeight / 2.54
            : currentHeight * 2.54;
        _heightController.text = convertedHeight.toStringAsFixed(1);
      }
      if (currentTargetWeight != null && currentTargetWeight > 0) {
        final convertedTarget = targetSystem == 'imperial'
            ? currentTargetWeight * 2.20462262
            : currentTargetWeight / 2.20462262;
        _targetWeightController.text = convertedTarget.toStringAsFixed(1);
      }
    });
  }

  Future<void> _saveSettings() async {
    final name = _nameController.text.trim();
    final age = int.tryParse(_ageController.text.trim()) ?? 25;
    final weight = double.tryParse(
          _weightController.text.trim().replaceAll(',', '.'),
        ) ??
        (_unitSystem == 'metric' ? 70.0 : 154.0);
    final height = double.tryParse(
          _heightController.text.trim().replaceAll(',', '.'),
        ) ??
        (_unitSystem == 'metric' ? 170.0 : 67.0);
    final targetWeight = _goal == 'Maintenance'
        ? weight
        : (double.tryParse(
              _targetWeightController.text.trim().replaceAll(',', '.'),
            ) ??
            weight);

    if (_goal != 'Maintenance') {
      final boundsKg = CalorieCalculator.getSafeWeightBounds(
        currentWeightKg: _currentWeightKg(),
        heightCm: _currentHeightCm(),
        goal: _goal,
      );
      final minDisplay = _kgToDisplayUnit(boundsKg['minKg']!);
      final maxDisplay = _kgToDisplayUnit(boundsKg['maxKg']!);
      final weightUnit = _unitSystem == 'metric' ? 'kg' : 'lbs';

      if (targetWeight < minDisplay - 0.1 || targetWeight > maxDisplay + 0.1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'For your health and height, please choose a safe target weight between ${minDisplay.toStringAsFixed(1)} and ${maxDisplay.toStringAsFixed(1)} $weightUnit.',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.kWhite),
            ),
            backgroundColor: Colors.redAccent.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
        );
        return;
      }
    }

    final updatedProfile = UserProfile(
      name: name,
      age: age,
      weight: weight,
      height: height,
      unitSystem: _unitSystem,
      gender: _gender,
      goal: _goal,
      targetWeight: targetWeight,
      goalWeeks: _goal == 'Maintenance' ? 0 : _goalWeeks,
      apiKey: _apiKeyController.text.trim(),
      isOnboarded: true,
    );

    await sl<LocalStorageService>().saveUserProfile(updatedProfile);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Settings & goals saved successfully',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.kWhite),
        ),
        backgroundColor: AppColors.kBlack,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
    );

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isMetric = _unitSystem == 'metric';
    final weightUnit = isMetric ? 'kg' : 'lbs';
    final heightUnit = isMetric ? 'cm' : 'in';

    final weightKg = _currentWeightKg();
    final heightCm = _currentHeightCm();
    final targetWeightKg =
        _goal == 'Maintenance' ? weightKg : _currentTargetWeightKg();
    final ageVal = int.tryParse(_ageController.text.trim()) ?? 25;

    final safeBoundsKg = CalorieCalculator.getSafeWeightBounds(
      currentWeightKg: weightKg,
      heightCm: heightCm,
      goal: _goal,
    );
    final minSafeDisplay = _kgToDisplayUnit(safeBoundsKg['minKg']!);
    final maxSafeDisplay = _kgToDisplayUnit(safeBoundsKg['maxKg']!);

    final planPreview = CalorieCalculator.calculatePlanForProfile(
      weightKg: weightKg,
      heightCm: heightCm,
      age: ageVal,
      gender: _gender,
      goal: _goal,
      targetWeightKg: targetWeightKg,
      goalWeeks: _goalWeeks,
    );

    return Scaffold(
      backgroundColor: AppColors.kScaffold,
      appBar: AppBar(
        backgroundColor: AppColors.kScaffold,
        leading: const AppBackButton(),
        centerTitle: true,
        title: Text(
          'Settings & Profile',
          style: AppTypography.displaySmall.copyWith(fontSize: 19.sp),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SettingsLabel('Unit System'),
                    SizedBox(height: 8.h),
                    _SettingsUnitSelector(
                      unitSystem: _unitSystem,
                      onChanged: _toggleUnitSystem,
                    ),
                    SizedBox(height: 16.h),

                    _SettingsLabel('Biological Sex'),
                    SizedBox(height: 8.h),
                    _SettingsGenderSelector(
                      gender: _gender,
                      onChanged: (val) => setState(() => _gender = val),
                    ),
                    SizedBox(height: 16.h),

                    _SettingsLabel('Name / Alias'),
                    SizedBox(height: 6.h),
                    _SettingsTextField(
                      controller: _nameController,
                      hintText: 'Your name or alias',
                      keyboardType: TextInputType.name,
                      prefixIcon: Icons.person_outline,
                    ),
                    SizedBox(height: 16.h),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SettingsLabel('Age'),
                              SizedBox(height: 6.h),
                              _SettingsTextField(
                                controller: _ageController,
                                hintText: '25',
                                suffixText: 'yrs',
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() {}),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SettingsLabel('Weight ($weightUnit)'),
                              SizedBox(height: 6.h),
                              _SettingsTextField(
                                controller: _weightController,
                                hintText: isMetric ? '70' : '154',
                                suffixText: weightUnit,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                onChanged: (_) {
                                  if (_goal != 'Maintenance') {
                                    _applySuggestedTargetForWeeks(_goalWeeks);
                                  } else {
                                    setState(() {});
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SettingsLabel('Height ($heightUnit)'),
                              SizedBox(height: 6.h),
                              _SettingsTextField(
                                controller: _heightController,
                                hintText: isMetric ? '170' : '67',
                                suffixText: heightUnit,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20.h),

                    _SettingsLabel('Your Goal'),
                    SizedBox(height: 8.h),
                    _SettingsGoalSelector(
                      goal: _goal,
                      onChanged: _onGoalChanged,
                    ),

                    if (_goal != 'Maintenance') ...[
                      SizedBox(height: 16.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _SettingsLabel('Suggested Timeframe'),
                          Text(
                            '$_goalWeeks weeks (~${(_goalWeeks / 4.3).toStringAsFixed(1)} mo)',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.kOrange,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5.sp,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      _SettingsTimeframeChips(
                        selectedWeeks: _goalWeeks,
                        onSelectWeeks: _applySuggestedTargetForWeeks,
                      ),
                      SizedBox(height: 14.h),
                      _SettingsLabel('Target Weight ($weightUnit)'),
                      SizedBox(height: 6.h),
                      _SettingsTextField(
                        controller: _targetWeightController,
                        hintText: minSafeDisplay.toStringAsFixed(1),
                        suffixText: weightUnit,
                        prefixIcon: Icons.flag_outlined,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: _onTargetWeightChanged,
                      ),
                      SizedBox(height: 6.h),
                      Row(
                        children: [
                          Icon(
                            Icons.health_and_safety_outlined,
                            size: 15.sp,
                            color: Colors.green.shade700,
                          ),
                          SizedBox(width: 5.w),
                          Expanded(
                            child: Text(
                              'Safe healthy range for your height & cycle: ${minSafeDisplay.toStringAsFixed(1)} – ${maxSafeDisplay.toStringAsFixed(1)} $weightUnit',
                              style: AppTypography.bodySmall.copyWith(
                                fontSize: 11.5.sp,
                                color: AppColors.kBlack.withValues(alpha: 0.65),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    SizedBox(height: 18.h),
                    _SettingsPlanSummaryCard(
                      calories: planPreview['targetCalories'] ?? 2000,
                      protein: planPreview['proteinGoal'] ?? 125,
                      carbs: planPreview['carbsGoal'] ?? 250,
                      fat: planPreview['fatGoal'] ?? 55,
                      goal: _goal,
                      weeks: _goalWeeks,
                    ),

                    SizedBox(height: 22.h),

                    Row(
                      children: [
                        Icon(
                          Icons.vpn_key_rounded,
                          size: 18.sp,
                          color: AppColors.kOrange,
                        ),
                        SizedBox(width: 6.w),
                        _SettingsLabel('Gemini API Key'),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Get your free key from Google AI Studio',
                      style: AppTypography.bodySmall.copyWith(
                        fontSize: 12.sp,
                        color: AppColors.kBlack.withValues(alpha: 0.6),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    _SettingsTextField(
                      controller: _apiKeyController,
                      hintText: 'Paste your Gemini API Key here',
                      obscureText: _obscureApiKey,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureApiKey
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: AppColors.kBlack.withValues(alpha: 0.6),
                          size: 20.sp,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureApiKey = !_obscureApiKey;
                          });
                        },
                      ),
                    ),
                    SizedBox(height: 28.h),

                    AppButton(
                      text: 'Save Changes',
                      onTap: _saveSettings,
                    ),
                    SizedBox(height: 16.h),
                  ],
                ),
              ),
            ),
    );
  }
}

class _SettingsLabel extends StatelessWidget {
  final String text;
  const _SettingsLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.titleMedium.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.kBlack,
      ),
    );
  }
}

class _SettingsUnitSelector extends StatelessWidget {
  final String unitSystem;
  final ValueChanged<String> onChanged;

  const _SettingsUnitSelector({
    required this.unitSystem,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isMetric = unitSystem == 'metric';
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppColors.kWhite,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.kBlack.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged('metric'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(vertical: 11.h),
                decoration: BoxDecoration(
                  color: isMetric ? AppColors.kBlack : Colors.transparent,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Metric (kg / cm)',
                  style: AppTypography.titleSmall.copyWith(
                    color: isMetric ? AppColors.kWhite : AppColors.kBlack,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.sp,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged('imperial'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(vertical: 11.h),
                decoration: BoxDecoration(
                  color: !isMetric ? AppColors.kBlack : Colors.transparent,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Imperial (lbs / in)',
                  style: AppTypography.titleSmall.copyWith(
                    color: !isMetric ? AppColors.kWhite : AppColors.kBlack,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.sp,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsGenderSelector extends StatelessWidget {
  final String gender;
  final ValueChanged<String> onChanged;

  const _SettingsGenderSelector({
    required this.gender,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isMale = gender == 'Male';
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppColors.kWhite,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.kBlack.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged('Male'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(vertical: 11.h),
                decoration: BoxDecoration(
                  color: isMale ? AppColors.kBlack : Colors.transparent,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.male_rounded,
                      size: 18.sp,
                      color: isMale ? AppColors.kWhite : AppColors.kBlack,
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      'Male',
                      style: AppTypography.titleSmall.copyWith(
                        color: isMale ? AppColors.kWhite : AppColors.kBlack,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged('Female'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(vertical: 11.h),
                decoration: BoxDecoration(
                  color: !isMale ? AppColors.kBlack : Colors.transparent,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.female_rounded,
                      size: 18.sp,
                      color: !isMale ? AppColors.kWhite : AppColors.kBlack,
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      'Female',
                      style: AppTypography.titleSmall.copyWith(
                        color: !isMale ? AppColors.kWhite : AppColors.kBlack,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsGoalSelector extends StatelessWidget {
  final String goal;
  final ValueChanged<String> onChanged;

  const _SettingsGoalSelector({
    required this.goal,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = [
      ('Weight Loss', 'Lose Weight', Icons.trending_down_rounded),
      ('Maintenance', 'Maintain', Icons.balance_rounded),
      ('Muscle Gain', 'Gain Muscle', Icons.fitness_center_rounded),
    ];

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppColors.kWhite,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.kBlack.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: options.map((opt) {
          final isSelected = goal == opt.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(opt.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 4.w),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.kBlack : Colors.transparent,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      opt.$3,
                      size: 18.sp,
                      color: isSelected ? AppColors.kOrange : AppColors.kBlack,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      opt.$2,
                      textAlign: TextAlign.center,
                      style: AppTypography.titleSmall.copyWith(
                        color: isSelected ? AppColors.kWhite : AppColors.kBlack,
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SettingsTimeframeChips extends StatelessWidget {
  final int selectedWeeks;
  final ValueChanged<int> onSelectWeeks;

  const _SettingsTimeframeChips({
    required this.selectedWeeks,
    required this.onSelectWeeks,
  });

  @override
  Widget build(BuildContext context) {
    const presets = [4, 8, 12, 16];
    return Row(
      children: presets.map((weeks) {
        final isSelected = selectedWeeks == weeks;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: weeks == presets.last ? 0 : 8.w),
            child: GestureDetector(
              onTap: () => onSelectWeeks(weeks),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.symmetric(vertical: 9.h),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.kOrange : AppColors.kWhite,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.kOrange
                        : AppColors.kBlack.withValues(alpha: 0.14),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$weeks wks',
                  style: AppTypography.titleSmall.copyWith(
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? AppColors.kWhite : AppColors.kBlack,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SettingsPlanSummaryCard extends StatelessWidget {
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final String goal;
  final int weeks;

  const _SettingsPlanSummaryCard({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.goal,
    required this.weeks,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = goal == 'Maintenance'
        ? 'Daily Maintenance Plan'
        : '$goal Plan • $weeks weeks';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.kWhite,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.kOrange.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Daily Target',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.kBlack,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.kOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  '$calories kcal / day',
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.kOrange,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.sp,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            subtitle,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.kBlack.withValues(alpha: 0.6),
              fontSize: 12.sp,
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SettingsMacroBadge(
                label: 'Protein',
                grams: protein,
                color: Colors.green,
              ),
              _SettingsMacroBadge(
                label: 'Carbs',
                grams: carbs,
                color: Colors.amber.shade700,
              ),
              _SettingsMacroBadge(
                label: 'Fat',
                grams: fat,
                color: Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsMacroBadge extends StatelessWidget {
  final String label;
  final int grams;
  final Color color;

  const _SettingsMacroBadge({
    required this.label,
    required this.grams,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${grams}g',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
            fontSize: 15.sp,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            fontSize: 11.5.sp,
            color: AppColors.kBlack.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }
}

class _SettingsTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final String? suffixText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final ValueChanged<String>? onChanged;

  const _SettingsTextField({
    required this.controller,
    required this.hintText,
    this.suffixText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.obscureText = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      onChanged: onChanged,
      cursorColor: AppColors.kOrange,
      style: AppTypography.bodyMedium.copyWith(
        fontSize: 14.sp,
        color: AppColors.kBlack,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTypography.bodyMedium.copyWith(
          fontSize: 13.5.sp,
          color: AppColors.kBlack.withValues(alpha: 0.4),
        ),
        suffixText: suffixText,
        suffixStyle: AppTypography.titleSmall.copyWith(
          color: AppColors.kOrange,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: prefixIcon != null
            ? Icon(
                prefixIcon,
                color: AppColors.kBlack.withValues(alpha: 0.55),
                size: 20.sp,
              )
            : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.kWhite,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14.w,
          vertical: 14.h,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: BorderSide(
            color: AppColors.kBlack.withValues(alpha: 0.15),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: BorderSide(
            color: AppColors.kBlack.withValues(alpha: 0.15),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: BorderSide(
            color: AppColors.kOrange,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
