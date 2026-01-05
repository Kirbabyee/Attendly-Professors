import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'dart:io';
import 'package:image_picker/image_picker.dart';

import '../mainshell.dart';
import 'change_email.dart';

class AccountInformation extends StatefulWidget {
  const AccountInformation({super.key});

  @override
  State<AccountInformation> createState() => _AccountInformationState();
}

class _AccountInformationState extends State<AccountInformation> {
  final ImagePicker _picker = ImagePicker();
  File? _profileImage;

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80, // optional compression
    );

    if (image == null) return;

    setState(() {
      _profileImage = File(image.path);
    });
  }

  String _email = 'LeviticioDowell@gmail.com';

  String maskEmail(String email, {int keepStart = 3, int keepEnd = 2}) { // emailk masking
    email = email.trim();
    final atIndex = email.indexOf('@');
    if (atIndex == -1) return email; // not a valid email format

    final local = email.substring(0, atIndex);      // before @
    final domain = email.substring(atIndex + 1);    // after @

    if (local.length <= keepStart + keepEnd) {
      // Too short to mask nicely
      return '${local[0]}***@$domain';
    }

    final start = local.substring(0, keepStart);
    final end = local.substring(local.length - keepEnd);

    final stars = '*' * (local.length - keepStart - keepEnd);

    return '$start$stars$end@$domain';
  }


  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.width;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // HEADER (fixed)
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
                  )
                ],
              ),
            ),
            SizedBox(height: screenHeight > 370 ? 50 : 10,),
            Container(
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const Mainshell(initialIndex: 2,)),
                      );
                    },
                    icon: Icon(CupertinoIcons.arrow_left)
                  ),
                  Text('Back'),
                ],
              ),
            ),

            // Account Informaton
            SizedBox(height: screenHeight > 370 ? 20 : 0,),
            Container(
              width: 350,
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadiusGeometry.circular(8)
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 20,
                      ),
                      SizedBox(width: 10,),
                      Text(
                        'Account Information',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 30,),
                  Center(
                    child: Container(
                      child: Column(
                        children: [
                          SizedBox(
                            width: 180,
                            height: 180,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(90),
                              child: _profileImage == null
                                  ? Image.asset('assets/avatar.png', fit: BoxFit.cover)
                                  : Image.file(_profileImage!, fit: BoxFit.cover),
                            ),
                          ),
                          SizedBox(height: 20,),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Color(0xFF018832),
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadiusGeometry.circular(8)
                              )
                            ),
                            icon: Icon(
                              Icons.upload,
                              color: Colors.white,
                            ),
                            onPressed: _pickImage,
                            label: Text(
                              'Upload',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w300
                              ),
                            )
                          )
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20,),
                  Center(
                    child: Container(
                      width: 250,
                      decoration: BoxDecoration(
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Name:',
                                style: TextStyle(
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                'Leviticio Dowell',
                                style: TextStyle(
                                  fontSize: 12,
                                    fontWeight: FontWeight.bold
                                ),
                              )
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Department:',
                                style: TextStyle(
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                'Computer Studies',
                                style: TextStyle(
                                  fontSize: 12,
                                    fontWeight: FontWeight.bold
                                ),
                              )
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Email:',
                                style: TextStyle(fontSize: 12),
                              ),
                              InkWell(
                                onTap: () async {
                                  final newEmail = await Navigator.push<String>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChangeEmail(currentEmail: _email),
                                    ),
                                  );

                                  if (newEmail != null && newEmail.trim().isNotEmpty) {
                                    setState(() {
                                      _email = newEmail.trim();
                                    });
                                  }
                                },
                                child: Text(
                                  maskEmail(_email),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF105698), // link blue
                                    decoration: TextDecoration.underline, // hyperlink look
                                    decorationColor: Color(0xFF105698)
                                  ),
                                ),
                              ),
                            ],
                          ),

                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 10,)
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
