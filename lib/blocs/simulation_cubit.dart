import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:airreader/blocs/survey_bloc.dart';
import 'package:airreader/models/signal_map.dart';
import 'package:airreader/models/survey.dart';
import 'package:airreader/services/rf_simulation_service.dart';

// ============================================================================
// State
// ============================================================================

class SimulationState extends Equatable {
  const SimulationState({this.signalMap, this.isComputing = false});

  final SignalMap? signalMap;
  final bool isComputing;

  SimulationState copyWith({SignalMap? signalMap, bool? isComputing}) =>
      SimulationState(
        signalMap: signalMap ?? this.signalMap,
        isComputing: isComputing ?? this.isComputing,
      );

  @override
  List<Object?> get props => [signalMap, isComputing];
}

// ============================================================================
// Cubit
// ============================================================================

/// Listens to [SurveyBloc] and triggers RF recomputation whenever the survey
/// data changes (APs moved/configured, walls modified, floor plan imported).
///
/// Computation runs in a background isolate. Rapid changes are debounced so
/// that dragging an AP doesn't spawn a new isolate on every pointer event.
class SimulationCubit extends Cubit<SimulationState> {
  SimulationCubit(SurveyBloc surveyBloc) : super(const SimulationState()) {
    _subscription = surveyBloc.stream.listen(_onSurveyChanged);
    // Run an initial computation in case there's already data loaded.
    _scheduleRecompute(surveyBloc.state.survey);
  }

  late final StreamSubscription<SurveyState> _subscription;
  Timer? _debounceTimer;
  int _seq = 0;

  static const _debounce = Duration(milliseconds: 400);

  // ---------------------------------------------------------------------------

  void _onSurveyChanged(SurveyState state) => _scheduleRecompute(state.survey);

  void _scheduleRecompute(Survey survey) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => _runCompute(survey));
  }

  Future<void> _runCompute(Survey survey) async {
    final fp = survey.floorPlan;
    if (fp == null || survey.accessPoints.isEmpty) {
      // Nothing to compute – clear any previous result.
      if (!isClosed) emit(const SimulationState());
      return;
    }

    final seq = ++_seq;
    if (!isClosed) emit(state.copyWith(isComputing: true));

    try {
      final result = await RfSimulationService.compute(
        floorPlan: fp,
        accessPoints: survey.accessPoints,
        walls: survey.walls,
        zones: survey.zones,
      );

      // Discard stale results (a newer computation was started).
      if (seq == _seq && !isClosed) {
        emit(SimulationState(signalMap: result, isComputing: false));
      }
    } catch (_) {
      if (seq == _seq && !isClosed) {
        emit(state.copyWith(isComputing: false));
      }
    }
  }

  // ---------------------------------------------------------------------------

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    _subscription.cancel();
    return super.close();
  }
}
