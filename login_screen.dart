import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'dashboard_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  String email = '', password = '';
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Login")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: "Email"),
                onSaved: (val) => email = val!.trim(),
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
                child: loading ? CircularProgressIndicator(color: Colors.white) : Text("Login"),
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    setState(() => loading = true);
                    final user = await DBHelper().loginUser(email, password);
                    setState(() => loading = false);
                    if (user != null) {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DashboardScreen(user: user)));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Invalid credentials")));
                    }
                  }
                },
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => RegisterScreen()));
                },
                child: Text("Don't have an account? Register")
              )
            ],
          ),
        ),
      ),
    );
  }
}
