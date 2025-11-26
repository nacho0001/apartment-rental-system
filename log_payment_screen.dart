import 'package:flutter/material.dart';
import 'db_helper.dart';

class LogPaymentScreen extends StatefulWidget {
  final Map<String, dynamic> tenant;
  const LogPaymentScreen({super.key, required this.tenant});

  @override
  _LogPaymentScreenState createState() => _LogPaymentScreenState();
}

class _LogPaymentScreenState extends State<LogPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  String amountPaid = '';
  String paymentDate = '';
  String paymentForMonth = '';

  Future<void> logPayment() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final db = await DBHelper().database;

      double amount = double.parse(amountPaid);
      double rent = widget.tenant['rent'] ?? 0.0;
      String status = amount >= rent ? 'Paid' : 'Partial';

      await db.insert('rent_payments', {
        'tenant_id': widget.tenant['id'],
        'amount_paid': amount,
        'payment_date': paymentDate,
        'payment_for_month': paymentForMonth,
        'status': status,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Payment logged for ${widget.tenant['fullName']}")),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Log Payment - ${widget.tenant['fullName']}")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text("Apartment Rent: ${widget.tenant['rent']} ETB"),
              SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(labelText: "Amount Paid"),
                keyboardType: TextInputType.number,
                validator: (val) => val!.isEmpty ? "Required" : null,
                onSaved: (val) => amountPaid = val!.trim(),
              ),
              TextFormField(
                decoration: InputDecoration(labelText: "Payment Date (YYYY-MM-DD)"),
                validator: (val) => val!.isEmpty ? "Required" : null,
                onSaved: (val) => paymentDate = val!.trim(),
              ),
              TextFormField(
                decoration: InputDecoration(labelText: "Payment For Month (YYYY-MM)"),
                validator: (val) => val!.isEmpty ? "Required" : null,
                onSaved: (val) => paymentForMonth = val!.trim(),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: logPayment,
                child: Text("Log Payment"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
