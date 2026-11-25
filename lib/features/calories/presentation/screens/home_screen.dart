// home_screen.dart

import 'dart:io';

import 'package:cal_scanner/core/extensions/widget_extension.dart';
import 'package:cal_scanner/features/calories/presentation/cubit/food_log_cubit.dart';
import 'package:cal_scanner/features/calories/presentation/cubit/food_log_state.dart';
import 'package:cal_scanner/features/calories/presentation/screens/barcode_scanner_screen.dart';
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

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _profileRefreshTick = 0;
  bool _isFabOpen = false;
  bool _showCameraSubmenu = false;

  late final AnimationController _fabController;
  late final AnimationController _cameraSubController;
  late final Animation<double> _scrimFade;
  late final Animation<double> _fanCurve;
  late final Animation<double> _subFanCurve;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _cameraSubController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 180),
    );

    _scrimFade = CurvedAnimation(
      parent: _fabController,
      curve: Curves.easeOut,
    );
    _fanCurve = CurvedAnimation(
      parent: _fabController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );
    _subFanCurve = CurvedAnimation(
      parent: _cameraSubController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _fabController.dispose();
    _cameraSubController.dispose();
    super.dispose();
  }

  void _toggleFabMenu() {
    if (_isFabOpen) {
      _closeFabMenu();
    } else {
      setState(() {
        _isFabOpen = true;
        _showCameraSubmenu = false;
      });
      _cameraSubController.reset();
      _fabController.forward();
    }
  }

  void _openCameraSubmenu() {
    setState(() => _showCameraSubmenu = true);
    _cameraSubController.forward();
  }

  Future<void> _closeFabMenu() async {
    if (!_isFabOpen) return;
    setState(() => _isFabOpen = false);
    await Future.wait([
      _fabController.reverse(),
      if (_showCameraSubmenu) _cameraSubController.reverse(),
    ]);
    if (mounted) {
      setState(() => _showCameraSubmenu = false);
    }
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

  void _openBarcodeScanner(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<FoodLogCubit>(),
          child: const BarcodeScannerScreen(),
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

          // Animated scrim & radial fan speed-dial menu
          AnimatedBuilder(
            animation: Listenable.merge([_fabController, _cameraSubController]),
            builder: (context, _) {
              if (_fabController.isDismissed) {
                return const SizedBox.shrink();
              }

              final fanT = _fanCurve.value.clamp(0.0, 1.2);
              final subT = _subFanCurve.value.clamp(0.0, 1.2);
              final level1Opacity =
                  (_fabController.value * (1.0 - _cameraSubController.value))
                      .clamp(0.0, 1.0);
              final level2Opacity =
                  (_fabController.value * _cameraSubController.value)
                      .clamp(0.0, 1.0);

              return Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _closeFabMenu,
                      child: FadeTransition(
                        opacity: _scrimFade,
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.34),
                        ),
                      ),
                    ),
                  ),

                  // Level 1: 3-option radial fan (Barcode, Camera, Manual)
                  if (level1Opacity > 0.01) ...[
                    _RadialFanItem(
                      offset: Offset(-102.w * fanT, -26.h * fanT),
                      scale: fanT * (1.0 - 0.35 * _cameraSubController.value),
                      opacity: level1Opacity,
                      icon: Icons.qr_code_scanner_rounded,
                      label: 'Barcode',
                      backgroundColor: Colors.green.shade600,
                      onTap: () async {
                        await _closeFabMenu();
                        if (context.mounted) {
                          _openBarcodeScanner(context);
                        }
                      },
                    ),
                    _RadialFanItem(
                      offset: Offset(0, -104.h * fanT),
                      scale: fanT * (1.0 - 0.35 * _cameraSubController.value),
                      opacity: level1Opacity,
                      icon: CupertinoIcons.camera_fill,
                      label: 'Camera',
                      backgroundColor: AppColors.kOrange,
                      onTap: _openCameraSubmenu,
                    ),
                    _RadialFanItem(
                      offset: Offset(102.w * fanT, -26.h * fanT),
                      scale: fanT * (1.0 - 0.35 * _cameraSubController.value),
                      opacity: level1Opacity,
                      icon: Icons.edit_note_rounded,
                      label: 'Manual',
                      backgroundColor: AppColors.kBlack,
                      onTap: () async {
                        await _closeFabMenu();
                        if (context.mounted) {
                          _openManualEntryScreen(context);
                        }
                      },
                    ),
                  ],

                  // Level 2: Camera submenu (Take Photo, Select Photo)
                  if (level2Opacity > 0.01) ...[
                    _RadialFanItem(
                      offset: Offset(-82.w * subT, -62.h * subT),
                      scale: subT,
                      opacity: level2Opacity,
                      icon: CupertinoIcons.camera_viewfinder,
                      label: 'Take Photo',
                      backgroundColor: AppColors.kOrange,
                      onTap: () async {
                        await _closeFabMenu();
                        if (context.mounted) {
                          _pickAndScanImage(context, ImageSource.camera);
                        }
                      },
                    ),
                    _RadialFanItem(
                      offset: Offset(82.w * subT, -62.h * subT),
                      scale: subT,
                      opacity: level2Opacity,
                      icon: CupertinoIcons.photo_fill,
                      label: 'Select Photo',
                      backgroundColor: AppColors.kBlack,
                      onTap: () async {
                        await _closeFabMenu();
                        if (context.mounted) {
                          _pickAndScanImage(context, ImageSource.gallery);
                        }
                      },
                    ),
                  ],
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

class _RadialFanItem extends StatelessWidget {
  final Offset offset;
  final double scale;
  final double opacity;
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final VoidCallback onTap;

  const _RadialFanItem({
    required this.offset,
    required this.scale,
    required this.opacity,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 18.h,
      child: Center(
        child: Transform.translate(
          offset: offset,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale.clamp(0.0, 1.2),
              child: GestureDetector(
                onTap: onTap,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 54.w,
                      height: 54.w,
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.22),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        icon,
                        color: AppColors.kWhite,
                        size: 24.sp,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.kWhite,
                        borderRadius: BorderRadius.circular(12.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        label,
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.kBlack,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
