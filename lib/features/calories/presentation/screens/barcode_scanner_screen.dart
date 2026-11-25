import 'dart:io';

import 'package:cal_scanner/features/calories/presentation/cubit/food_log_cubit.dart';
import 'package:cal_scanner/features/calories/presentation/screens/manual_meal_screen.dart';
import 'package:cal_scanner/features/calories/presentation/screens/scan_result_screen.dart';
import 'package:cal_scanner/theme/app_colors.dart';
import 'package:cal_scanner/theme/app_typography.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
    ],
  );

  bool _isProcessing = false;
  bool _torchOn = false;
  String? _notFoundBarcode;
  String? _notFoundPartialName;
  String? _lookupError;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || _notFoundBarcode != null) return;

    String? rawCode;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        rawCode = value;
        break;
      }
    }
    if (rawCode == null) return;

    setState(() {
      _isProcessing = true;
      _lookupError = null;
      _notFoundBarcode = null;
      _notFoundPartialName = null;
    });

    final cubit = context.read<FoodLogCubit>();
    final (result, errorMsg) = await cubit.lookupBarcode(rawCode);

    if (!mounted) return;

    if (result != null && result.isFound) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BlocProvider.value(
            value: cubit,
            child: ScanResultScreen(
              initialFood: result.food!,
              associateBarcode: rawCode,
            ),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = false;
      _notFoundBarcode = rawCode;
      _notFoundPartialName = result?.partialName;
      _lookupError = errorMsg;
    });
  }

  Future<void> _scanLabelWithAi() async {
    final code = _notFoundBarcode;
    final partialName = _notFoundPartialName;
    final cubit = context.read<FoodLogCubit>();

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: ScanResultScreen(
            imageFile: File(picked.path),
            labelOnlyMode: true,
            associateBarcode: code,
            initialUserHint: partialName,
          ),
        ),
      ),
    );
  }

  void _openManualFallback() {
    final code = _notFoundBarcode;
    final partialName = _notFoundPartialName;
    final cubit = context.read<FoodLogCubit>();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: ManualMealScreen(
            initialName: partialName,
            associateBarcode: code,
          ),
        ),
      ),
    );
  }

  void _resumeScanning() {
    setState(() {
      _isProcessing = false;
      _notFoundBarcode = null;
      _notFoundPartialName = null;
      _lookupError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),

          // Framing guide overlay
          IgnorePointer(
            child: Center(
              child: Container(
                width: 260.w,
                height: 160.h,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: _isProcessing
                        ? AppColors.kOrange
                        : AppColors.kWhite.withValues(alpha: 0.9),
                    width: 2.5,
                  ),
                ),
              ),
            ),
          ),

          // Top bar (Back & Torch)
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CircleOverlayButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 8.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      'Scan Barcode',
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.kWhite,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5.sp,
                      ),
                    ),
                  ),
                  _CircleOverlayButton(
                    icon: _torchOn
                        ? Icons.flash_on_rounded
                        : Icons.flash_off_rounded,
                    onTap: () async {
                      await _scannerController.toggleTorch();
                      if (mounted) {
                        setState(() => _torchOn = !_torchOn);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          // Bottom hint or loading or not-found fallback sheet
          Positioned(
            left: 16.w,
            right: 16.w,
            bottom: 24.h,
            child: SafeArea(
              top: false,
              child: _isProcessing
                  ? _StatusPill(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CupertinoActivityIndicator(
                            color: Colors.white,
                            radius: 10,
                          ),
                          SizedBox(width: 10.w),
                          Text(
                            'Looking up product...',
                            style: AppTypography.titleSmall.copyWith(
                              color: AppColors.kWhite,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _notFoundBarcode != null
                  ? _NotFoundFallbackCard(
                      barcode: _notFoundBarcode!,
                      partialName: _notFoundPartialName,
                      errorMessage: _lookupError,
                      onScanLabel: _scanLabelWithAi,
                      onEnterManual: _openManualFallback,
                      onRetry: _resumeScanning,
                    )
                  : _StatusPill(
                      child: Text(
                        'Point camera at the product barcode (EAN / UPC)',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.kWhite,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5.sp,
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

class _CircleOverlayButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleOverlayButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42.w,
        height: 42.w,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.kWhite, size: 22.sp),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final Widget child;
  const _StatusPill({required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(24.r),
        ),
        child: child,
      ),
    );
  }
}

class _NotFoundFallbackCard extends StatelessWidget {
  final String barcode;
  final String? partialName;
  final String? errorMessage;
  final VoidCallback onScanLabel;
  final VoidCallback onEnterManual;
  final VoidCallback onRetry;

  const _NotFoundFallbackCard({
    required this.barcode,
    this.partialName,
    this.errorMessage,
    required this.onScanLabel,
    required this.onEnterManual,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final title = errorMessage != null
        ? 'Connection Issue'
        : (partialName != null && partialName!.isNotEmpty
              ? 'Missing Nutrition Data'
              : 'Product Not Found');

    final subtitle = errorMessage ??
        (partialName != null && partialName!.isNotEmpty
            ? '"$partialName" ($barcode) has no macros in the database. Scan its nutrition label once and we will remember it!'
            : 'Barcode $barcode is not in Open Food Facts yet. Scan its nutrition label once and we will remember it for next time!');

    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: AppColors.kWhite,
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: AppColors.kOrange.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  Icons.qr_code_2_rounded,
                  color: AppColors.kOrange,
                  size: 20.sp,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.kBlack,
                  ),
                ),
              ),
              IconButton(
                onPressed: onRetry,
                icon: const Icon(Icons.close_rounded),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            subtitle,
            style: AppTypography.bodySmall.copyWith(
              fontSize: 12.5.sp,
              color: AppColors.kBlack.withValues(alpha: 0.7),
            ),
          ),
          SizedBox(height: 14.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onScanLabel,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.kOrange,
                foregroundColor: AppColors.kWhite,
                elevation: 0,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
              icon: Icon(Icons.document_scanner_rounded, size: 19.sp),
              label: Text(
                'Scan Nutrition Label (AI)',
                style: AppTypography.titleSmall.copyWith(
                  color: AppColors.kWhite,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onEnterManual,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.kBlack,
                    side: BorderSide(
                      color: AppColors.kBlack.withValues(alpha: 0.2),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    'Enter Manually',
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5.sp,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: OutlinedButton(
                  onPressed: onRetry,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.kBlack,
                    side: BorderSide(
                      color: AppColors.kBlack.withValues(alpha: 0.2),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    'Scan Another',
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5.sp,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
