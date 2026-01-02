import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'dashboard.dart';

class Archives extends StatefulWidget {
  final List<ClassItem> archivedClasses;
  final void Function(ClassItem item) onRestore;

  const Archives({
    super.key,
    required this.archivedClasses,
    required this.onRestore,
  });

  @override
  State<Archives> createState() => _ArchivesState();
}



class _ArchivesState extends State<Archives> {

  Widget classCard(String course,
      String classCode,
      String professor,
      String room,
      String sched,
      String session,
      double screenHeight,
      VoidCallback onArchive,
      ) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Container(
      margin: EdgeInsets.symmetric(vertical: screenHeight > 700 ? 20 : 12),
      padding: EdgeInsets.all(10),
      width: 350,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadiusGeometry.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 2,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          fontSize: screenHeight > 700 ? 12 : 11,
          color: Colors.black,
          fontFamily: 'Montserrat',
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 280,
                      child: Text(
                        course,
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    SizedBox(height: 5,),
                    Text(classCode),
                    SizedBox(height: 10,),
                  ],
                ),
                PopupMenuButton<String>(
                  color: Colors.white,
                  icon: const Icon(Icons.more_vert_outlined),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem<String>(
                      value: 'restore',
                      child: Row(
                        children: [
                          Icon(Icons.restore, size: 18),
                          SizedBox(width: 8),
                          Text('Restore'),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'restore') {
                      onArchive(); // we’ll use this as restore action
                    }
                  },
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(CupertinoIcons.person, size: screenHeight > 700 ? 20 : 18),
                        SizedBox(width: 5),
                        Container(child: Text(professor,softWrap: true,)),
                      ],
                    ),
                    SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(Icons.pin_drop_outlined, size: screenHeight > 700 ? 20 : 18),
                        SizedBox(width: 5),
                        Text(room),
                      ],
                    ),
                    SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(CupertinoIcons.clock, size: screenHeight > 700 ? 20 : 18),
                        SizedBox(width: 5),
                        Container(child: Text(sched)),
                      ],
                    ),
                  ],
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
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
                      Icons.archive,
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
                          'Archives',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: screenHeight > 700 ? 10 : 5),
                        Text(
                          'Manage archived classes',
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
            Container(
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(CupertinoIcons.arrow_left)
                  ),
                  Text('Back'),
                ],
              ),
            ),
            // Classlist
            Expanded(
              child: widget.archivedClasses.isEmpty
                  ? const Center(child: Text('No archived classes yet.'))
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                itemCount: widget.archivedClasses.length,
                itemBuilder: (context, index) {
                  final c = widget.archivedClasses[index];

                  return classCard(
                    c.course,
                    c.classCode,
                    c.professor,
                    c.room,
                    c.sched,
                    c.session,
                    screenHeight,
                        () {
                      setState(() {
                        widget.archivedClasses.removeAt(index); // remove from archive UI
                      });

                      widget.onRestore(c); // send back to Dashboard classes
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
