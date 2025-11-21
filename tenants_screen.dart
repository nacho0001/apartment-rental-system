import 'package:flutter/material.dart';
import 'db_helper.dart';
// NOTE: You must import your LogPaymentScreen here!
// Assuming it's in a file named 'log_payment_screen.dart'
import 'log_payment_screen.dart'; // <--- ADD THIS IMPORT

class TenantsScreen extends StatefulWidget {
  @override
  _TenantsScreenState createState() => _TenantsScreenState();
}

class _TenantsScreenState extends State<TenantsScreen> {
  List<Map<String, dynamic>> tenants = [];
  List<Map<String, dynamic>> availableApartments = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadTenants();
  }

  Future<void> loadTenants() async {
    final db = await DBHelper().database;

    final tenantsResult = await db.rawQuery('''
      SELECT t.*, a.name as apartment_name
      FROM tenants t
      LEFT JOIN apartments a ON t.apartment_id = a.id
      ORDER BY t.fullName
    ''');

    final availableAptResult = await db.rawQuery('''
      SELECT a.id, a.name
      FROM apartments a
      LEFT JOIN tenants t ON a.id = t.apartment_id
      WHERE t.apartment_id IS NULL
      ORDER BY a.name
    ''');

    setState(() {
      tenants = tenantsResult;
      availableApartments = availableAptResult;
      loading = false;
    });
  }

  Future<void> deleteTenant(int id) async {
    final db = await DBHelper().database;
    await db.delete('tenants', where: 'id = ?', whereArgs: [id]);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Tenant deleted")));
    loadTenants();
  }

  void showTenantForm({Map<String, dynamic>? tenant}) {
    final _formKey = GlobalKey<FormState>();
    String fullName = tenant?['fullName'] ?? '';
    String phone = tenant?['phone'] ?? '';
    String email = tenant?['email'] ?? '';
    String leaseStart = tenant?['lease_start'] ?? '';
    int? apartmentId = tenant?['apartment_id'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tenant == null ? "Add Tenant" : "Edit Tenant"),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  initialValue: fullName,
                  decoration: InputDecoration(labelText: "Full Name"),
                  validator: (val) => val!.isEmpty ? "Required" : null,
                  onSaved: (val) => fullName = val!.trim(),
                ),
                TextFormField(
                  initialValue: phone,
                  decoration: InputDecoration(labelText: "Phone"),
                  validator: (val) => val!.isEmpty ? "Required" : null,
                  onSaved: (val) => phone = val!.trim(),
                ),
                TextFormField(
                  initialValue: email,
                  decoration: InputDecoration(labelText: "Email (optional)"),
                  onSaved: (val) => email = val!.trim(),
                ),
                TextFormField(
                  initialValue: leaseStart,
                  decoration: InputDecoration(labelText: "Lease Start (YYYY-MM-DD)"),
                  validator: (val) => val!.isEmpty ? "Required" : null,
                  onSaved: (val) => leaseStart = val!.trim(),
                ),
                DropdownButtonFormField<int>(
                  value: apartmentId,
                  items: [
                    DropdownMenuItem<int>(
                      value: null,
                      child: Text("Unassigned"),
                    ),
                    ...availableApartments.map((a) => DropdownMenuItem<int>(
                          value: a['id'],
                          child: Text(a['name']),
                        )),
                  ],
                  onChanged: (val) => apartmentId = val,
                  decoration: InputDecoration(labelText: "Apartment"),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
          ElevatedButton(
            child: Text(tenant == null ? "Add" : "Update"),
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                _formKey.currentState!.save();
                final db = await DBHelper().database;
                if (tenant == null) {
                  try {
                    await db.insert('tenants', {
                      'fullName': fullName,
                      'phone': phone,
                      'email': email,
                      'apartment_id': apartmentId,
                      'lease_start': leaseStart,
                    });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Tenant added")));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: Apartment already assigned")));
                  }
                } else {
                  await db.update('tenants', {
                    'fullName': fullName,
                    'phone': phone,
                    'email': email,
                    'apartment_id': apartmentId,
                    'lease_start': leaseStart,
                  }, where: 'id = ?', whereArgs: [tenant['id']]);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Tenant updated")));
                }
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
      appBar: AppBar(title: Text("Tenants")),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: tenants.length,
              itemBuilder: (context, index) {
                final t = tenants[index];
                return Card(
                  child: ListTile(
                    title: Text(t['fullName']),
                    subtitle: Text("Phone: ${t['phone']}\nEmail: ${t['email'] ?? '-'}\nApartment: ${t['apartment_name'] ?? 'Unassigned'}\nLease Start: ${t['lease_start']}"),
                    isThreeLine: true,
                    // *** Trailing Row Updated Here ***
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // New Log Payment Button
                        IconButton(
                          icon: const Icon(Icons.payment),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              // Ensure you have defined LogPaymentScreen to accept a 'tenant' argument
                              builder: (_) => LogPaymentScreen(tenant: t), 
                            ),
                          ),
                        ),
                        // Existing Edit Button
                        IconButton(icon: const Icon(Icons.edit), onPressed: () => showTenantForm(tenant: t)),
                        // Existing Delete Button
                        IconButton(icon: const Icon(Icons.delete), onPressed: () => deleteTenant(t['id'])),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showTenantForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}