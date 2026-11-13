import 'package:cal_scanner/core/di/service_locator.dart';
import 'package:cal_scanner/features/calories/data/datasources/food_remote_datasource.dart';
import 'package:cal_scanner/features/calories/domain/entities/food.dart';
import 'package:cal_scanner/theme/app_colors.dart';
import 'package:cal_scanner/theme/app_typography.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MealIngredientsEditor extends StatelessWidget {
  final List<FoodIngredient> ingredients;
  final ValueChanged<List<FoodIngredient>> onIngredientsChanged;

  const MealIngredientsEditor({
    super.key,
    required this.ingredients,
    required this.onIngredientsChanged,
  });

  double _stepForUnit(String unit, double baseSize) {
    final lower = unit.toLowerCase();
    if (lower == 'g' || lower == 'ml' || baseSize >= 25) {
      return 10.0;
    }
    return 0.5;
  }

  void _updateIngredientQuantity(int index, double newQty) {
    final updated = List<FoodIngredient>.from(ingredients);
    updated[index] = updated[index].withQuantity(newQty);
    onIngredientsChanged(updated);
  }

  void _removeIngredient(int index) {
    final updated = List<FoodIngredient>.from(ingredients)..removeAt(index);
    onIngredientsChanged(updated);
  }

  Future<void> _showAddIngredientSheet(BuildContext context) async {
    final added = await showModalBottomSheet<FoodIngredient>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.kWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      ),
      builder: (_) => const _AddIngredientSheet(),
    );

    if (added != null) {
      final updated = [...ingredients, added];
      onIngredientsChanged(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.kWhite,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.kBlack.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.restaurant_menu_rounded,
                    size: 18.sp,
                    color: AppColors.kOrange,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    'Meal Ingredients (${ingredients.length})',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.kBlack,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => _showAddIngredientSheet(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.kOrange,
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(Icons.add_circle_outline, size: 17.sp),
                label: Text(
                  'Add Item',
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
            'Adjust quantities or add extra items to recalculate totals automatically.',
            style: AppTypography.bodySmall.copyWith(
              fontSize: 11.5.sp,
              color: AppColors.kBlack.withValues(alpha: 0.55),
            ),
          ),
          SizedBox(height: 12.h),
          if (ingredients.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12.h),
              child: Center(
                child: Text(
                  'No ingredients listed yet. Tap "+ Add Item" to add components.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.kBlack.withValues(alpha: 0.5),
                  ),
                ),
              ),
            )
          else
            ...List.generate(ingredients.length, (index) {
              final item = ingredients[index];
              final step = _stepForUnit(item.servingUnit, item.servingSize);
              return _IngredientRowItem(
                key: ValueKey(item.id),
                ingredient: item,
                step: step,
                onQuantityChanged: (q) => _updateIngredientQuantity(index, q),
                onDelete: () => _removeIngredient(index),
              );
            }),
        ],
      ),
    );
  }
}

class _IngredientRowItem extends StatefulWidget {
  final FoodIngredient ingredient;
  final double step;
  final ValueChanged<double> onQuantityChanged;
  final VoidCallback onDelete;

  const _IngredientRowItem({
    super.key,
    required this.ingredient,
    required this.step,
    required this.onQuantityChanged,
    required this.onDelete,
  });

  @override
  State<_IngredientRowItem> createState() => _IngredientRowItemState();
}

class _IngredientRowItemState extends State<_IngredientRowItem> {
  late final TextEditingController _qtyController;

  String _formatQty(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(
      text: _formatQty(widget.ingredient.quantity),
    );
  }

