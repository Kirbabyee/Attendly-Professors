import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  final _studentNoController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _studentNoController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

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
                              style: TextStyle(fontSize: 14),
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                errorMaxLines: 1,
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

                              // TODO: dont forget to change the validation to email validation
                              // here: emailValidator
                              validator: (value) {
                                final v = value?.trim() ?? '';
                                if (v.isEmpty) return 'Student number is required';
                                if (v.length < 8) return 'Student number is too short';
                                return null;
                              },
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
                                if (v.length < 8) return 'Minimum 8 characters';
                                return null;
                              },
                            ),
                          ),
                          Container(
                            margin: EdgeInsets.fromLTRB(165,0,0,0),
                            child: InkWell(
                              onTap: () {
                                print('forgot password');
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
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              // All inputs are valid
                              final studentNo = _studentNoController.text;
                              final password = _passwordController.text;
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(builder: (_) => Mainshell()),
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
