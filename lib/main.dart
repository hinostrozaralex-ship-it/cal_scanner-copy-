import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/di/service_locator.dart';
import 'features/calories/presentation/cubit/food_log_cubit.dart';
import 'theme/app_typography.dart';
import 'theme/theme.dart';

Future<void> _loadEnvironmentFile() async {
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Error loading .env file: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _loadEnvironmentFile();

  final prefs = await SharedPreferences.getInstance();
  await configureDependencies(prefs: prefs);

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(MyApp(router: sl<GoRouter>()));
}

class MyApp extends StatelessWidget {
  final GoRouter router;

  const MyApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, child) {
        return BlocProvider(
          create: (_) => sl<FoodLogCubit>(),
          child: MaterialApp.router(
            routerConfig: router,
            theme: buildLightTheme().copyWith(
              textTheme: AppTypography.textTheme,
            ),
            debugShowCheckedModeBanner: false,
            title: 'AI Calorie Tracker',
          ),
        );
      },
    );
  }
}
