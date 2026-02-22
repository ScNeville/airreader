import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:airreader/blocs/survey_bloc.dart';
import 'package:airreader/models/network_performance.dart';
import 'package:airreader/services/network_performance_service.dart';

// ============================================================================
// State
// ============================================================================

class PerformanceState extends Equatable {
  const PerformanceState({
    this.performance,
    this.isComputing = false,
    this.disabledClientIds = const {},
  });

  final NetworkPerformance? performance;
  final bool isComputing;

  /// Client IDs that have been toggled off in the simulation.
  /// Excluded from air-time contention so remaining clients get more bandwidth.
  final Set<String> disabledClientIds;

  PerformanceState copyWith({
    NetworkPerformance? performance,
    bool? isComputing,
    Set<String>? disabledClientIds,
  }) {
    return PerformanceState(
      performance: performance ?? this.performance,
      isComputing: isComputing ?? this.isComputing,
      disabledClientIds: disabledClientIds ?? this.disabledClientIds,
    );
  }

  @override
  List<Object?> get props => [performance, isComputing, disabledClientIds];
}

// ============================================================================
// Cubit
// ============================================================================

/// Listens to [SurveyBloc] and recomputes [NetworkPerformance] whenever the
/// survey changes, with a 400 ms debounce to avoid thrashing.
class PerformanceCubit extends Cubit<PerformanceState> {
  PerformanceCubit(this._surveyBloc) : super(const PerformanceState()) {
    _subscription = _surveyBloc.stream.listen(_onSurveyChanged);
    // Compute once immediately for the initial state.
    _schedule(_surveyBloc.state);
  }

  final SurveyBloc _surveyBloc;
  late final StreamSubscription<SurveyState> _subscription;
  Timer? _debounce;

  void _onSurveyChanged(SurveyState surveyState) => _schedule(surveyState);

  void _schedule(SurveyState surveyState) {
    _debounce?.cancel();
    if (!isClosed) emit(state.copyWith(isComputing: true));
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (isClosed) return;
      final result = NetworkPerformanceService.compute(
        surveyState.survey,
        disabledClientIds: state.disabledClientIds,
      );
      emit(state.copyWith(performance: result, isComputing: false));
    });
  }

  /// Toggle a client device on or off in the simulation.
  ///
  /// When off, the client is removed from air-time contention on its AP so
  /// remaining clients see higher effective throughput.  The disabled client
  /// still shows its theoretical PHY rate in the panel.
  void toggleClientDisabled(String clientId) {
    final updated = Set<String>.from(state.disabledClientIds);
    if (updated.contains(clientId)) {
      updated.remove(clientId);
    } else {
      updated.add(clientId);
    }
    emit(state.copyWith(disabledClientIds: updated, isComputing: true));
    _schedule(_surveyBloc.state);
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    _subscription.cancel();
    return super.close();
  }
}
