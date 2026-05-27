import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/theme.dart';
import 'package:flutter_application_1/models/home_model.dart';
import 'package:flutter_application_1/screens/daily_streak_screen.dart';
import 'package:flutter_application_1/screens/mock_test_flow.dart';
import 'package:flutter_application_1/screens/splash_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final loggedIn = await AuthService.isLoggedIn();
  runApp(NEETPrepApp(loggedIn: loggedIn));
}

class NEETPrepApp extends StatelessWidget {
  final bool loggedIn;
  const NEETPrepApp({super.key, required this.loggedIn});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HomeModel(),
      child: MaterialApp(
        title: 'NEET Prep',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        onGenerateRoute: (settings) {
          if (settings.name == '/streak/daily') {
            return MaterialPageRoute(builder: (_) => const DailyStreakScreen(), settings: settings);
          }
          if (settings.name == '/mock-test/start') {
            return MaterialPageRoute(builder: (_) => const MockTestLandingScreen(), settings: settings);
          }
          if (settings.name == '/mock-test/result') {
            final args = settings.arguments;
            if (args is MockTestResultArgs) {
              return MaterialPageRoute(builder: (_) => MockTestResultsScreen(args: args), settings: settings);
            }
            return MaterialPageRoute(builder: (_) => const MockTestResultsScreen(), settings: settings);
          }
          return null;
        },
        home: SplashScreen(loggedIn: loggedIn),
      ),
    );
  }
}
