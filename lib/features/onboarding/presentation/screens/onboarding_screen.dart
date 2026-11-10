import 'package:cal_scanner/app_widgets/buttons/app_button.dart';
import 'package:cal_scanner/core/di/service_locator.dart';
import 'package:cal_scanner/core/routes/app_routes.dart';
import 'package:cal_scanner/core/storage/local_storage_service.dart';
import 'package:cal_scanner/theme/app_colors.dart';
import 'package:cal_scanner/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  // Campo de API Key completamente vacío por requerimiento de primera ejecución
  final TextEditingController _apiKeyController = TextEditingController();

  String _unitSystem = 'metric'; // 'metric' (kg/cm) o 'imperial' (lbs/in)
  bool _obscureApiKey = true;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _toggleUnitSystem(String targetSystem) {
    if (_unitSystem == targetSystem) return;

    final currentWeight = double.tryParse(
      _weightController.text.replaceAll(',', '.'),
    );
    final currentHeight = double.tryParse(
      _heightController.text.replaceAll(',', '.'),
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
    });
  }

  Future<void> _completeOnboarding() async {
    final name = _nameController.text.trim();
    final age = int.tryParse(_ageController.text.trim());
    final weight = double.tryParse(
      _weightController.text.trim().replaceAll(',', '.'),
    );
    final height = double.tryParse(
      _heightController.text.trim().replaceAll(',', '.'),
    );

    if (name.isEmpty ||
        age == null ||
        age <= 0 ||
        weight == null ||
        weight <= 0 ||
        height == null ||
        height <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Por favor, completa tu nombre, edad, peso y talla',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.kWhite),
          ),
          backgroundColor: AppColors.kBlack,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final profile = UserProfile(
      name: name,
      age: age,
      weight: weight,
      height: height,
      unitSystem: _unitSystem,
      apiKey: _apiKeyController.text.trim(),
      isOnboarded: true,
    );

    await sl<LocalStorageService>().saveUserProfile(profile);
    if (!mounted) return;
    context.go(AppRoutes.main);
  }

  @override
  Widget build(BuildContext context) {
    final isMetric = _unitSystem == 'metric';
    final weightUnit = isMetric ? 'kg' : 'lbs';
    final heightUnit = isMetric ? 'cm' : 'in';

    return Scaffold(
      backgroundColor: AppColors.kScaffold,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 8.h),
              Text(
                'Bienvenido a Cal AI',
                style: AppTypography.displaySmall.copyWith(
                  fontSize: 26.sp,
                  color: AppColors.kBlack,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                'Configura tu perfil y tu clave de Gemini para comenzar a escanear tus comidas.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.kBlack.withValues(alpha: 0.65),
                  fontSize: 13.5.sp,
                ),
              ),
              SizedBox(height: 22.h),

              // Selector de Sistema de Unidades
              Text(
                'Sistema de Unidades',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.kBlack,
                ),
              ),
              SizedBox(height: 8.h),
              _UnitSystemSelector(
                unitSystem: _unitSystem,
                onChanged: _toggleUnitSystem,
              ),
              SizedBox(height: 20.h),

              // Nombre / Alias
              _FieldLabel('Nombre / Alias'),
              SizedBox(height: 6.h),
              _StyledInputField(
                controller: _nameController,
                hintText: 'Ej. Alex',
                keyboardType: TextInputType.name,
                prefixIcon: Icons.person_outline,
              ),
              SizedBox(height: 16.h),

              // Edad, Peso y Talla
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FieldLabel('Edad'),
                        SizedBox(height: 6.h),
                        _StyledInputField(
                          controller: _ageController,
                          hintText: '25',
                          suffixText: 'años',
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FieldLabel('Peso ($weightUnit)'),
                        SizedBox(height: 6.h),
                        _StyledInputField(
                          controller: _weightController,
                          hintText: isMetric ? '70' : '154',
                          suffixText: weightUnit,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FieldLabel('Talla ($heightUnit)'),
                        SizedBox(height: 6.h),
                        _StyledInputField(
                          controller: _heightController,
                          hintText: isMetric ? '170' : '67',
                          suffixText: heightUnit,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 22.h),

              // Gemini API Key
              Row(
                children: [
                  Icon(
                    Icons.vpn_key_rounded,
                    size: 18.sp,
                    color: AppColors.kOrange,
                  ),
                  SizedBox(width: 6.w),
                  _FieldLabel('Gemini API Key'),
                ],
              ),
              SizedBox(height: 4.h),
              Text(
                'Obtén tu clave gratuita en Google AI Studio',
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 12.sp,
                  color: AppColors.kBlack.withValues(alpha: 0.6),
                ),
              ),
              SizedBox(height: 8.h),
              _StyledInputField(
                controller: _apiKeyController,
                hintText: 'Pega tu Gemini API Key aquí',
                obscureText: _obscureApiKey,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureApiKey ? Icons.visibility_off : Icons.visibility,
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
              SizedBox(height: 32.h),

              AppButton(
                text: 'Comenzar',
                onTap: _completeOnboarding,
              ),
              SizedBox(height: 16.h),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

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

class _UnitSystemSelector extends StatelessWidget {
  final String unitSystem;
  final ValueChanged<String> onChanged;

  const _UnitSystemSelector({
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
                  'Métrico (kg / cm)',
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

class _StyledInputField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final String? suffixText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final bool obscureText;

  const _StyledInputField({
    required this.controller,
    required this.hintText,
    this.suffixText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
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
