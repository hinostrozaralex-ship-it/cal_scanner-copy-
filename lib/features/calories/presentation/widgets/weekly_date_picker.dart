import 'package:cal_scanner/core/extensions/widget_extension.dart';
import 'package:cal_scanner/features/calories/presentation/cubit/weeklydatepicker_cubit.dart';
import 'package:cal_scanner/theme/app_colors.dart';
import 'package:cal_scanner/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class WeekDatePicker extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const WeekDatePicker({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  State<WeekDatePicker> createState() => _WeekDatePickerState();
}

class _WeekDatePickerState extends State<WeekDatePicker> {
  late final ScrollController _scrollController;
  late final WeekDatePickerCubit _cubit;

  static const double _itemWidth = 60.0;

  @override
  void initState() {
    super.initState();
    _cubit = WeekDatePickerCubit(initialSelectedDate: widget.selectedDate);

    final today = DateTime.now();
    final startDate = DateTime(today.year, 1, 1);
    final todayIndex = today.difference(startDate).inDays;

    final initialOffset = (todayIndex * _itemWidth) - 160;
    _scrollController = ScrollController(
      initialScrollOffset: initialOffset < 0 ? 0 : initialOffset,
    );

    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant WeekDatePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isSameDay(oldWidget.selectedDate, widget.selectedDate)) {
      _cubit.selectDate(widget.selectedDate);
    }
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final dates = _cubit.state.dates;
    final centerIndex = ((offset + 160) / _itemWidth).floor().clamp(
      0,
      dates.length - 1,
    );
    _cubit.updateVisibleMonth(dates[centerIndex]);
  }

  void _jumpToToday() {
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final startDate = DateTime(today.year, 1, 1);
    final todayIndex = normalizedToday.difference(startDate).inDays;
    final targetOffset = (todayIndex * _itemWidth) - 160;

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        targetOffset < 0 ? 0 : targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    _cubit.selectDate(normalizedToday);
    widget.onDateSelected(normalizedToday);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _cubit.close();
    super.dispose();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isToday(DateTime date) => _isSameDay(date, DateTime.now());

  String _dayLabel(DateTime date) {
    const labels = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];
    return labels[date.weekday - 1];
  }

  String _monthYearLabel(DateTime date) {
    const months = [
      'ENERO',
      'FEBRERO',
      'MARZO',
      'ABRIL',
      'MAYO',
      'JUNIO',
      'JULIO',
      'AGOSTO',
      'SEPTIEMBRE',
      'OCTUBRE',
      'NOVIEMBRE',
      'DICIEMBRE',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final dateColor = AppColors.kOrange;
    final today = DateTime.now();

    return BlocBuilder<WeekDatePickerCubit, WeekDatePickerState>(
      bloc: _cubit,
      builder: (context, state) {
        final isSelectedToday = _isToday(state.selectedDate);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _monthYearLabel(state.visibleMonthDate),
                  style: AppTypography.headlineSmall.copyWith(color: dateColor),
                ),
                GestureDetector(
                  onTap: _jumpToToday,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 5.h,
                    ),
                    decoration: BoxDecoration(
                      color: isSelectedToday
                          ? dateColor.withValues(alpha: 0.14)
                          : AppColors.kBlack,
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.today_rounded,
                          size: 14.sp,
                          color: isSelectedToday ? dateColor : AppColors.kWhite,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          'Hoy',
                          style: AppTypography.labelMedium.copyWith(
                            color:
                                isSelectedToday ? dateColor : AppColors.kWhite,
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ).paddingSymmetric(horizontal: 20.w),
            SizedBox(height: 6.h),
            SizedBox(
              height: 60.h,
              child: ListView.builder(
                padding: pagePadding,
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                itemCount: state.dates.length,
                itemExtent: _itemWidth,
                itemBuilder: (context, index) {
                  final date = state.dates[index];
                  final isSelected = _isSameDay(date, state.selectedDate);
                  final isToday = _isToday(date);
                  final isFuture = date.isAfter(today);

                  return GestureDetector(
                    onTap: isFuture
                        ? null
                        : () {
                            _cubit.selectDate(date);
                            widget.onDateSelected(date);
                          },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: isSelected ? dateColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _dayLabel(date),
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? AppColors.kWhite
                                  : isFuture
                                      ? AppColors.kgrey
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${date.day}',
                            style: AppTypography.bodyLarge.copyWith(
                              fontWeight: isSelected || isToday
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppColors.kWhite
                                  : isFuture
                                      ? AppColors.kgrey
                                      : AppColors.kBlack,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
