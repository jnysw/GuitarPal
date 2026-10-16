import 'dart:io';

import 'package:flutter/services.dart';

import '../../domain/practice_plan/practice_plan.dart';

enum ReminderPermissionStatus { granted, denied, unsupported }

abstract interface class PracticeReminderGateway {
  Future<ReminderPermissionStatus> requestPermission();

  Future<void> synchronize(Iterable<PracticePlan> plans);

  Future<void> cancelAll();
}

class MethodChannelPracticeReminderGateway implements PracticeReminderGateway {
  const MethodChannelPracticeReminderGateway();

  static const _channel = MethodChannel('com.guitarpal/practice_reminders');

  @override
  Future<ReminderPermissionStatus> requestPermission() async {
    if (!Platform.isAndroid) return ReminderPermissionStatus.unsupported;
    try {
      final granted =
          await _channel.invokeMethod<bool>('requestPermission') ?? false;
      return granted
          ? ReminderPermissionStatus.granted
          : ReminderPermissionStatus.denied;
    } on MissingPluginException {
      return ReminderPermissionStatus.unsupported;
    }
  }

  @override
  Future<void> synchronize(Iterable<PracticePlan> plans) async {
    if (!Platform.isAndroid) return;
    final reminders = plans
        .where((plan) => plan.reminderTime != null)
        .map(
          (plan) => <String, Object>{
            'planId': plan.id,
            'title': plan.name,
            'sourceId': plan.sourceId,
            'startDay': plan.startDate.dayKey,
            'endDay': plan.endDate.dayKey,
            'weekdayMask': plan.repeatWeekdays.fold<int>(
              0,
              (mask, day) => mask | (1 << (day - 1)),
            ),
            'minuteOfDay': plan.reminderTime!.minutesSinceMidnight,
          },
        )
        .toList(growable: false);
    await _channel.invokeMethod<void>('synchronize', {'reminders': reminders});
  }

  @override
  Future<void> cancelAll() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('cancelAll');
  }
}
