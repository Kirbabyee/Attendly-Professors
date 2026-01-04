import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../widgets/class_session.dart';

class EndSession extends StatefulWidget {
  final List<String> students;

  const EndSession({
    super.key,
    required this.students,
  });

  @override
  State<EndSession> createState() => _EndSessionState();
}

class _EndSessionState extends State<EndSession> {
  bool viewAllList = false;

  Future<void> _confirmEndSession() async {
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
            'This will end the current class session.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadiusGeometry.circular(8)
                )
              ),
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.black
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB60202),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadiusGeometry.circular(8)
                )
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
               'End Session',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      if (_ending) return; // prevent double trigger
      setState(() => _ending = true);

      // optional delay (simulate ending session / saving to DB)
      await Future.delayed(const Duration(milliseconds: 1000));

      if (!mounted) return;
      Navigator.pop(context, 'ended'); // ✅ return result to Dashboard
    }
  }

  Widget student(String studentName) {
    return Column(
      children: [
        Container(
          margin: EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
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
                    ),
                  ],
                ),
              ),
              Container(
                child: Row(
                  children: [
                    Icon(CupertinoIcons.check_mark_circled, color: Color(0xFF018832), size: 15,),
                    Text('Present', style: TextStyle(color: Color(0xFF018832), fontSize: 12),)
                  ],
                ),
              )
            ],
          ),
        ),
        SizedBox(height: 10,),
      ],
    );
  }

  bool _ending = false;

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

                  // End Session
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
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Color(0x509BC9F5),
                            borderRadius: BorderRadiusGeometry.circular(8)
                          ),
                          child: Row(
                            children: [
                              Icon(
                                CupertinoIcons.clock,
                                size: 20,
                                color: Color(0xFF043B6F)
                              ),
                              SizedBox(width: 5,),
                              Text(
                                'Session Started at 5:58 PM',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF043B6F)
                                ),
                              )
                            ],
                          ),
                        ),
                        SizedBox(height: 10,),
                        Center(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: const Color(0xFFB60202),
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _ending ? null : _confirmEndSession,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_ending) ...[
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  Text(
                                    _ending ? 'Ending...' : 'End Class Session',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      ],
                    ),
                  ),

                  SizedBox(height: 20,),

                  // Attendance
                  Container(
                    width: 350,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadiusGeometry.circular(8),
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
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '4',
                                style: TextStyle(
                                  fontSize: 30
                                ),
                              ),
                              Text(
                                'Present',
                                style: TextStyle(
                                  fontSize: 12
                                ),
                              )
                            ],
                          ),
                        ),
                        Container(
                          width: 100,
                          height: 100,
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadiusGeometry.circular(8),
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
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '39',
                                style: TextStyle(
                                    fontSize: 30
                                ),
                              ),
                              Text(
                                'Pending',
                                style: TextStyle(
                                    fontSize: 12
                                ),
                              )
                            ],
                          ),
                        ),
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadiusGeometry.circular(8),
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
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '43',
                                style: TextStyle(
                                    fontSize: 30
                                ),
                              ),
                              Text(
                                'Total',
                                style: TextStyle(
                                    fontSize: 12
                                ),
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20,),

                  // Attendance Log
                  Container(
                    width: 350,
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadiusGeometry.circular(8)
                    ),
                    child: Column(
                      children: [
                        Container(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Attendance Log'),
                              Container(
                                child: Row(
                                  children: [
                                    Icon(Icons.people_alt_outlined),
                                    Text('${widget.students.length}/39'),
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                        Divider(
                          color: Colors.black,
                        ),
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            itemCount: widget.students.length,
                            itemBuilder: (context, index) {
                              return student(widget.students[index]);
                            },
                          ),
                        ),
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
