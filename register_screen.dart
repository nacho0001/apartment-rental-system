import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  String fullName = '', email = '', phone = '', password = '';
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Register")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: "Full Name"),
                onSaved: (val) => fullName = val!.trim(),
                validator: (val) => val!.isEmpty ? "Required" : null,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: "Email"),
                onSaved: (val) => email = val!.trim(),
                validator: (val) => val!.isEmpty ? "Required" : null,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: "Phone"),
                onSaved: (val) => phone = val!.trim(),
                validator: (val) => val!.isEmpty ? "Required" : null,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: "Password"),
                obscureText: true,
                onSaved: (val) => password = val!.trim(),
                validator: (val) => val!.isEmpty ? "Required" : null,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                child: loading ? CircularProgressIndicator(color: Colors.white) : Text("Register"),
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    setState(() => loading = true);
                    try {
                      await DBHelper().registerUser(fullName, email, phone, password);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Registered Successfully!")));
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen()));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                    } finally {
                      setState(() => loading = false);
                    }
                  }
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}
