import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/practice_reminder_gateway.dart';
import '../../domain/practice_plan/practice_plan.dart';
import 'practice_plan_providers.dart';

final practiceReminderGatewayProvider = Provider<PracticeReminderGateway>((
  ref,
) {
  return const MethodChannelPracticeReminderGateway();
});

/// Keeps Android's persisted alarm schedule aligned with the Drift plans.
///
/// Synchronization happens after every plan-stream change, at cold start, and
/// whenever the app returns to the foreground. Failures are deliberately
/// retried later instead of making the plan database unavailable.
class PracticeReminderCoordinator extends ConsumerStatefulWidget {
  const PracticeReminderCoordinator({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<PracticeReminderCoordinator> createState() =>
      _PracticeReminderCoordinatorState();
}

class _PracticeReminderCoordinatorState
    extends ConsumerState<PracticeReminderCoordinator>
    with WidgetsBindingObserver {
  List<PracticePlan>? _latestPlans;
  bool _synchronizationPending = false;
  Future<void>? _synchronization;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual<AsyncValue<List<PracticePlan>>>(practicePlansProvider, (
      _,
      next,
    ) {
      if (next case AsyncData(:final value)) {
        _latestPlans = value;
        _queueSynchronization();
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _synchronizationPending = false;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _queueSynchronization();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  void _queueSynchronization() {
    if (_latestPlans == null) return;
    _synchronizationPending = true;
    if (_synchronization != null) return;
    final synchronization = _drainSynchronizations();
    _synchronization = synchronization;
    unawaited(
      synchronization.whenComplete(() {
        _synchronization = null;
        if (_synchronizationPending) _queueSynchronization();
      }),
    );
  }

  Future<void> _drainSynchronizations() async {
    while (_synchronizationPending) {
      _synchronizationPending = false;
      final plans = _latestPlans;
      if (plans == null) continue;
      try {
        await ref.read(practiceReminderGatewayProvider).synchronize(plans);
      } on Object {
        // The next plan change or foreground transition retries reconciliation.
      }
    }
  }
}
