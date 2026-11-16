import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../routes/router.dart';
import '../storage/local_storage_service.dart';
import '../../features/calories/data/datasources/food_local_datasource.dart';
import '../../features/calories/data/datasources/food_remote_datasource.dart';
import '../../features/calories/data/repositories/food_repository_impl.dart';
import '../../features/calories/domain/repositories/food_repository.dart';
import '../../features/calories/domain/usecases/add_food.dart';
import '../../features/calories/domain/usecases/delete_food.dart';
import '../../features/calories/domain/usecases/detect_food_from_image.dart';
import '../../features/calories/domain/usecases/get_daily_food_log.dart';
import '../../features/calories/domain/usecases/get_weekly_calories.dart';
import '../../features/calories/domain/usecases/update_food.dart';
import '../../features/calories/presentation/cubit/food_log_cubit.dart';

final sl = GetIt.instance;

Future<void> configureDependencies({
  required SharedPreferences prefs,
}) async {
  // External
  sl.registerLazySingleton<SharedPreferences>(() => prefs);
  sl.registerLazySingleton<http.Client>(() => http.Client());

  // Core
  sl.registerLazySingleton<LocalStorageService>(() => LocalStorageService(sl()));
  sl.registerLazySingleton<AppRouter>(() => AppRouter(prefs: sl()));
  sl.registerLazySingleton<GoRouter>(() => sl<AppRouter>().router);

  // Calories
  sl.registerLazySingleton<FoodLocalDataSource>(
    () => FoodLocalDataSource(sl(), sl()),
  );
  sl.registerLazySingleton<FoodRemoteDataSource>(
    () => FoodRemoteDataSource(sl(), client: sl()),
  );
  sl.registerLazySingleton<FoodRepository>(() => FoodRepositoryImpl(sl(), sl()));

  sl.registerLazySingleton<GetDailyFoodLog>(() => GetDailyFoodLog(sl()));
  sl.registerLazySingleton<GetWeeklyCalories>(() => GetWeeklyCalories(sl()));
  sl.registerLazySingleton<AddFood>(() => AddFood(sl()));
  sl.registerLazySingleton<DeleteFood>(() => DeleteFood(sl()));
  sl.registerLazySingleton<UpdateFood>(() => UpdateFood(sl()));
  sl.registerLazySingleton<DetectFoodFromImage>(() => DetectFoodFromImage(sl()));

  sl.registerFactory<FoodLogCubit>(
    () => FoodLogCubit(sl(), sl(), sl(), sl(), sl(), sl())..loadDailyLog(),
  );
}
