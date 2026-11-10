import 'package:cal_scanner/core/di/service_locator.dart';
import 'package:cal_scanner/core/storage/local_storage_service.dart';
import 'package:cal_scanner/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final userProfile = await sl<LocalStorageService>().getUserProfile();
    final isOnboarded = userProfile?.isOnboarded ?? false;

    if (!mounted) return;
    context.go(isOnboarded ? AppRoutes.main : AppRoutes.onboarding);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ClipRRect(
          borderRadius: BorderRadiusGeometry.circular(1000),
          child: Image.asset(Assets.images.splash.path, height: 130.h),
        ),
      ),
    );
  }
}
