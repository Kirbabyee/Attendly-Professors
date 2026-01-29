import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final int id;
  final String text;
  int? read; // null = unread, 1 = read
  final DateTime createdAt;

  NotificationItem({
    required this.id,
    required this.text,
    required this.read,
    required this.createdAt,
  });

  bool get isRead => read == 1;
}

class _NotificationsDrawerState extends State<NotificationsDrawer> {
  final supabase = Supabase.instance.client;

  bool _loading = true;
  List<NotificationItem> notifications = [];

  bool get hasUnread => notifications.any((n) => !n.isRead);

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) return;

      final rows = await supabase
          .from('notification_queue')
          .select('id, body, read, created_at')
          .eq('target_user_id', uid)
          .order('created_at', ascending: false)
          .limit(50);

      final list = (rows as List)
          .cast<Map<String, dynamic>>()
          .map((r) {
        return NotificationItem(
          id: (r['id'] as num).toInt(),
          text: (r['body'] ?? '').toString().trim(),
          read: r['read'] as int?,
          createdAt: DateTime.tryParse(
            (r['created_at'] ?? '').toString(),
          ) ??
              DateTime.fromMillisecondsSinceEpoch(0),
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        notifications = list;
        _loading = false;
      });

      widget.onUnreadChanged(hasUnread);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) return;

      await supabase
          .from('notification_queue')
          .update({'read': 1})
          .eq('target_user_id', uid)
          .isFilter('read', null);

      if (!mounted) return;
      setState(() {
        for (final n in notifications) {
          n.read = 1;
        }
      });

      widget.onUnreadChanged(false);
    } catch (_) {}
  }

  Future<void> _markOneAsRead(int notifId) async {
    try {
      await supabase
          .from('notification_queue')
          .update({'read': 1})
          .eq('id', notifId);

      if (!mounted) return;
      setState(() {
        notifications.firstWhere((n) => n.id == notifId).read = 1;
      });

      widget.onUnreadChanged(hasUnread);
    } catch (_) {}
  }

  Future<void> _markOneAsUnread(int notifId) async {
    try {
      await supabase
          .from('notification_queue')
          .update({'read': null})
          .eq('id', notifId);

      if (!mounted) return;
      setState(() {
        notifications.firstWhere((n) => n.id == notifId).read = null;
      });

      widget.onUnreadChanged(hasUnread);
    } catch (_) {}
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
                    onPressed: _loading ? null : _markAllAsRead,
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
                child: _loading
                    ? const Center(child: CupertinoActivityIndicator())
                    : notifications.isEmpty
                    ? const Center(child: Text('No notifications yet.'))
                    : ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notif = notifications[index];
                    return _NotifTile(
                      text: notif.text,
                      isRead: notif.isRead,
                      createdAt: notif.createdAt,
                      onMarkAsRead: () =>
                          _markOneAsRead(notif.id),
                      onMarkAsUnread: () =>
                          _markOneAsUnread(notif.id),
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
  final DateTime createdAt;
  final VoidCallback onMarkAsRead;
  final VoidCallback onMarkAsUnread;

  const _NotifTile({
    required this.isRead,
    required this.text,
    required this.createdAt,
    required this.onMarkAsRead,
    required this.onMarkAsUnread,
  });

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    final weeks = (diff.inDays / 7).floor();
    if (weeks < 4) return '${weeks}w ago';

    final months = (diff.inDays / 30).floor();
    if (months < 12) return '${months}mo ago';

    return '${(diff.inDays / 365).floor()}y ago';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFEF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔹 content row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Opacity(
                opacity: isRead ? 0 : 1,
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
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                    isRead ? FontWeight.normal : FontWeight.w600,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                color: Colors.white,
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (value) {
                  if (value == 'read') onMarkAsRead();
                  if (value == 'unread') onMarkAsUnread();
                },
                itemBuilder: (_) => [
                  if (!isRead)
                    const PopupMenuItem(
                      value: 'read',
                      child: Text('Mark as read'),
                    ),
                  if (isRead)
                    const PopupMenuItem(
                      value: 'unread',
                      child: Text('Mark as unread'),
                    ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),

          // 🔹 time ago
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Text(
              _timeAgo(createdAt),
              style: const TextStyle(
                fontSize: 10,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
