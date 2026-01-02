import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../mainshell.dart';

class ChangePassword extends StatefulWidget {
  const ChangePassword({super.key});

  @override
  State<ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends State<ChangePassword> {

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _currentPassword = TextEditingController();
  final TextEditingController _newPassword = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();

  bool showPassword = false;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.width;
    return Scaffold(
      resizeToAvoidBottomInset: false,
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
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const Mainshell(initialIndex: 3,)),
                      );
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
              padding: EdgeInsets.all(15),
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
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.lock,
                          size: 20,
                        ),
                        SizedBox(width: 10,),
                        Text(
                          'Change Password',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20,),
                    Container(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Current password'),
                          SizedBox(height: 5,),
                          SizedBox(
                            width: 300,
                            height: 58,
                            child: TextFormField(
                              controller: _currentPassword,
                              obscureText: showPassword ? false : true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Current password is required';
                                }
                                return null;
                              },
                              style: TextStyle(
                                fontSize: 12,
                              ),
                              decoration: InputDecoration(
                                errorMaxLines: 1,
                                errorStyle: TextStyle(
                                  fontSize: 10,
                                ),
                                contentPadding: EdgeInsets.all(10), // Padding inside the inputbar
                                filled: true,
                                fillColor: Color(0x50D9D9D9),
                                hintText: 'Enter current password',
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
                                )
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                    SizedBox(height: 20,),
                    Container(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('New password'),
                          SizedBox(height: 5,),
                          SizedBox(
                            width: 300,
                            height: 58,
                            child: TextFormField(
                              controller: _newPassword,
                              obscureText: showPassword ? false : true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'New password is required';
                                }
                                return null;
                              },
                              style: TextStyle(
                                fontSize: 12,
                              ),
                              decoration: InputDecoration(
                                errorMaxLines: 1,
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
                                )
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                    SizedBox(height: 20,),
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
                              controller: _confirmPassword,
                              obscureText: showPassword ? false : true,
                              validator: (value) {
                                if ((value == null || value.isEmpty) && !_newPassword.text.isEmpty) {
                                  return 'Please confirm your password';
                                }
                                return null;
                              },
                              style: TextStyle(
                                fontSize: 12,
                              ),
                              decoration: InputDecoration(
                                errorMaxLines: 1,
                                errorStyle: TextStyle(
                                  fontSize: 10,
                                ),
                                contentPadding: EdgeInsets.all(10), // Padding inside the inputbar
                                filled: true,
                                fillColor: Color(0x50D9D9D9),
                                hintText: 'Confirm new password',
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
                                )
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        SizedBox(width: 30,),
                        Transform.scale(
                          scale: .8,
                          child: SizedBox(
                            width: 23,
                            child: Checkbox(
                              value: showPassword,
                              onChanged: (value) {
                                setState(() {
                                  showPassword = !showPassword;
                                });
                              }
                            ),
                          ),
                        ),
                        Text('Show Password'),
                      ],
                    )
                  ],
                ),
              ),
            ),
            SizedBox(height: 30,),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF043B6F),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadiusGeometry.circular(8)
                )
              ),
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  // All inputs valid
                  print('Passwords valid');
                }
              },
              child: const Text(
                'Change Password',
                style: TextStyle(
                  color: Colors.white
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
