import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login.dart';

class NewPassword extends StatefulWidget {
  final String userId;
  final String otp;

  const NewPassword({
    super.key,
    required this.userId,
    required this.otp,
  });

  @override
  State<NewPassword> createState() => _NewPasswordState();
}


class _NewPasswordState extends State<NewPassword> {
  Future<void> _showLoading() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }

  String? emailValidator(String? value) {
    return null; // ✅ valid
  }

  bool showNewPassword = true;
  bool showConfirmPassword = true;

  final _formKey = GlobalKey<FormState>();

  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handlePasswordChange() async {
    if (!_formKey.currentState!.validate()) return;

    print('user id:' + widget.userId);
    final newPass = _newPasswordController.text.trim();

    await _showLoading();
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'prof-verify-otp-and-change-password',
        body: {
          'professor_id': widget.userId,
          'otp': widget.otp,
          'new_password': newPass,
        },
      );
      Navigator.pop(context); // close loading

      final data = res.data;
      if (data == null || data['success'] != true) {
        final msg = "${data?['step'] ?? 'error'}: ${data?['message'] ?? 'Failed'}";
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Error"),
            content: Text(msg),
          ),
        );
        return;
      }

      // success dialog
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            title: const Icon(Icons.check_circle_outline, color: Colors.green, size: 50),
            content: const Text(
              'Your password has been changed successfully.',
              textAlign: TextAlign.center,
            ),
          );
        },
      );

      if (!mounted) return;

      // go to login
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const Login()),
      );
    } catch (e) {
      Navigator.pop(context); // close loading
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Error"),
          content: Text("Error: $e"),
        ),
      );
    }
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
                      'Change Password',
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
                            'New Password',
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
                            obscureText: showNewPassword,
                            controller: _newPasswordController,
                            style: TextStyle(fontSize: 14),
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              errorMaxLines: 1,
                              errorStyle: TextStyle(
                                fontSize: 10,
                                height: 1,
                              ),
                              hintText: 'Enter new password', // Placeholder
                              hintStyle: TextStyle(
                                color: Colors.grey, // Change placeholder color
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(
                                Icons.lock_outline, // Add icon to the placeholder
                                color: Colors.grey, // Change the color of the icon
                              ),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    showNewPassword = !showNewPassword;
                                  });
                                },
                                icon: Icon(!showNewPassword ? Icons.visibility : Icons.visibility_off)
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
                              final v = value?.trim() ?? '';
                              if (v.isEmpty) return 'Password is required';
                              if (v.length < 6) return 'Password is too short';
                              return null;
                            },
                          ),
                        ),

                        SizedBox(height: screenHeight > 370 ? 15 : 10),

                        Container(
                          child: Text(
                            'Confirm Password',
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
                            obscureText: showConfirmPassword,
                            controller: _confirmPasswordController,
                            style: TextStyle(fontSize: 14),
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              errorMaxLines: 1,
                              errorStyle: TextStyle(
                                fontSize: 10,
                                height: 1,
                              ),
                              hintText: 'Confirm your password', // Placeholder
                              hintStyle: TextStyle(
                                color: Colors.grey, // Change placeholder color
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(
                                Icons.lock_outline, // Add icon to the placeholder
                                color: Colors.grey, // Change the color of the icon
                              ),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    showConfirmPassword = !showConfirmPassword;
                                  });
                                },
                                icon: Icon(!showConfirmPassword ? Icons.visibility : Icons.visibility_off)
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
                              final v = value?.trim() ?? '';
                              if (v.isEmpty && !_newPasswordController.text.isEmpty) return 'Confirm password is required';
                              if (v != _newPasswordController.text.trim()) return 'Password must match';
                              if (v.length < 6) return 'Password is too short';
                              return null;
                            },
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
                          _handlePasswordChange();

                          print('user id:' + widget.userId);
                        }
                      },

                      child: Text(
                        'Change Password',
                        style: TextStyle(color: Colors.white),
                      ),
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
