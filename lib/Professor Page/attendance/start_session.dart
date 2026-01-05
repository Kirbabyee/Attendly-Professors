import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../widgets/class_session.dart';

class StartSession extends StatefulWidget {
  final List<String> students;

  const StartSession({
    super.key,
    required this.students,
  });

  @override
  State<StartSession> createState() => _StartSessionState();
}


class _StartSessionState extends State<StartSession> {
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

  bool _starting = false;

  Future<void> _confirmStartSession() async { // Start session confirmation
    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: const Text(
            'Are you sure?',
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'This will start the class session.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.black),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF018832),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Start Session',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      if (_starting) return;
      setState(() => _starting = true);

      await Future.delayed(const Duration(milliseconds: 700));

      if (!mounted) return;
      Navigator.pop(context, 'started');
    }
  }



  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
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
                    onBack: false,
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
                          'Start Class Session',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold
                          ),
                        ),
                        SizedBox(height: 10,),
                        Center(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: const Color(0xFF018832),
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _starting ? null : _confirmStartSession,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_starting) ...[
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                  ] else ...[
                                    const Icon(CupertinoIcons.play, color: Colors.white),
                                    const SizedBox(width: 10),
                                  ],
                                  Text(
                                    _starting ? 'Starting...' : 'Start Class Session',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
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
                        Container(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Students',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold
                                ),
                              ),
                              Text(
                                '${widget.students.length} students',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold
                                ),
                              )
                            ],
                          ),
                        ),
                        SizedBox(height: 10,),
                        !viewAllList
                            ? Container(
                          height: screenHeight * .20,
                          child: Column(
                            children: widget.students.take(6)
                                      .map((stud) => student(stud)).toList(),
                          ),
                        )
                            : SizedBox(
                          height: screenHeight * .25,
                          child: ListView.builder(
                            itemCount: widget.students.length,
                            itemBuilder: (context, index) {
                              return student(widget.students[index]);
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
