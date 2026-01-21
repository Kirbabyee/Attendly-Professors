import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:professor/Professor%20Page/mainshell.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NewPasswordPage extends StatefulWidget {
  final String userId; // auth.users.id (student/prof/admin)
  final String otp;
  final String role; // "student" | "professor" | "admin" (optional)

  const NewPasswordPage({
    super.key,
    required this.userId,
    required this.otp,
    required this.role,
  });

  @override
  State<NewPasswordPage> createState() => _NewPasswordPageState();
}

class _NewPasswordPageState extends State<NewPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _newPass = TextEditingController();
  final _confirmPass = TextEditingController();

  bool loading = false;
  String error = "";

  @override
  void dispose() {
    _newPass.dispose();
    _confirmPass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      error = "";
      loading = true;
    });

    try {
      final res = await Supabase.instance.client.functions.invoke(
        'prof-verify-otp-and-change-password',
        body: {
          'professor_id': widget.userId,
          'otp': widget.otp,
          'new_password': _newPass.text.trim(),
        },
      );


      final data = res.data;
      if (data == null || data['success'] != true) {
        setState(() {
          error = "${data?['step'] ?? 'error'}: ${data?['message'] ?? 'Failed'}";
        });
        return;
      }

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: const Icon(Icons.check_circle_outline, color: Colors.green, size: 50),
          content: const Text(
            "Password changed successfully.",
            textAlign: TextAlign.center,
          ),
        ),
      );

      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => Mainshell(initialIndex: 3))); // back
    } catch (e) {
      setState(() => error = "Error: $e");
    } finally {
      setState(() => loading = false);
    }
  }

  bool _showNewPassword = false;
  bool _showConfirmPass = false;
  String? _passwordError;

  @override
  Widget build(BuildContext context) {
    if (error.isNotEmpty) _passwordError = error;
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 100,
              padding: EdgeInsets.symmetric(horizontal: 30),
              decoration: BoxDecoration(
                color: Color(0xFF004280),
                borderRadius: BorderRadius.vertical(
                  top: Radius.zero,
                  bottom: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadiusGeometry.circular(7),
                      color: Color(0x30FFFFFF),
                    ),
                    child: Icon(
                      Icons.settings,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                  SizedBox(width: 15),
                  Container(
                    height: 50,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Settings',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: screenHeight > 700 ? 10 : 5),
                        Text(
                          'Manage your preferences',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20,),
            Container(
              child: Row(
                children: [
                  IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: Icon(CupertinoIcons.arrow_left)
                  ),
                  Text('Back')
                ],
              ),
            ),
            SizedBox(height: 20,),
            Container(
              width: 350,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 2,
                    offset: Offset(0, 5),
                  ),
                ],
                borderRadius: BorderRadiusGeometry.circular(8),
                color: Colors.white
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Container(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$_passwordError'),
                          SizedBox(height: 5,),
                          SizedBox(
                            width: 300,
                            height: 58,
                            child: TextFormField(
                              controller: _newPass,
                              obscureText: _showNewPassword ? false : true,
                              validator: (v) {
                                if (v == null || v.isEmpty) return "Required";
                                if (v.length < 8) return "Min 8 characters";
                                return null;
                              },
                              style: TextStyle(
                                fontSize: 12,
                              ),
                              decoration: InputDecoration(
                                suffixIcon: IconButton(onPressed: () {setState(() {_showNewPassword = !_showNewPassword;});}, icon: Icon(_showNewPassword ? Icons.visibility : Icons.visibility_off)),
                                errorMaxLines: 1,
                                errorText: _passwordError,
                                errorStyle: TextStyle(
                                  fontSize: 10,
                                ),
                                contentPadding: EdgeInsets.all(10), // Padding inside the inputbar
                                filled: true,
                                fillColor: Color(0x50D9D9D9),
                                hintText: 'Enter new password',
                                hintStyle: TextStyle(
                                  fontSize: 12,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                      color: Colors.black,
                                      width: .5
                                  ),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                      color: Colors.red,
                                      width: .5
                                  ),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                      color: Colors.red,
                                      width: .5
                                  ),
                                ),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    Container(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Confirm password'),
                          SizedBox(height: 5,),
                          SizedBox(
                            width: 300,
                            height: 58,
                            child: TextFormField(
                              controller: _confirmPass,
                              obscureText: _showConfirmPass ? false : true,
                              validator: (v) {
                                if (v == null || v.isEmpty) return "Required";
                                if (v != _newPass.text) return "Passwords do not match";
                                return null;
                              },
                              style: TextStyle(
                                fontSize: 12,
                              ),
                              decoration: InputDecoration(
                                suffixIcon: IconButton(onPressed: () {setState(() {_showConfirmPass = !_showConfirmPass;});}, icon: Icon(_showConfirmPass ? Icons.visibility : Icons.visibility_off)),
                                errorMaxLines: 1,
                                errorStyle: TextStyle(
                                  fontSize: 10,
                                ),
                                contentPadding: EdgeInsets.all(10), // Padding inside the inputbar
                                filled: true,
                                fillColor: Color(0x50D9D9D9),
                                hintText: 'Confirm password',
                                hintStyle: TextStyle(
                                  fontSize: 12,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                      color: Colors.black,
                                      width: .5
                                  ),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                      color: Colors.red,
                                      width: .5
                                  ),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                      color: Colors.red,
                                      width: .5
                                  ),
                                ),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    OutlinedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF043B6F),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadiusGeometry.circular(8)
                        )
                      ),
                      onPressed: loading
                          ? null
                          : () {
                        if (_formKey.currentState!.validate()) _submit();
                      },
                      child: loading
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Text("Change Password", style: TextStyle(color: Colors.white),),
                    ),
                  ],
                ),
              ),
            )
          ],
        )
      )
    );
  }
}
