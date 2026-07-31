import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/main_screen.dart';
import 'screens/report_screen.dart';
import 'screens/history_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/community_screen.dart';
import 'screens/accident_report_screen.dart';
import 'screens/chatbot_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/drafts_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'services/notification_service.dart';
import 'utils/global_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  
  // Try loading .env but don't crash if it's missing
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("No .env file found or empty. Using fallbacks.");
  }

  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
  final userRole = prefs.getString('user_role') ?? 'citizen';

  final isDark = prefs.getBool('darkMode') ?? false;
  GlobalState.themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  GlobalState.languageNotifier.value = prefs.getString('language') ?? 'English';

  final route = !isLoggedIn ? '/login' : (userRole == 'admin' ? '/admin' : '/');
  runApp(CivicIssueApp(initialRoute: route));
}

class CivicIssueApp extends StatelessWidget {
  final String initialRoute;
  
  const CivicIssueApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: GlobalState.themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return ValueListenableBuilder<String>(
          valueListenable: GlobalState.languageNotifier,
          builder: (_, String lang, __) {
            return MaterialApp(
              title: 'Civic Connect',
              debugShowCheckedModeBanner: false,
              themeMode: currentMode,
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF1E293B),
                  primary: const Color(0xFF1E293B),
                  secondary: const Color(0xFF3B82F6),
                  surface: const Color(0xFFF8FAFC),
                ),
                useMaterial3: true,
                textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
                scaffoldBackgroundColor: const Color(0xFFF8FAFC),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
              ),
              darkTheme: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: Color(0xFF3B82F6),
                  secondary: Color(0xFF1E293B),
                  surface: Color(0xFF0F172A),
                ),
                scaffoldBackgroundColor: const Color(0xFF0F172A),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
                bottomNavigationBarTheme: const BottomNavigationBarThemeData(
                  backgroundColor: Color(0xFF1E293B),
                ),
              ),
              initialRoute: initialRoute,
              routes: {
                '/login': (context) => const LoginScreen(),
                '/register': (context) => const RegisterScreen(),
                '/': (context) => const MainScreen(),
                '/report': (context) => const ReportScreen(),
                '/history': (context) => const HistoryScreen(),
                '/community': (context) => const CommunityScreen(),
                '/accident': (context) => const AccidentReportScreen(),
                '/chat': (context) => const ChatbotScreen(),
                '/analytics': (context) => const AnalyticsScreen(),
                '/drafts': (context) => const DraftsScreen(),
                '/admin': (context) => const AdminDashboardScreen(),
              },
            );
          },
        );
      },
    );
  }
}
