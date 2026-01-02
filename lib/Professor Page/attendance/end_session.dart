import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../widgets/class_session.dart';

class EndSession extends StatefulWidget {
  const EndSession({super.key});

  @override
  State<EndSession> createState() => _EndSessionState();
}

class _EndSessionState extends State<EndSession> {
  bool viewAllList = false;

  List Students = [
    'John Doe',
    'Nicole Margarette',
    'Trisha Lorraine',
    'Arthur Morgan',
    'Clark Kent',
    'Lex Luthor',
    'Lois Lane',
    'Lana Lang',
    'Tony Stark',
  ];

  Widget student(String studentName) {
    return Column(
      children: [
        Container(
          margin: EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Image.asset(
                  width: 20,
                  'assets/avatar.png'
              ),
              SizedBox(width: 10,),
              Text(
                studentName,
                style: TextStyle(
                  fontSize: 12,
                ),
              )
            ],
          ),
        ),
        SizedBox(height: 10,),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.width;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AttendlyBlueHeader(
                    onBack: true,
                    courseTitle: 'Introduction to Human Computer Interaction',
                    courseCode: 'CCS101',
                    professor: 'Mr. Leviticio Dowell',
                    icon: CupertinoIcons.book,
                    iconColor: const Color(0xFFFBD600),
                  ),
                  const SizedBox(height: 20),
                  const ClassInfo(),
                  const SizedBox(height: 10),

                  // Back Button
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 30),
                    child: Row(
                      children: [
                        IconButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            icon: Icon(CupertinoIcons.arrow_left)),
                        Text('Back')
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Start Session
                  Container(
                    padding: EdgeInsets.all(20),
                    width: 350,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadiusGeometry.circular(8),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 2,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'End Class Session',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold
                          ),
                        ),
                        SizedBox(height: 10,),
                        Center(
                          child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                  backgroundColor: Color(0xFFB60202),
                                  side: BorderSide.none,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadiusGeometry.circular(8)
                                  )
                              ),
                              onPressed: () {},
                              icon: Icon(
                                CupertinoIcons.stop,
                                color: Colors.white,
                              ),
                              label: Text(
                                'End Class Session',
                                style: TextStyle(
                                    color: Colors.white
                                ),
                              )),
                        )
                      ],
                    ),
                  ),

                  SizedBox(height: 30,),

                  // Student in the class
                  Container(
                    width: 350,
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 2,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Students',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold
                          ),
                        ),
                        SizedBox(height: 10,),
                        !viewAllList
                            ? Container(
                          child: Column(
                            children: Students.take(4).map((stud) => student(stud)).toList(),
                          ),
                        )
                            : SizedBox(
                          height: 180,
                          child: ListView.builder(
                            itemCount: Students.length,
                            itemBuilder: (context, index) {
                              return student(Students[index]);
                            },
                          ),
                        ),

                        Center(
                          child: TextButton(
                            onPressed: () {
                              setState(() {
                                viewAllList = !viewAllList;
                              });
                            },
                            child: Text(
                              !viewAllList ? 'View all students' : 'Show less',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF105698)
                              ),
                            ),
                          ),
                        )
                      ],
                    ),
                  )
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
