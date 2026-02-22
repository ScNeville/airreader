import 'dart:typed_data';

import 'package:airreader/models/access_point.dart';

/// The lowest dBm value stored in the grid; anything at or below this is
/// treated as "no signal" for rendering purposes.
const double kNoSignal = -120.0;

/// Result of a single RF simulation pass.
///
/// Stores a 2-D grid of received-signal-strength (dBm) values for each
/// [WiFiBand].  The grid is stored as a flat [Float32List] in row-major order:
///   index = row * gridCols + col
///
/// [resolution] is the number of floor-plan pixels represented by each grid
/// cell.  E.g. resolution = 6 means each cell covers a 6×6 px area.
class SignalMap {
  const SignalMap({
    required this.gridCols,
    required this.gridRows,
    required this.resolution,
    required this.bandGrids,
  });

  final int gridCols;
  final int gridRows;

  /// Floor-plan pixels per grid cell on each axis.
  final int resolution;

  /// Best received signal (dBm) at every grid cell, keyed by [WiFiBand].
  final Map<WiFiBand, Float32List> bandGrids;

  // ---------------------------------------------------------------------------
  // Accessors
  // ---------------------------------------------------------------------------

  /// Returns the signal strength in dBm for [band] at scene pixel [px], [py].
  double signalAt(WiFiBand band, double px, double py) {
    final grid = bandGrids[band];
    if (grid == null) return kNoSignal;
    final col = (px / resolution).floor().clamp(0, gridCols - 1);
    final row = (py / resolution).floor().clamp(0, gridRows - 1);
    return grid[row * gridCols + col];
  }

  /// Best (maximum) signal across all bands at scene pixel [px], [py].
  double bestSignalAt(double px, double py) {
    double best = kNoSignal;
    for (final band in WiFiBand.values) {
      final s = signalAt(band, px, py);
      if (s > best) best = s;
    }
    return best;
  }
}
