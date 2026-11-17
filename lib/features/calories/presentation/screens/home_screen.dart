// home_screen.dart

import 'dart:io';

import 'package:cal_scanner/core/extensions/widget_extension.dart';
import 'package:cal_scanner/features/calories/presentation/cubit/food_log_cubit.dart';
import 'package:cal_scanner/features/calories/presentation/cubit/food_log_state.dart';
import 'package:cal_scanner/features/calories/presentation/screens/manual_meal_screen.dart';
import 'package:cal_scanner/features/calories/presentation/screens/progress_screen.dart';
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

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _profileRefreshTick = 0;
  bool _isFabOpen = false;

  late final AnimationController _fabController;
  late final Animation<double> _scrimFade;
  late final Animation<double> _firstOptionScale;
  late final Animation<Offset> _firstOptionSlide;
  late final Animation<double> _secondOptionScale;
  late final Animation<Offset> _secondOptionSlide;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 200),
    );

    _scrimFade = CurvedAnimation(
      parent: _fabController,
      curve: Curves.easeOut,
    );

    _firstOptionScale = CurvedAnimation(
      parent: _fabController,
      curve: const Interval(0.0, 0.85, curve: Curves.easeOutBack),
      reverseCurve: Curves.easeInCubic,
    );
    _firstOptionSlide = Tween<Offset>(
      begin: const Offset(0, 0.45),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _fabController,
        curve: const Interval(0.0, 0.85, curve: Curves.easeOutBack),
        reverseCurve: Curves.easeInCubic,
      ),
    );

    _secondOptionScale = CurvedAnimation(
      parent: _fabController,
      curve: const Interval(0.15, 1.0, curve: Curves.easeOutBack),
      reverseCurve: Curves.easeInCubic,
    );
    _secondOptionSlide = Tween<Offset>(
      begin: const Offset(0, 0.55),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _fabController,
        curve: const Interval(0.15, 1.0, curve: Curves.easeOutBack),
        reverseCurve: Curves.easeInCubic,
      ),
    );
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  void _toggleFabMenu() {
    setState(() {
      _isFabOpen = !_isFabOpen;
      if (_isFabOpen) {
        _fabController.forward();
      } else {
        _fabController.reverse();
      }
    });
  }

  Future<void> _closeFabMenu() async {
    if (!_isFabOpen) return;
    setState(() => _isFabOpen = false);
    await _fabController.reverse();
  }

  Future<void> _pickAndScanImage(
    BuildContext context,
    ImageSource source,
  ) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
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

  void _openManualEntryScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<FoodLogCubit>(),
          child: const ManualMealScreen(),
        ),
      ),
    );
  }

  void _openProgressScreen(BuildContext context) {
    _closeFabMenu();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProgressScreen(),
      ),
    );
  }

  Future<void> _openSettingsScreen(BuildContext context) async {
    await _closeFabMenu();
    if (!context.mounted) return;
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
      ),
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: 24.h),
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
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
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

          // Animated scrim & centered speed-dial options
          AnimatedBuilder(
            animation: _fabController,
            builder: (context, _) {
              if (_fabController.isDismissed) {
                return const SizedBox.shrink();
              }
              return Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _closeFabMenu,
                      child: FadeTransition(
                        opacity: _scrimFade,
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.28),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 20.h,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FadeTransition(
                          opacity: _secondOptionScale,
                          child: SlideTransition(
                            position: _secondOptionSlide,
                            child: ScaleTransition(
                              scale: _secondOptionScale,
                              child: _FabBubbleOption(
                                label: 'Scan Food',
                                icon: CupertinoIcons.camera_viewfinder,
                                backgroundColor: AppColors.kOrange,
                                iconColor: AppColors.kWhite,
                                onTap: () async {
                                  await _closeFabMenu();
                                  if (context.mounted) {
                                    _showImageSourceSelector(context);
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 12.h),
                        FadeTransition(
                          opacity: _firstOptionScale,
                          child: SlideTransition(
                            position: _firstOptionSlide,
                            child: ScaleTransition(
                              scale: _firstOptionScale,
                              child: _FabBubbleOption(
                                label: 'Manual Entry',
                                icon: Icons.edit_note_rounded,
                                backgroundColor: AppColors.kBlack,
                                iconColor: AppColors.kWhite,
                                onTap: () async {
                                  await _closeFabMenu();
                                  if (context.mounted) {
                                    _openManualEntryScreen(context);
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.kWhite,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Left: Progress / Statistics
                _BottomNavAction(
                  icon: Icons.bar_chart_rounded,
                  label: 'Progress',
                  onTap: () => _openProgressScreen(context),
                ),

                // Center: Animated "+" Button
                GestureDetector(
                  onTap: _toggleFabMenu,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    width: 54.w,
                    height: 54.w,
                    decoration: BoxDecoration(
                      color: _isFabOpen ? AppColors.kBlack : AppColors.kOrange,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_isFabOpen
                                  ? AppColors.kBlack
                                  : AppColors.kOrange)
                              .withValues(alpha: 0.32),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: AnimatedRotation(
                      turns: _isFabOpen ? 0.125 : 0.0,
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutBack,
                      child: Icon(
                        Icons.add_rounded,
                        size: 30.sp,
                        color: AppColors.kWhite,
                      ),
                    ),
                  ),
                ),

                // Right: Settings & Profile
                _BottomNavAction(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  onTap: () => _openSettingsScreen(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BottomNavAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 6.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24.sp,
              color: AppColors.kBlack.withValues(alpha: 0.8),
            ),
            SizedBox(height: 3.h),
            Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.kBlack.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FabBubbleOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _FabBubbleOption({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 11.h),
        decoration: BoxDecoration(
          color: AppColors.kWhite,
          borderRadius: BorderRadius.circular(30.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34.w,
              height: 34.w,
              decoration: BoxDecoration(
                color: backgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 18.sp,
              ),
            ),
            SizedBox(width: 10.w),
            Text(
              label,
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.kBlack,
                fontSize: 14.sp,
              ),
            ),
            SizedBox(width: 4.w),
          ],
        ),
      ),
    );
  }
}
