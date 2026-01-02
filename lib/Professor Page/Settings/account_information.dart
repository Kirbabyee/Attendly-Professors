import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../mainshell.dart';

class AccountInformation extends StatefulWidget {
  const AccountInformation({super.key});

  @override
  State<AccountInformation> createState() => _AccountInformationState();
}

class _AccountInformationState extends State<AccountInformation> {
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
                          Image.asset(
                            'assets/avatar.png',
                            width: 180,
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
                            onPressed: () {},
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
                              Text(
                                'Email:',
                                style: TextStyle(
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                'Lev************ll.com',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold
                                ),
                              )
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
