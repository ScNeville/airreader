/// App-wide constants.
class AppConstants {
  AppConstants._();

  static const String appName = 'AirReader';
  static const String appVersion = '1.0.0';

  // Default window size
  static const double minWindowWidth = 1100;
  static const double minWindowHeight = 700;
  static const double defaultWindowWidth = 1400;
  static const double defaultWindowHeight = 900;

  // RF defaults
  static const double defaultTxPowerDbm = 20.0; // 100 mW
  static const double defaultAntennaGainDbi = 2.0; // typical omnidirectional AP
  static const double defaultFrequency24Ghz = 2437.0; // MHz – ch 6
  static const double defaultFrequency5Ghz = 5180.0; // MHz – ch 36
  static const double defaultFrequency6Ghz = 5955.0; // MHz – ch 1

  // Heat-map thresholds (dBm)
  static const double signalExcellent = -50;
  static const double signalGood = -65;
  static const double signalFair = -75;
  static const double signalPoor = -85;
  static const double signalNoSignal = -95;
}
