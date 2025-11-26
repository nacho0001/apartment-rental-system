import 'package:flutter/material.dart';
import 'db_helper.dart'; // Database helper for initialization
import 'login_screen.dart'; // Screen 1: Initial route
import 'dashboard_screen.dart'; // Screen 3: Main app content
import 'register_screen.dart'; // Screen 2: Registration
import 'apartments_screen.dart'; // Screen 4: Apartments listing
import 'tenants_screen.dart'; // Screen 5: Tenants listing (New Import)

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await DBHelper().database; // ensure DB is initialized before app runs
  } catch (e, st) {
    debugPrint('DB initialization failed: $e\n$st');
    // Continue launching app; screens should handle DB errors gracefully
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rent in Addis',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Inter',
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue.shade700,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: Colors.blue.shade700, width: 2.0),
          ),
        ),
      ),
      initialRoute: '/',
      // remove 'const' here to match screens that may not have const constructors
      routes: {
        '/': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
        '/apartments': (context) => ApartmentsScreen(),
        '/tenants': (context) => TenantsScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/dashboard') {
          final args = settings.arguments;
          final user =
              args is Map<String, dynamic> ? args : <String, dynamic>{};
          return MaterialPageRoute(
              builder: (ctx) => DashboardScreen(user: user),
              settings: settings);
        }
        return null;
      },
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (ctx) => const Scaffold(
          body: Center(child: Text('404: Route not found')),
        ),
      ),
    );
  }
}