  @override
  void didUpdateWidget(covariant _IngredientRowItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentParsed = double.tryParse(
      _qtyController.text.replaceAll(',', '.'),
    );
    if (currentParsed != widget.ingredient.quantity) {
      _qtyController.text = _formatQty(widget.ingredient.quantity);
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  void _stepQuantity(double delta) {
    final minVal = widget.step >= 10.0 ? 5.0 : 0.5;
    final next = (widget.ingredient.quantity + delta).clamp(minVal, 10000.0);
    _qtyController.text = _formatQty(next);
    widget.onQuantityChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.ingredient;
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.kScaffold,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.kBlack.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5.sp,
                    color: AppColors.kBlack,
                  ),
                ),
              ),
              Text(
                '${item.calories.round()} kcal',
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.sp,
                  color: AppColors.kOrange,
                ),
              ),
              SizedBox(width: 6.w),
              InkWell(
                onTap: widget.onDelete,
                borderRadius: BorderRadius.circular(8.r),
                child: Padding(
                  padding: EdgeInsets.all(4.w),
                  child: Icon(
                    CupertinoIcons.trash,
                    size: 16.sp,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'P: ${item.protein.round()}g  •  C: ${item.carbs.round()}g  •  F: ${item.fat.round()}g',
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 11.5.sp,
                  color: AppColors.kBlack.withValues(alpha: 0.6),
                ),
              ),
              Row(
                children: [
                  _MiniStepButton(
                    icon: Icons.remove,
                    onTap: () => _stepQuantity(-widget.step),
                  ),
                  SizedBox(width: 6.w),
                  SizedBox(
                    width: 58.w,
                    child: TextField(
                      controller: _qtyController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textAlign: TextAlign.center,
                      onChanged: (txt) {
                        final val = double.tryParse(
                          txt.trim().replaceAll(',', '.'),
                        );
                        if (val != null && val >= 0) {
                          widget.onQuantityChanged(val);
                        }
                      },
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.sp,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 6.h,
                        ),
                        filled: true,
                        fillColor: AppColors.kWhite,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          borderSide: BorderSide(
                            color: AppColors.kBlack.withValues(alpha: 0.12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 6.w),
                  _MiniStepButton(
                    icon: Icons.add,
                    onTap: () => _stepQuantity(widget.step),
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    item.servingUnit,
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.kOrange,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MiniStepButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        width: 26.w,
        height: 26.w,
        decoration: BoxDecoration(
          color: AppColors.kBlack,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Icon(
          icon,
          color: AppColors.kWhite,
          size: 15.sp,
        ),
      ),
    );
  }
}

class _AddIngredientSheet extends StatefulWidget {
  const _AddIngredientSheet();

  @override
  State<_AddIngredientSheet> createState() => _AddIngredientSheetState();
}

class _AddIngredientSheetState extends State<_AddIngredientSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController(
    text: '100',
  );
  final TextEditingController _calController = TextEditingController(text: '0');
  final TextEditingController _protController = TextEditingController(
    text: '0',
  );
  final TextEditingController _carbsController = TextEditingController(
    text: '0',
  );
  final TextEditingController _fatController = TextEditingController(text: '0');

  String _unit = 'g';
  bool _isEstimating = false;
  String? _aiError;

  @override
  void dispose() {
    _nameController.dispose();
    _qtyController.dispose();
    _calController.dispose();
    _protController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  Future<void> _estimateWithAi() async {
    final name = _nameController.text.trim();
    final qty = _qtyController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _aiError = 'Please enter the ingredient name first (e.g. Avocado).';
      });
      return;
    }

    setState(() {
      _isEstimating = true;
      _aiError = null;
    });

    final query = '$name (${qty.isEmpty ? "100" : qty} $_unit)';
    final result = await sl<FoodRemoteDataSource>().estimateFoodFromText(query);

    if (!mounted) return;
    result.fold(
      (failure) {
        setState(() {
          _isEstimating = false;
          _aiError = failure.message;
        });
      },
      (food) {
        setState(() {
          _isEstimating = false;
          _nameController.text = food.name;
          _qtyController.text = food.servingSize.round().toString();
          _unit = food.servingUnit.isNotEmpty ? food.servingUnit : _unit;
          _calController.text = food.calories.round().toString();
          _protController.text = food.protein.round().toString();
          _carbsController.text = food.carbs.round().toString();
          _fatController.text = food.fat.round().toString();
        });
      },
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _aiError = 'Please enter an ingredient name.';
      });
      return;
    }

    final qty =
        double.tryParse(_qtyController.text.trim().replaceAll(',', '.')) ??
        100.0;
    final safeQty = qty > 0 ? qty : 100.0;
    final cal =
        double.tryParse(_calController.text.trim().replaceAll(',', '.')) ?? 0.0;
    final prot =
        double.tryParse(_protController.text.trim().replaceAll(',', '.')) ??
        0.0;
    final carbs =
        double.tryParse(_carbsController.text.trim().replaceAll(',', '.')) ??
        0.0;
    final fat =
        double.tryParse(_fatController.text.trim().replaceAll(',', '.')) ?? 0.0;

    final ingredient = FoodIngredient(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      quantity: safeQty,
      servingSize: safeQty,
      servingUnit: _unit,
      calories: cal,
      protein: prot,
      carbs: carbs,
      fat: fat,
      baseCalories: cal,
      baseProtein: prot,
      baseCarbs: carbs,
      baseFat: fat,
    );

    Navigator.of(context).pop(ingredient);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(
        left: 20.w,
        right: 20.w,
        top: 16.h,
        bottom: bottomInset + 20.h,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.kBlack.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
            ),
            SizedBox(height: 14.h),
            Text(
              'Add Ingredient to Meal',
              style: AppTypography.headlineSmall.copyWith(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Ingredient Name (e.g. Fried Egg, Avocado)',
                filled: true,
                fillColor: AppColors.kScaffold,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.r),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: 10.h),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _qtyController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      filled: true,
                      fillColor: AppColors.kScaffold,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.r),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _unit,
                    decoration: InputDecoration(
                      labelText: 'Unit',
                      filled: true,
                      fillColor: AppColors.kScaffold,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.r),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'g', child: Text('g')),
                      DropdownMenuItem(value: 'ml', child: Text('ml')),
                      DropdownMenuItem(value: 'unit', child: Text('unit')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _unit = val);
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isEstimating ? null : _estimateWithAi,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.kOrange,
                  side: const BorderSide(color: AppColors.kOrange),
                  padding: EdgeInsets.symmetric(vertical: 11.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
                icon: _isEstimating
                    ? const CupertinoActivityIndicator(radius: 9)
                    : Icon(Icons.auto_awesome, size: 18.sp),
                label: Text(
                  _isEstimating
                      ? 'Calculating with AI...'
                      : 'Auto-calculate Macros with AI',
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.kOrange,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (_aiError != null) ...[
              SizedBox(height: 6.h),
              Text(
                _aiError!,
                style: TextStyle(color: Colors.red, fontSize: 12.sp),
              ),
            ],
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: _MiniMacroField(
                    controller: _calController,
                    label: 'Calories',
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: _MiniMacroField(
                    controller: _protController,
                    label: 'Protein (g)',
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: _MiniMacroField(
                    controller: _carbsController,
                    label: 'Carbs (g)',
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: _MiniMacroField(
                    controller: _fatController,
                    label: 'Fat (g)',
                  ),
                ),
              ],
            ),
            SizedBox(height: 18.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.kBlack,
                  foregroundColor: AppColors.kWhite,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
                child: Text(
                  'Add to Meal',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.kWhite,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMacroField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _MiniMacroField({
    required this.controller,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 10.5.sp),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 10.h),
        filled: true,
        fillColor: AppColors.kScaffold,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
