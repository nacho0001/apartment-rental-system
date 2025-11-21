import 'package:flutter/material.dart';
import '../widgets/apartment_card.dart'; // Make sure this path is correct
import 'db_helper.dart'; // Placeholder for your database helper

class ApartmentsScreen extends StatefulWidget {
  // If you use an Add/Edit screen, you might want to pass a callback here
  // final VoidCallback? onApartmentUpdated; 
  
  const ApartmentsScreen({Key? key}) : super(key: key);

  @override
  _ApartmentsScreenState createState() => _ApartmentsScreenState();
}

class _ApartmentsScreenState extends State<ApartmentsScreen> {
  List<Map<String, dynamic>> apartments = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadApartments();
  }

  // --- Data Loading Function ---
  Future<void> loadApartments() async {
    // Placeholder for actual database call
    // Ensure you have a working DBHelper class with a 'database' getter
    try {
      final db = await DBHelper().database;
      final result = await db.rawQuery('''
        SELECT a.*, t.id as tenant_id, t.fullName as tenant_name
        FROM apartments a
        LEFT JOIN tenants t ON a.id = t.apartment_id
        ORDER BY a.name
      ''');
      setState(() {
        apartments = result;
        loading = false;
      });
    } catch (e) {
      // Handle potential errors (e.g., database not initialized)
      print("Error loading apartments: $e");
      setState(() {
        loading = false;
        // Optionally show an error message
      });
    }
  }

  // --- Data Deletion Function ---
  void deleteApartment(int id) async {
    final db = await DBHelper().database;
    await db.delete('apartments', where: 'id = ?', whereArgs: [id]);
    
    if (mounted) { // Check if the widget is still in the tree before showing SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Apartment deleted successfully"),
          backgroundColor: Colors.green,
        ),
      );
    }
    // Reload the list to reflect the deletion
    loadApartments();
  }

  // --- Widget Build ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Apartments")),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : apartments.isEmpty
              ? Center(
                  child: Text(
                    "No apartments added yet. Tap '+' to add one.",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: apartments.length,
                  itemBuilder: (context, index) {
                    final apt = apartments[index];
                    return ApartmentCard(
                      apartment: apt,
                      onEdit: () {
                        // TODO: Implement Navigation to Edit Apartment Screen
                        print('Edit Apartment ID: ${apt['id']}');
                      },
                      onDelete: () => deleteApartment(apt['id'] as int),
                    );
                  },
                ),
      
      // Floating Action Button for adding a new apartment
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Implement Navigation to Add Apartment Screen
          print('Navigate to Add Apartment Screen');
        },
        child: Icon(Icons.add),
      ),
    );
  }
}