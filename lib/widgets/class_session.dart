import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../Professor Page/mainshell.dart';

class AttendlyBlueHeader extends StatelessWidget {

  final bool onBack;

  final IconData icon;
  final Color iconColor;

  final String courseTitle;
  final String courseCode;
  final String professor;

  final double height;

  const AttendlyBlueHeader({
    super.key,
    required this.onBack,
    this.icon = CupertinoIcons.book,
    this.iconColor = const Color(0xFFFBD600),
    required this.courseTitle,
    required this.courseCode,
    required this.professor,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.width;
    return Container(
      height: screenHeight > 370 && onBack ? height : screenHeight > 370 && !onBack ? 180 : onBack ? 180 : 130,
      decoration: const BoxDecoration(
        color: Color(0xFF004280),
        borderRadius: BorderRadius.vertical(
          top: Radius.zero,
          bottom: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.all(screenHeight > 370 ? 10 : 5),
      child: Column(
        children: [
          onBack ? Row(
            children: [
              IconButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const Mainshell())
                  );
                },
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white
                ),
              ),
              Text(
                'Back',
                style: const TextStyle(color: Colors.white),
              )
            ],
          ) : SizedBox(height: onBack ? 30 : 10,),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0x30FFFFFF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: screenHeight > 370 ? 80 : 65, color: iconColor),
              ),
              SizedBox(width: screenHeight > 370 ? 15 : 10),

              // Course details
              DefaultTextStyle(
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontFamily: 'Montserrat',
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 250,
                      child: Text(
                        courseTitle,
                        softWrap: true,
                        style: TextStyle(
                          fontSize: screenHeight > 370 ? 14 : 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      courseCode,
                      style: TextStyle(
                        fontSize: screenHeight > 370 ? 14 : 13
                      ),
                    ),
                    SizedBox(height: screenHeight > 370 ? 20 : 15),
                    Text(
                      professor,
                      style: TextStyle(
                        fontSize: screenHeight > 370 ? 13 : 12
                      ),
                    ),
                  ],
                ),
              )
            ],
          )
        ],
      ),
    );
  }
}

class ClassInfo extends StatelessWidget {
  final double width;
  final double height;

  const ClassInfo({
    this.width = 350,
    this.height = 100,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.width;
    return Container(
      width: screenHeight > 370 ? width : 320,
      height: height,
      padding: EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 2,
            offset: Offset(0, 4),
          ),
        ],
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            child: Row(
              children: [
                Text(
                  'Class Code:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15
                  ),
                ),
                SizedBox(width: 10,),
                Text(
                  'BJL23JHD',
                  style: TextStyle(
                    fontSize: 12
                  ),
                )
              ],
            ),
          ),
          SizedBox(height: 10,),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              children: [
                Container(
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 15,
                      ),
                      SizedBox(width: 5,),
                      Text(
                        'Room 301',
                        style: TextStyle(
                          fontSize: 11
                        ),
                      )
                    ],
                  ),
                ),
                SizedBox(height: 5,),
                Container(
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.clock,
                        size: 15,
                      ),
                      SizedBox(width: 5,),
                      Text(
                        'Monday: 9:00 - 11:00 AM',
                        style: TextStyle(
                            fontSize: 11
                        ),
                      )
                    ],
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
