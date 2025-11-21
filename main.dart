import 'package:flutter/material.dart';
import 'db_helper.dart'; // Database helper for initialization
import 'login_screen.dart'; // Screen 1: Initial route
import 'dashboard_screen.dart'; // Screen 3: Main app content
import 'register_screen.dart'; // Screen 2: Registration
import 'apartments_screen.dart'; // Screen 4: Apartments listing
import 'tenants_screen.dart'; // Screen 5: Tenants listing (New Import)

void main() async {
  // Ensure that Flutter widgets are bound before any async calls (like DB init)
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize the database connection (assuming DBHelper handles this setup)
  // This ensures the database is ready before the app UI loads.
  await DBHelper().database; 
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rent in Addis',
      // Using Inter font for a modern look (if available in the environment)
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
      
      // The application starts at the LoginScreen
      initialRoute: '/',
      
      // Defining named routes for navigation
      routes: {
        '/': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
        
        // '/dashboard' route expects a user object. 
        '/dashboard': (context) => DashboardScreen(user: {}), // placeholder
        
        '/apartments': (context) => ApartmentsScreen(), 
        
        // New route added for TenantsScreen
        '/tenants': (context) => TenantsScreen(),
      },
    );
  }
}