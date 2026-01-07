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

class NotificationItem {
  final String text;
  bool isRead;

  NotificationItem({
    required this.text,
    this.isRead = false,
  });
}

class _NotificationsDrawerState extends State<NotificationsDrawer> {
  late List<NotificationItem> notifications;

  @override
  void initState() {
    super.initState();

    notifications = [
      NotificationItem(text: 'Your class session will start in 10 minutes.'),
      NotificationItem(text: 'Attendance window has been closed.'),
      NotificationItem(text: 'Attendance window is currently open.'),
    ];
  }

  bool get hasUnread =>
      notifications.any((n) => !n.isRead);

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
                      setState(() {
                        for (final n in notifications) {
                          n.isRead = true;
                        }
                      });
                      widget.onUnreadChanged(false);
                    },
                    child: const Text(
                      'Mark all as read',
                      style: TextStyle(color: Color(0xFF043B6F)),
                    ),
                  ),

                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        onPressed: () {
                          widget.onUnreadChanged(hasUnread);
                          Navigator.pop(context);
                        },
                        icon: const Icon(CupertinoIcons.bell),
                      ),
                      if (hasUnread)
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
                child: ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notif = notifications[index];

                    return _NotifTile(
                      text: notif.text,
                      isRead: notif.isRead,
                      onMarkAsRead: () {
                        setState(() => notif.isRead = true);
                        widget.onUnreadChanged(hasUnread);
                      },
                    );
                  },
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
  final bool isRead;
  final String text;
  final VoidCallback onMarkAsRead;

  const _NotifTile({
    required this.isRead,
    required this.text,
    required this.onMarkAsRead,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFEF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, // ✅ center vertically
        children: [
          // unread dot (space always reserved)
          Opacity(
            opacity: isRead ? 0 : 1, // ✅ invisible but keeps space
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFF004280),
                shape: BoxShape.circle,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // text (centered vertically)
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isRead ? FontWeight.normal : FontWeight.w500,
              ),
            ),
          ),

          // 3 dots menu
          PopupMenuButton<String>(
            color: Colors.white,
            icon: const Icon(Icons.more_vert, size: 18),
            onSelected: (value) {
              if (value == 'read') onMarkAsRead();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'read',
                child: Text('Mark as read'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


