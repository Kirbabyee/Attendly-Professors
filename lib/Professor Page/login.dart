import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:professor/Professor%20Page/professor_session.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import 'mainshell.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  String? emailValidator(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) return 'Email is required';

    final emailRegex = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,}$');
    if (!emailRegex.hasMatch(email)) return 'Enter a valid email';

    return null; // ✅ valid
  }


  bool showPassword = true;
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _loginError;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.width;
    final isKeyboard = MediaQuery.of(context).viewInsets.bottom != 0;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Color(0xFFEAF5FB),
      body: Stack(
        children: [
          Stack(
            children: [
              Visibility(
                visible: (!isKeyboard ? true : false), // bool
                child: Positioned(
                  top: screenHeight > 370 ? 0 : -50,
                  left: 0,
                  right: 0,
                  child: Image.asset(
                    'assets/Ellipse 2.png',
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: screenHeight > 370 ? 0 : -50,
                left: 0,
                right: 0,
                child: Image.asset(
                  'assets/Ellipse 1.png', // Dark Blue Wave
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ),
          Container(
            child: Center(
              child: Column(
                children: [
                  SizedBox(height: !isKeyboard && screenHeight > 370 ? 210 : 130,),
                  Image.asset(
                    width: screenHeight > 370 ? 400 : 300,
                    'assets/logo.png'
                  ), // Logo
                  SizedBox(height: 10,),
                  Container(
                    child: Text(
                      'Log in to your Account',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: screenHeight > 370 ? 45 : 30,),
                  // Input Boxes
                  Form( // Put to form to add validations
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Student No.
                        Container(
                          child: Text(
                            'Email',
                            style: TextStyle(
                              fontSize: screenHeight > 370 ? 14 : 12
                            ),
                          ),
                        ),
                        SizedBox(height: 5,),
                        SizedBox(
                          height: screenHeight > 370 ? 55 : 48,
                          width: 300,
                          child: TextFormField( // Input box
                            controller: _emailController,
                            style: TextStyle(fontSize: 14),
                            onChanged: (_) {
                              if (_loginError != null) {
                                setState(() => _loginError = null);
                              }
                            },
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              errorMaxLines: 1,
                              errorText: _loginError,
                              errorStyle: TextStyle(
                                fontSize: 10,
                                height: 1,
                              ),
                              hintText: 'Enter Email', // Placeholder
                              hintStyle: TextStyle(
                                color: Colors.grey, // Change placeholder color
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(
                                Icons.email_outlined, // Add icon to the placeholder
                                color: Colors.grey, // Change the color of the icon
                              ),
                              contentPadding: const EdgeInsets.symmetric( // Add padding
                                horizontal: 10,
                                vertical: 10,
                              ),
                              // Add border to the input box
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: Colors.grey
                                  )
                              ),
                              focusedBorder: OutlineInputBorder(  // Change color of the border when clicked
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: Colors.black
                                  )
                              ),
                              errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: Colors.red
                                  )
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: Colors.red
                                ),
                              ),
                            ),
                            validator: emailValidator,
                          ),
                        ),
                        SizedBox(height: screenHeight > 370 ? 15 : 10),
                        // Password
                        Container(child: Text(
                          'Password',
                          style: TextStyle(
                              fontSize: screenHeight > 370 ? 14 : 12
                          ),
                        ),),
                        SizedBox(height: 5,),
                        SizedBox(
                          height: screenHeight > 370 ? 55 : 48,
                          width: 300,
                          child: TextFormField( // Input box
                            controller: _passwordController,
                            style: TextStyle(fontSize: 14),
                            obscureText: (showPassword ? true : false),
                            decoration: InputDecoration(
                              errorMaxLines: 1,
                              errorStyle: TextStyle(
                                fontSize: 10,
                                height: 1,
                              ),
                              hintText: 'Enter Password', // Placeholder
                              hintStyle: TextStyle(
                                color: Colors.grey, // Change placeholder color
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(
                                Icons.lock_outline, // Add icon to the placeholder
                                color: Colors.grey, // Change the color of the icon
                                size: 20,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility),
                                onPressed: () {
                                  setState(() {
                                    showPassword = !showPassword;
                                  });
                                },
                              ),
                              contentPadding: const EdgeInsets.symmetric( // Add padding
                                horizontal: 10,
                                vertical: 10,
                              ),
                              // Add border to the input box
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: Colors.grey
                                )
                              ),
                              focusedBorder: OutlineInputBorder(  // Change color of the border when clicked
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: Colors.black
                                )
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: Colors.red
                                )
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: Colors.red
                                ),
                              ),
                            ),
                            validator: (value) {
                              final v = value ?? '';
                              if (v.isEmpty) return 'Password is required';
                              if (v.length < 4) return 'Minimum 6 characters';
                              return null;
                            },
                          ),
                        ),
                        Container(
                          margin: EdgeInsets.fromLTRB(165,0,0,0),
                          child: InkWell(
                            onTap: () {
                              Navigator.pushNamed(context, '/forgot_password');
                            },
                            child: Text(
                              'Forgot Password?',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 70,),
                  !isKeyboard ? Container(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size(150, 40),
                        backgroundColor: Color(0xFF004280),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadiusGeometry.circular(6)
                        )
                      ),
                        onPressed: () async {
                          if (!_formKey.currentState!.validate()) return;

                          setState(() {
                            _loginError = null;
                          });

                          // Show loading
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) {
                              return Dialog(
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                      SizedBox(width: 12),
                                      Text('Signing in...'),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );

                          try {
                            final email = _emailController.text.trim().toLowerCase();
                            final password = _passwordController.text;

                            final res = await supabase.auth.signInWithPassword(
                              email: email,
                              password: password,
                            );

                            final uid = res.user?.id;
                            if (uid == null) {
                              throw Exception("User has no data");
                            }

                            // To check if the account is for student
                            final studentRow = await supabase
                                .from('professors')
                                .select('id')
                                .eq('id', uid)
                                .maybeSingle();

                            if (studentRow == null) {
                              // Block login if no returns, means not a student account
                              await supabase.auth.signOut();
                              if (!mounted) return;
                              Navigator.pop(context); // close loading

                              setState(() {
                                _loginError = 'This account is not allowed in the Student app.';
                              });
                              _formKey.currentState!.validate();
                              return;
                            }

                            ProfessorSession.clear();
                            await ProfessorSession.get(force: true);

                            if (!mounted) return;
                            Navigator.pop(context);
                            Navigator.of(context).pushNamedAndRemoveUntil('/mainshell', (route) => false);
                          } on AuthException catch (e) {
                            if (!mounted) return;
                            Navigator.pop(context);

                            final msg = e.message.toLowerCase();

                            setState(() {
                              _loginError = 'Invalid email or password';
                            });

                            // force redraw + show red text immediately
                            _formKey.currentState!.validate();
                          } catch (e) {
                            if (!mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Login failed. $e')),
                            );
                          }
                        },
                      child: Text(
                        'Sign In',
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      )
                    ),
                  ) : Container(),
                ],
              ),
            ),
          )
        ],
      )
    );
  }
}
