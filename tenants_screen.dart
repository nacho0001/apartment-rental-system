import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'log_payment_screen.dart'; // Ensure this import is correct

class TenantsScreen extends StatefulWidget {
  const TenantsScreen({super.key});

  @override
  _TenantsScreenState createState() => _TenantsScreenState();
}

class _TenantsScreenState extends State<TenantsScreen> {
  final DBHelper _dbHelper = DBHelper();
  List<Map<String, dynamic>> tenants = [];
  List<Map<String, dynamic>> allApartments = []; // FIX: Use a list of ALL apartments for the dropdown
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadTenants();
  }

  Future<void> loadTenants() async {
    setState(() => loading = true);
    try {
      final db = await _dbHelper.database;

      // FIX 1: Query ALL apartments for the dropdown, whether occupied or not
      final allAptResult = await db.rawQuery('SELECT id, name, rent FROM apartments ORDER BY name');
      
      // Query tenants joined with their assigned apartment name
      final tenantsResult = await db.rawQuery('''
        SELECT t.*, a.name as apartment_name
        FROM tenants t
        LEFT JOIN apartments a ON t.apartment_id = a.id
        ORDER BY t.fullName
      ''');

      if (mounted) {
        setState(() {
          tenants = tenantsResult;
          allApartments = allAptResult; // Assign all apartments here
          loading = false;
        });
      }
    } catch (e, st) {
      debugPrint("Error loading tenants/apartments: $e\n$st");
      if (mounted) {
         setState(() => loading = false);
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to load data."), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> deleteTenant(int id) async {
    try {
      final db = await _dbHelper.database;
      final count = await db.delete('tenants', where: 'id = ?', whereArgs: [id]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(count > 0 ? "Tenant deleted successfully" : "No tenant found to delete"),
            backgroundColor: count > 0 ? Colors.green : Colors.orange,
          ),
        );
      }
      loadTenants();
    } catch (e) {
      debugPrint("Error deleting tenant: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to delete tenant"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void showTenantForm({Map<String, dynamic>? tenant}) {
    final formKey = GlobalKey<FormState>();
    // Create new controllers for proper state management in the dialog
    final fullNameCtrl = TextEditingController(text: tenant?['fullName'] ?? '');
    final phoneCtrl = TextEditingController(text: tenant?['phone'] ?? '');
    final emailCtrl = TextEditingController(text: tenant?['email'] ?? '');
    final leaseStartCtrl = TextEditingController(text: tenant?['lease_start'] ?? '');
    
    int? apartmentId = (tenant != null && tenant['apartment_id'] is int) ? tenant['apartment_id'] as int : null;

    // FIX 2: Identify apartments that are currently occupied by OTHERS (excluding the current tenant being edited)
    Set<int?> occupiedApartmentIds = tenants
      .where((t) => t['id'] != tenant?['id'] && t['apartment_id'] != null)
      .map((t) => t['apartment_id'] as int?)
      .toSet();

    // Combine all apartment options with the option to unassign
    List<DropdownMenuItem<int?>> apartmentOptions = [
      const DropdownMenuItem<int?>(
        value: null,
        child: Text("Unassigned"),
      ),
      ...allApartments.map((a) {
        final aptId = a['id'] as int;
        final isOccupiedByOther = occupiedApartmentIds.contains(aptId);
        
        return DropdownMenuItem<int?>(
          value: aptId,
          // FIX 3: Disable/Grey out apartments occupied by someone else
          enabled: !isOccupiedByOther, 
          child: Text(
            '${a['name']} ${isOccupiedByOther ? '(Occupied)' : ''}', 
            style: isOccupiedByOther ? const TextStyle(color: Colors.grey) : null,
          ),
        );
      }).toList(),
    ];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tenant == null ? "Add Tenant" : "Edit Tenant"),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: fullNameCtrl,
                  decoration: const InputDecoration(labelText: "Full Name"),
                  validator: (val) => (val == null || val.isEmpty) ? "Required" : null,
                ),
                TextFormField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: "Phone"),
                  keyboardType: TextInputType.phone,
                  validator: (val) => (val == null || val.isEmpty) ? "Required" : null,
                ),
                TextFormField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: "Email (optional)"),
                  keyboardType: TextInputType.emailAddress,
                ),
                TextFormField(
                  controller: leaseStartCtrl,
                  decoration: const InputDecoration(labelText: "Lease Start (YYYY-MM-DD)"),
                  validator: (val) => (val == null || val.isEmpty) ? "Required" : null,
                ),
                // FIX: Added StatefulWidget/StatefulBuilder logic for Dropdown value update
                StatefulBuilder(
                  builder: (context, setStateSB) {
                    return DropdownButtonFormField<int?>(
                      value: apartmentId,
                      items: apartmentOptions,
                      onChanged: (val) {
                        setStateSB(() {
                          apartmentId = val;
                        });
                      },
                      decoration: const InputDecoration(labelText: "Apartment"),
                    );
                  }
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            child: Text(tenant == null ? "Add" : "Update"),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                
                final tenantData = {
                  'fullName': fullNameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'email': emailCtrl.text.trim(),
                  'apartment_id': apartmentId,
                  'lease_start': leaseStartCtrl.text.trim(),
                };
                
                final db = await _dbHelper.database;
                
                try {
                  if (tenant == null) {
                    await db.insert('tenants', tenantData);
                    
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tenant added"), backgroundColor: Colors.green));
                  } else {
                    await db.update(
                      'tenants', 
                      tenantData,
                      where: 'id = ?', 
                      whereArgs: [tenant['id']],
                    );
                    
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tenant updated"), backgroundColor: Colors.green));
                  }
                } catch (e) {
                  debugPrint("Tenant save error: $e");
                  if (!mounted) return;
                  // Handle unique constraint error (if a unique index is on apartment_id)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Error saving tenant. Check constraints."), backgroundColor: Colors.red),
                  );
                }
                
                // Dispose controllers after use
                fullNameCtrl.dispose();
                phoneCtrl.dispose();
                emailCtrl.dispose();
                leaseStartCtrl.dispose();
                
                if (!mounted) return;
                Navigator.pop(context);
                loadTenants();
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tenants")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadTenants,
              child: tenants.isEmpty
                  ? Center(
                      child: ListView(
                        shrinkWrap: true,
                        children: const [
                          Center(child: Text("No tenants added yet.", style: TextStyle(color: Colors.grey))),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: tenants.length,
                      itemBuilder: (context, index) {
                        final t = tenants[index];
                        final int? tenantId = t['id'] is int ? t['id'] as int : null;
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          child: ListTile(
                            title: Text(t['fullName']),
                            subtitle: Text(
                              "Phone: ${t['phone']}\nApartment: ${t['apartment_name'] ?? 'Unassigned'}\nLease Start: ${t['lease_start']}",
                            ),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Log Payment Button
                                IconButton(
                                  icon: const Icon(Icons.payment, color: Colors.blue),
                                  onPressed: () {
                                    if (tenantId != null) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          // Ensure LogPaymentScreen accepts a Map<String, dynamic> tenant argument
                                          builder: (_) => LogPaymentScreen(tenant: t), 
                                        ),
                                      ).then((_) => loadTenants()); // Refresh list when returning
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("Tenant ID required for payment.")),
                                      );
                                    }
                                  },
                                ),
                                // Edit Button
                                IconButton(icon: const Icon(Icons.edit, color: Colors.orange), onPressed: () => showTenantForm(tenant: t)),
                                // Delete Button
                                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () {
                                  if (tenantId != null) {
                                    deleteTenant(tenantId);
                                  }
                                }),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showTenantForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}