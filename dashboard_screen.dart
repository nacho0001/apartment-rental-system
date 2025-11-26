import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const DashboardScreen({super.key, required this.user});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int totalApartments = 0;
  int occupiedUnits = 0;
  int totalTenants = 0;
  double collectedRent = 0.0;
  double expectedMonthlyRent = 0.0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadMetrics();
  }

  Future<void> loadMetrics() async {
    try {
      final db = await DBHelper().database;

      // Total apartments
      final totalApt = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(id) FROM apartments')) ?? 0;

      // Occupied units
      final occUnits = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(apartment_id) FROM tenants WHERE apartment_id IS NOT NULL')) ?? 0;

      // Total tenants
      final tenants = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(id) FROM tenants')) ?? 0;

      // Collected rent
      final rentCollectedResult = await db.rawQuery('SELECT SUM(amount_paid) as total FROM rent_payments');
      final rentCollected = (rentCollectedResult.isNotEmpty && rentCollectedResult.first['total'] != null)
          ? (rentCollectedResult.first['total'] as num).toDouble()
          : 0.0;

      // Expected monthly rent (sum of rent for currently occupied units)
      final expectedRentResult = await db.rawQuery('''
        SELECT SUM(a.rent) as total 
        FROM apartments a 
        JOIN tenants t ON a.id = t.apartment_id 
        WHERE t.apartment_id IS NOT NULL
      ''');
      final expectedRent = (expectedRentResult.isNotEmpty && expectedRentResult.first['total'] != null)
          ? (expectedRentResult.first['total'] as num).toDouble()
          : 0.0;

      if (mounted) {
        setState(() {
          totalApartments = totalApt;
          occupiedUnits = occUnits;
          totalTenants = tenants;
          collectedRent = rentCollected;
          expectedMonthlyRent = expectedRent;
          loading = false;
        });
      }
    } catch (e, st) {
      debugPrint('Failed to load dashboard metrics: $e\n$st');
      if (mounted) {
        setState(() {
          loading = false;
        });
        // Optionally show a failure SnackBar here
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to load dashboard data."), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget metricCard(String title, String value, Color color) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final username = widget.user['fullName'] ?? 'User';
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard - $username'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              // FIX: This Column now contains all the dashboard content.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch, // Makes buttons stretch full width
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      metricCard("Total Apartments", totalApartments.toString(), Colors.blue),
                      metricCard("Occupied Units", occupiedUnits.toString(), Colors.green),
                      metricCard("Total Tenants", totalTenants.toString(), Colors.orange),
                      metricCard("Collected Rent", "${collectedRent.toStringAsFixed(2)} ETB", Colors.purple),
                      metricCard("Expected Monthly Rent", "${expectedMonthlyRent.toStringAsFixed(2)} ETB", Colors.red),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to Apartment Management
                      Navigator.pushNamed(context, '/apartments');
                    },
                    child: const Text("Manage Apartments"),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to Tenant Management
                      Navigator.pushNamed(context, '/tenants');
                    },
                    child: const Text("Manage Tenants"),
                  ),
                  // Add other components/navigation here as needed
                ],
              ),
            ),
    );
  }
}