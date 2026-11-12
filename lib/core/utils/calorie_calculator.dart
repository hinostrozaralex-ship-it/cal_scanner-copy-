class CalorieCalculator {
  /// Calculates the Basal Metabolic Rate (BMR) and estimated daily calorie needs
  /// using the Mifflin-St Jeor Equation
  static int fallbackEstimateCalories({
    required double weight, // in kg
    required double height, // in cm
    required int age,
    required String activityLevel,
    required String gender,
  }) {
    double bmr;

    // Calculate BMR using Mifflin-St Jeor Equation
    if (gender == 'Male') {
      bmr = 88.362 + (13.397 * weight) + (4.799 * height) - (5.677 * age);
    } else if (gender == 'Female') {
      bmr = 447.593 + (9.247 * weight) + (3.098 * height) - (4.330 * age);
    } else {
      // Average BMR for other genders
      double maleBmr = 88.362 + (13.397 * weight) + (4.799 * height) - (5.677 * age);
      double femaleBmr = 447.593 + (9.247 * weight) + (3.098 * height) - (4.330 * age);
      bmr = (maleBmr + femaleBmr) / 2;
    }

    // Determine activity multiplier based on detailed activity levels
    double activityMultiplier = switch (activityLevel) {
      'Sedentary' => 1.2, // Little or no exercise, desk job
      'Light' => 1.375, // Light exercise 1-3 days/week
      'Moderate' => 1.55, // Moderate exercise 3-5 days/week
      'Active' => 1.725, // Heavy exercise 6-7 days/week
      'Very Active' => 1.9, // Very heavy exercise, physical job
      _ => 1.2 // Default to sedentary if unknown
    };

    return (bmr * activityMultiplier).toInt();
  }

  /// Adjusts calories based on the user's goal with scientifically-backed adjustments
  static int calculateCaloriesBasedOnGoal({
    required int maintenanceCalories,
    required String goal,
  }) {
    return switch (goal) {
      'Weight Loss' => (maintenanceCalories * 0.8).round(), // 20% deficit
      'Muscle Gain' => (maintenanceCalories * 1.15).round(), // 15% surplus
      _ => maintenanceCalories // Maintenance
    };
  }

  /// Calculates macronutrient goals based on calorie intake and user goal
  /// Returns values in grams per day
  static Map<String, int> calculateMacroGoals({
    required int calories,
    required String goal,
  }) {
    // Initialize default macro ratios
    double proteinPercent;
    double fatPercent;
    double carbsPercent;

    switch (goal) {
      case 'Weight Loss':
        // Higher protein for muscle preservation during deficit
        proteinPercent = 0.30; // 30% of calories from protein
        fatPercent = 0.25; // 25% of calories from fat
        carbsPercent = 0.45; // 45% of calories from carbs
        break;
      case 'Muscle Gain':
        // Moderate protein, higher carbs for muscle growth
        proteinPercent = 0.25; // 25% of calories from protein
        fatPercent = 0.25; // 25% of calories from fat
        carbsPercent = 0.50; // 50% of calories from carbs
        break;
      default: // Maintenance
        // Balanced distribution
        proteinPercent = 0.25; // 25% of calories from protein
        fatPercent = 0.25; // 25% of calories from fat
        carbsPercent = 0.50; // 50% of calories from carbs
    }

    // Calculate grams of each macronutrient
    // Protein & Carbs = 4 calories per gram
    // Fat = 9 calories per gram
    return {
      'proteinGoal': (calories * proteinPercent / 4).round(),
      'fatGoal': (calories * fatPercent / 9).round(),
      'carbsGoal': (calories * carbsPercent / 4).round(),
    };
  }

  /// Calculates recommended water intake in milliliters based on weight
  static int calculateWaterIntake({
    required double weight, // in kg
    required String activityLevel,
  }) {
    // Base calculation: 30-35ml per kg of body weight
    double baseWater = weight * 33; // Using 33ml as a middle ground

    // Adjust for activity level
    double activityMultiplier = switch (activityLevel) {
      'Sedentary' => 1.0,
      'Light' => 1.1,
      'Moderate' => 1.2,
      'Active' => 1.3,
      'Very Active' => 1.4,
      _ => 1.0
    };

    return (baseWater * activityMultiplier).round();
  }

  /// Estimates recommended protein intake in grams based on weight and activity level
  static int calculateProteinNeeds({
    required double weight, // in kg
    required String activityLevel,
    required String goal,
  }) {
    // Base protein requirements (in g/kg of body weight)
    double proteinMultiplier = switch (goal) {
      'Weight Loss' => 2.0, // Higher protein for muscle preservation
      'Muscle Gain' => 2.2, // Higher protein for muscle growth
      _ => 1.8 // Maintenance
    };

    // Adjust for activity level
    if (activityLevel == 'Active' || activityLevel == 'Very Active') {
      proteinMultiplier += 0.2;
    }

    return (weight * proteinMultiplier).round();
  }

  /// Returns medically safe target weight bounds (in kg) based on current weight,
  /// height (BMI >= 18.5), and safe per-cycle body weight change limits.
  static Map<String, double> getSafeWeightBounds({
    required double currentWeightKg,
    required double heightCm,
    required String goal,
  }) {
    final safeCurrentKg = currentWeightKg > 20 ? currentWeightKg : 70.0;
    final safeHeightM = (heightCm > 100 ? heightCm : 170.0) / 100.0;
    final bmiMinKg = 18.5 * safeHeightM * safeHeightM;

    if (goal == 'Weight Loss') {
      // Max 15% body weight loss in a single cycle, and never below BMI 18.5
      double minKg = safeCurrentKg * 0.85;
      if (bmiMinKg > minKg && bmiMinKg < safeCurrentKg - 0.5) {
        minKg = bmiMinKg;
      }
      final maxKg = (safeCurrentKg - 0.5).clamp(minKg, safeCurrentKg);
      return {
        'minKg': double.parse(minKg.toStringAsFixed(1)),
        'maxKg': double.parse(maxKg.toStringAsFixed(1)),
      };
    } else if (goal == 'Muscle Gain') {
      final minKg = safeCurrentKg + 0.5;
      // Max +12% body weight gain in a single cycle
      double maxKg = safeCurrentKg * 1.12;
      if (maxKg < minKg + 1.0) {
        maxKg = minKg + 2.0;
      }
      return {
        'minKg': double.parse(minKg.toStringAsFixed(1)),
        'maxKg': double.parse(maxKg.toStringAsFixed(1)),
      };
    }

    return {
      'minKg': double.parse(safeCurrentKg.toStringAsFixed(1)),
      'maxKg': double.parse(safeCurrentKg.toStringAsFixed(1)),
    };
  }

  /// Suggests a healthy target weight (in kg) for a given timeframe in weeks.
  /// Standard healthy rates: -0.5 kg/week for weight loss, +0.3 kg/week for muscle gain.
  static double suggestTargetWeightForWeeks({
    required double currentWeightKg,
    required double heightCm,
    required String goal,
    required int weeks,
  }) {
    if (goal == 'Maintenance') return currentWeightKg;

    final bounds = getSafeWeightBounds(
      currentWeightKg: currentWeightKg,
      heightCm: heightCm,
      goal: goal,
    );
    final safeWeeks = weeks.clamp(1, 52);

    if (goal == 'Weight Loss') {
      final rawTarget = currentWeightKg - (safeWeeks * 0.5);
      return rawTarget.clamp(bounds['minKg']!, bounds['maxKg']!);
    } else if (goal == 'Muscle Gain') {
      final rawTarget = currentWeightKg + (safeWeeks * 0.3);
      return rawTarget.clamp(bounds['minKg']!, bounds['maxKg']!);
    }
    return currentWeightKg;
  }

  /// Suggests a healthy number of weeks to reach a target weight (both in kg).
  static int suggestWeeksForTargetWeight({
    required double currentWeightKg,
    required double targetWeightKg,
    required String goal,
  }) {
    if (goal == 'Maintenance') return 0;
    final deltaKg = (targetWeightKg - currentWeightKg).abs();
    if (deltaKg < 0.1) return 1;

    if (goal == 'Weight Loss') {
      return (deltaKg / 0.5).round().clamp(1, 52);
    } else if (goal == 'Muscle Gain') {
      return (deltaKg / 0.3).round().clamp(1, 52);
    }
    return 8;
  }

  /// Calculates daily target calories and macro goals (protein, carbs, fat in grams)
  /// taking into account sex, age, weight, height, goal, target weight, and timeframe.
  static Map<String, int> calculatePlanForProfile({
    required double weightKg,
    required double heightCm,
    required int age,
    required String gender,
    required String goal,
    required double targetWeightKg,
    required int goalWeeks,
  }) {
    final safeWeight = weightKg > 20 ? weightKg : 70.0;
    final safeHeight = heightCm > 100 ? heightCm : 170.0;
    final safeAge = age > 5 ? age : 25;

    final maintenanceCalories = fallbackEstimateCalories(
      weight: safeWeight,
      height: safeHeight,
      age: safeAge,
      activityLevel: 'Light',
      gender: gender,
    );

    int targetCalories = maintenanceCalories;

    if (goal == 'Weight Loss') {
      final deltaKg = (safeWeight - targetWeightKg).clamp(0.5, safeWeight * 0.2);
      final days = (goalWeeks.clamp(1, 52)) * 7;
      final dailyDeficit = ((deltaKg * 7700) / days).round().clamp(250, 750);
      final minSafeCalories = gender == 'Female' ? 1200 : 1500;
      targetCalories = (maintenanceCalories - dailyDeficit).clamp(
        minSafeCalories,
        maintenanceCalories,
      );
    } else if (goal == 'Muscle Gain') {
      final deltaKg = (targetWeightKg - safeWeight).clamp(0.5, safeWeight * 0.2);
      final days = (goalWeeks.clamp(1, 52)) * 7;
      final dailySurplus = ((deltaKg * 7700) / days).round().clamp(200, 500);
      targetCalories = maintenanceCalories + dailySurplus;
    }

    final macros = calculateMacroGoals(
      calories: targetCalories,
      goal: goal,
    );

    return {
      'maintenanceCalories': maintenanceCalories,
      'targetCalories': targetCalories,
      'proteinGoal': macros['proteinGoal'] ?? 125,
      'carbsGoal': macros['carbsGoal'] ?? 250,
      'fatGoal': macros['fatGoal'] ?? 55,
    };
  }
}