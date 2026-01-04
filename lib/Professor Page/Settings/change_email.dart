import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ChangeEmail extends StatefulWidget {
  const ChangeEmail({super.key});

  @override
  State<ChangeEmail> createState() => _ChangeEmailState();
}

class _ChangeEmailState extends State<ChangeEmail> {

  bool showPassword = false;
  final _formKey = GlobalKey<FormState>();

  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.width;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Container(
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
                      padding: EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadiusGeometry.circular(7),
                        color: Color(0x30FFFFFF),
                      ),
                      child: Icon(
                        Icons.email_outlined,
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
                            'Change Email',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                          SizedBox(height: screenHeight > 700 ? 10 : 5),
                          Text(
                            'Manage your email',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                            ),
                          )
                        ],
                      ),
                    )
                  ],
                ),
              ),
              
              SizedBox(height: screenHeight * .05,),
              
              Container(
                child: Row(
                  children: [
                    IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: Icon(CupertinoIcons.arrow_left)
                    ),
                    Text('Back'),
                  ],
                ),
              ),
              
              SizedBox(height: screenHeight * .20,),
              
              Container(
                width: screenHeight * .9,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadiusGeometry.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 2,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
              child: Column(
                children: [
                  Text(
                    'You must enter your first password to change your email',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: screenHeight * .05,),
                  Container(
                    width: screenHeight * .8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Password'),
                        SizedBox(height: 5,),
                        Form(
                          key: _formKey,
                          child: TextFormField(
                            obscureText: !showPassword,
                            style: TextStyle(
                              fontSize: 12
                            ),
                            decoration: InputDecoration(
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    showPassword = !showPassword;
                                  });
                                },
                                icon: Icon(
                                  showPassword ? Icons.visibility : Icons.visibility_off,
                                  size: 18,
                                )
                              ),
                              hintText: 'Enter your password',
                              hintStyle: TextStyle(
                                fontSize: 12
                              ),
                              contentPadding: EdgeInsets.all(3),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey
                                )
                              ),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                      color: Colors.grey
                                  )
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color: Colors.red
                                )
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color: Colors.red
                                )
                              ),
                            ),
                            validator: (value) {
                              final v = value ?? '';
                              if (v.isEmpty) return 'Password is required';
                              if (v.length < 8) return 'Minimum 8 characters';
                              return null;
                            },
                          ),
                        )
                      ],
                    ),
                  ),

                  SizedBox(height: screenHeight * .05,),

                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadiusGeometry.circular(8)
                      ),
                      side: BorderSide.none,
                      backgroundColor: Color(0xFF004280),
                    ),
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          // All inputs are valid
                          final password = _passwordController.text;
                        }
                      },
                    child: Text(
                      'Next',
                      style: TextStyle(
                        color: Colors.white,
                      ),
                    )
                  ),
                ],
              ),
              )
            ],
          ),
        )
      ),
    );
  }
}
