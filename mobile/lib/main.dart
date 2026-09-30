import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'src/app_state.dart';
import 'src/screens/interview_screen.dart';
import 'src/screens/pin_screen.dart';
import 'src/screens/setup_screen.dart';
import 'src/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CopilotApp());
}

class CopilotApp extends StatelessWidget {
  const CopilotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: MaterialApp(
        title: 'AI Interview Copilot',
        theme: buildDarkTheme(),
        debugShowCheckedModeBanner: false,
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();

    if (!s.ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (s.profileId == null) {
      return const PinScreen();
    }

    if (!s.setupComplete) {
      return const SetupScreen();
    }

    return const InterviewScreen();
  }
}

