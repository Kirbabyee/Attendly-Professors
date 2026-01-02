import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'filters.dart';

class History extends StatefulWidget {
  const History({super.key});

  @override
  State<History> createState() => _HistoryState();
}

class _HistoryState extends State<History> {

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
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
                  bottom: Radius.circular(20)
                )
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
                      Icons.history_sharp,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 15,),
                  Container(
                    height: 50,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attendance History',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                            fontSize: 15
                          ),
                        ),
                        SizedBox(height: screenHeight > 700 ? 10 : 5,),
                        Text(
                          'View your complete attendance records',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white
                          ),
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
            SizedBox(height: 15,),
            Expanded(
              child: DataFilter()
            )
          ],
        ),
      ),
    );
  }
}
