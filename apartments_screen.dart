import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'apartment_card.dart';

class ApartmentsScreen extends StatefulWidget {
  const ApartmentsScreen({super.key});

  @override
  State<ApartmentsScreen> createState() => _ApartmentsScreenState();
}

class _ApartmentsScreenState extends State<ApartmentsScreen> {
  final DBHelper _dbHelper = DBHelper();
  List<Map<String, dynamic>> apartments = [];
  bool loading = true;
  
  // Controllers and FormKey for the Add/Edit Dialog
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _bedroomsCtrl = TextEditingController();
  final TextEditingController _bathroomsCtrl = TextEditingController();
  final TextEditingController _locationCtrl = TextEditingController();
  final TextEditingController _rentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadApartments();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bedroomsCtrl.dispose();
    _bathroomsCtrl.dispose();
    _locationCtrl.dispose();
    _rentCtrl.dispose();
    super.dispose();
  }

  Future<void> loadApartments() async {
    // FIX: Set loading state only if not already loading to avoid flicker on RefreshIndicator
    if (!loading) setState(() => loading = true); 
    
    try {
      final data = await _dbHelper.getApartments(); 
      if (mounted) {
        setState(() {
          apartments = data;
          loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading apartments: $e');
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to load apartments."), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> deleteApartment(int id) async {
    await _dbHelper.deleteApartment(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Apartment deleted successfully!"), backgroundColor: Colors.green),
    );
    loadApartments(); // Reload list
  }
  
  // New method to show confirmation dialog before deletion
  Future<void> _confirmDelete(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete this apartment? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await deleteApartment(id);
    }
  }

  // FIX: Unified Dialog for Add and Edit
  Future<void> _showApartmentDialog({Map<String, dynamic>? apartment}) async {
    final bool isEditing = apartment != null;
    final int? apartmentId = isEditing ? apartment!['id'] as int : null;

    // 1. Initialize controllers
    _nameCtrl.text = apartment?['name'] ?? '';
    _bedroomsCtrl.text = apartment?['bedrooms']?.toString() ?? '';
    _bathroomsCtrl.text = apartment?['bathrooms']?.toString() ?? '';
    _locationCtrl.text = apartment?['location'] ?? '';
    _rentCtrl.text = apartment?['rent']?.toString() ?? '';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEditing ? 'Edit Apartment' : 'Add Apartment'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a name' : null,
                ),
                TextFormField(
                  controller: _bedroomsCtrl,
                  decoration: const InputDecoration(labelText: 'Bedrooms'),
                  keyboardType: TextInputType.number,
                  validator: (v) => int.tryParse((v ?? '').trim()) == null ? 'Enter a number' : null,
                ),
                TextFormField(
                  controller: _bathroomsCtrl,
                  decoration: const InputDecoration(labelText: 'Bathrooms'),
                  keyboardType: TextInputType.number,
                  validator: (v) => int.tryParse((v ?? '').trim()) == null ? 'Enter a number' : null,
                ),
                TextFormField(
                  controller: _locationCtrl,
                  decoration: const InputDecoration(labelText: 'Location'),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Enter location' : null,
                ),
                TextFormField(
                  controller: _rentCtrl,
                  decoration: const InputDecoration(labelText: 'Rent (ETB)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => double.tryParse((v ?? '').trim()) == null ? 'Enter a valid amount' : null,
                ),
              ].map((w) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: w)).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!_formKey.currentState!.validate()) return;
              
              final apartmentData = {
                'name': _nameCtrl.text.trim(),
                'bedrooms': int.tryParse(_bedroomsCtrl.text.trim())!,
                'bathrooms': int.tryParse(_bathroomsCtrl.text.trim())!,
                'location': _locationCtrl.text.trim(),
                'rent': double.tryParse(_rentCtrl.text.trim())!,
              };

              try {
                if (isEditing) {
                  // Update using DBHelper method
                  await _dbHelper.updateApartment(apartmentId!, apartmentData.cast<String, Object?>());
                  
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Apartment updated successfully'), backgroundColor: Colors.green),
                  );
                } else {
                  // Add using DBHelper method
                  await _dbHelper.addApartment(apartmentData.cast<String, Object?>());
                  
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Apartment added successfully'), backgroundColor: Colors.green),
                  );
                }

                if (!mounted) return;
                Navigator.of(context).pop(); // Close dialog
                await loadApartments();
              } catch (e) {
                debugPrint("Error saving apartment: $e");
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Failed to save apartment"), backgroundColor: Colors.red),
                  );
                }
              }
            }, 
            child: Text(isEditing ? 'Update' : 'Add')
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Apartments"),
      ),
      body: RefreshIndicator( // Added RefreshIndicator for pull-to-refresh
        onRefresh: loadApartments,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : apartments.isEmpty
                ? const Center(child: Text("No apartments yet. Tap '+' to add one."))
                : ListView.builder(
                    itemCount: apartments.length,
                    itemBuilder: (context, index) {
                      final apt = apartments[index];
                      // Ensure the ID is safe before passing it
                      final int? aptId = apt['id'] is int ? apt['id'] as int : null;

                      return ApartmentCard(
                        apartment: apt,
                        // FIX: Pass the apartment data to the unified dialog function for editing
                        onEdit: () {
                          if (aptId != null) {
                            _showApartmentDialog(apartment: apt);
                          }
                        },
                        // FIX: Use the confirmation dialog before deleting
                        onDelete: () {
                          if (aptId != null) {
                            _confirmDelete(aptId);
                          }
                        },
                      );
                    },
                  ),
      ),
      // FIX: Added Floating Action Button to trigger the 'Add' dialog
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showApartmentDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}