import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:airreader/blocs/performance_cubit.dart';
import 'package:airreader/blocs/simulation_cubit.dart';
import 'package:airreader/blocs/survey_bloc.dart';
import 'package:airreader/blocs/ui_bloc.dart';
import 'package:airreader/screens/home_screen.dart';
import 'package:airreader/utils/constants.dart';
import 'package:airreader/utils/desktop_window.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // runApp must be called before setupDesktopWindow so that the widget tree
  // is attached and can handle flutter/lifecycle channel messages that
  // window_manager emits during its waitUntilReadyToShow callback.
  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => SurveyBloc()),
        BlocProvider(create: (_) => UIBloc()),
        BlocProvider(create: (ctx) => SimulationCubit(ctx.read<SurveyBloc>())),
        BlocProvider(create: (ctx) => PerformanceCubit(ctx.read<SurveyBloc>())),
      ],
      child: const AirReaderApp(),
    ),
  );

  await setupDesktopWindow();
}

class AirReaderApp extends StatelessWidget {
  const AirReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UIBloc, UIState>(
      buildWhen: (prev, curr) => prev.darkMode != curr.darkMode,
      builder: (context, uiState) {
        final darkMode = uiState.darkMode;
        return MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
          home: const HomeScreen(),
        );
      },
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0077FF),
      brightness: brightness,
      surface: isDark ? const Color(0xFF1A1D23) : const Color(0xFFF5F7FA),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF13151A)
          : const Color(0xFFEFF2F5),
      dividerColor: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.1),
      textTheme: const TextTheme(
        titleMedium: TextStyle(fontSize: 15, letterSpacing: 0),
        bodyMedium: TextStyle(fontSize: 13),
        bodySmall: TextStyle(fontSize: 12),
      ),
    );
  }
}
