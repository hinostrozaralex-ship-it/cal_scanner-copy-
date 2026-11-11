import 'package:cal_scanner/core/di/service_locator.dart';
import 'package:cal_scanner/core/storage/api_key_storage.dart';
import 'package:cal_scanner/theme/app_colors.dart';
import 'package:cal_scanner/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  final TextEditingController _apiKeyController = TextEditingController();
  bool _obscureText = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentKey();
  }

  Future<void> _loadCurrentKey() async {
    final storedKey = await sl<ApiKeyStorage>().getApiKey();
    if (!mounted) return;
    setState(() {
      _apiKeyController.text = storedKey ?? '';
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveApiKey() async {
    await sl<ApiKeyStorage>().saveApiKey(_apiKeyController.text);
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'API Key saved successfully',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.kWhite),
        ),
        backgroundColor: AppColors.kBlack,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.kWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.r),
      ),
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: AppColors.kOrange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    Icons.vpn_key_rounded,
                    color: AppColors.kOrange,
                    size: 22.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    'Gemini API Key',
                    style: AppTypography.headlineSmall.copyWith(
                      fontSize: 18.sp,
                      color: AppColors.kBlack,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close,
                    color: AppColors.kgrey,
                    size: 20.sp,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 14.sp,
                  color: AppColors.kOrange,
                ),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    'Get your free key from Google AI Studio',
                    style: AppTypography.bodySmall.copyWith(
                      fontSize: 12.sp,
                      color: AppColors.kBlack.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 18.h),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              TextField(
                controller: _apiKeyController,
                obscureText: _obscureText,
                cursorColor: AppColors.kOrange,
                style: AppTypography.bodyMedium.copyWith(fontSize: 14.sp),
                decoration: InputDecoration(
                  hintText: 'Paste your Gemini API Key here',
                  hintStyle: AppTypography.bodyMedium.copyWith(
                    fontSize: 14.sp,
                    color: AppColors.kBlack.withValues(alpha: 0.4),
                  ),
                  filled: true,
                  fillColor: AppColors.kScaffold,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.kBlack.withValues(alpha: 0.6),
                      size: 20.sp,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
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
              ),
            SizedBox(height: 22.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 13.h),
                      side: BorderSide(
                        color: AppColors.kBlack.withValues(alpha: 0.2),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.r),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.kBlack,
                        fontSize: 14.sp,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveApiKey,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.kOrange,
                      foregroundColor: AppColors.kWhite,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 13.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.r),
                      ),
                    ),
                    child: Text(
                      'Save',
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.kWhite,
                        fontWeight: FontWeight.w600,
                        fontSize: 14.sp,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
