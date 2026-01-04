import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class NotificationsDrawer extends StatefulWidget {
  final bool unRead;
  final ValueChanged<bool> onUnreadChanged;

  const NotificationsDrawer({
    super.key,
    required this.unRead,
    required this.onUnreadChanged,
  });

  @override
  State<NotificationsDrawer> createState() => _NotificationsDrawerState();
}

class _NotificationsDrawerState extends State<NotificationsDrawer> {
  late bool unRead;

  @override
  void initState() {
    super.initState();
    unRead = widget.unRead; // ✅ start from Dashboard value
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(30)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() => unRead = false);
                      widget.onUnreadChanged(false); // ✅ update Dashboard
                    },
                    child: Text(
                      'Mark all as read',
                      style: TextStyle(
                        color: Color(0xFF043B6F)
                      ),
                    ),
                  ),

                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(CupertinoIcons.bell),
                        color: Colors.black,
                      ),
                      if (unRead)
                        Positioned(
                          right: 10,
                          top: 10,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Expanded(
                child: ListView(
                  children: [
                    _NotifTile(unRead: unRead, text: 'Your class session will start in 10 minutes.'),
                    _NotifTile(unRead: unRead, text: 'Attendance window has been closed.'),
                    _NotifTile(unRead: unRead, text: 'Attendance window is currently open.'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final bool unRead;
  final String text;

  const _NotifTile({
    required this.unRead,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFEF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: unRead ? const Color(0xFF004280) : Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
