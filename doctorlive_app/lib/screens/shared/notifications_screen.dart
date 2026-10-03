import 'package:flutter/material.dart';

import '../../services/notification_service.dart';

/// Patient aur doctor dono ke liye shared notifications screen.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();

  List<Map<String, dynamic>> _notifications = <Map<String, dynamic>>[];
  bool _loading = true;
  bool _unreadOnly = false;
  bool _markingAll = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  /// Selected filter ke mutabiq backend notifications load karega.
  Future<void> _loadNotifications() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final List<Map<String, dynamic>> data = await _notificationService
          .getNotifications(unreadOnly: _unreadOnly);
      if (!mounted) return;
      setState(() => _notifications = data);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Notification click hone par usay read mark karega.
  Future<void> _markRead(Map<String, dynamic> notification) async {
    if (notification['is_read'] == true) return;

    final int? id = int.tryParse(notification['id']?.toString() ?? '');
    if (id == null) return;

    try {
      final Map<String, dynamic> updated = await _notificationService
          .markAsRead(id);
      if (!mounted) return;

      setState(() {
        if (_unreadOnly) {
          _notifications.removeWhere((Map<String, dynamic> item) {
            return item['id']?.toString() == id.toString();
          });
        } else {
          final int index = _notifications.indexWhere(
            (Map<String, dynamic> item) =>
                item['id']?.toString() == id.toString(),
          );
          if (index >= 0) {
            _notifications[index] = updated.isEmpty
                ? <String, dynamic>{...notification, 'is_read': true}
                : updated;
          }
        }
      });
    } catch (error) {
      if (mounted) _showMessage(error.toString(), true);
    }
  }

  /// Tamam unread notifications ko aik request mein read karega.
  Future<void> _markAllRead() async {
    if (_markingAll) return;
    setState(() => _markingAll = true);

    try {
      final int count = await _notificationService.markAllAsRead();
      if (!mounted) return;

      if (_unreadOnly) {
        setState(() => _notifications.clear());
      } else {
        setState(() {
          _notifications = _notifications
              .map(
                (Map<String, dynamic> item) => <String, dynamic>{
                  ...item,
                  'is_read': true,
                },
              )
              .toList();
        });
      }
      _showMessage('$count notification(s) read mark ho gayi.', false);
    } catch (error) {
      if (mounted) _showMessage(error.toString(), true);
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  void _showMessage(String message, bool isError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.replaceFirst('Exception: ', '')),
        backgroundColor: isError ? Colors.red : const Color(0xFF13877C),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int unreadCount = _notifications
        .where((Map<String, dynamic> item) => item['is_read'] != true)
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F8F7),
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: <Widget>[
          TextButton.icon(
            onPressed: _markingAll || unreadCount == 0 ? null : _markAllRead,
            icon: _markingAll
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.done_all_rounded),
            label: const Text('Mark all read'),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadNotifications,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: <Widget>[
          _filterBar(),
          Expanded(child: _content()),
        ],
      ),
    );
  }

  Widget _filterBar() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      child: Wrap(
        spacing: 12,
        children: <Widget>[
          ChoiceChip(
            label: const Text('All'),
            selected: !_unreadOnly,
            onSelected: (_) {
              if (_unreadOnly) {
                setState(() => _unreadOnly = false);
                _loadNotifications();
              }
            },
          ),
          ChoiceChip(
            label: const Text('Unread'),
            selected: _unreadOnly,
            onSelected: (_) {
              if (!_unreadOnly) {
                setState(() => _unreadOnly = true);
                _loadNotifications();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _content() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 52, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error!),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _loadNotifications,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      );
    }
    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.notifications_none_rounded,
              size: 72,
              color: Color(0xFF8CA3A0),
            ),
            const SizedBox(height: 15),
            Text(
              _unreadOnly
                  ? 'No unread notifications.'
                  : 'No notifications found.',
              style: const TextStyle(fontSize: 18, color: Color(0xFF6E8481)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.separated(
        padding: const EdgeInsets.all(28),
        itemCount: _notifications.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(height: 12),
        itemBuilder: (BuildContext context, int index) {
          return _NotificationCard(
            notification: _notifications[index],
            onTap: () => _markRead(_notifications[index]),
          );
        },
      ),
    );
  }
}

/// Aik notification ka responsive card.
class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final Map<String, dynamic> notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isRead = notification['is_read'] == true;
    final String type = notification['notification_type']?.toString() ?? '';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1050),
        child: Material(
          color: isRead ? Colors.white : const Color(0xFFE7F8F5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: isRead ? const Color(0xFFD8E5E3) : const Color(0xFF73CFC5),
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: _typeColor(type).withValues(alpha: 0.14),
                    child: Icon(_typeIcon(type), color: _typeColor(type)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                notification['title']?.toString() ??
                                    'Notification',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: isRead
                                      ? FontWeight.w600
                                      : FontWeight.w800,
                                  color: const Color(0xFF153936),
                                ),
                              ),
                            ),
                            if (!isRead)
                              const CircleAvatar(
                                radius: 5,
                                backgroundColor: Color(0xFF0B8A7E),
                              ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          notification['message']?.toString() ?? '',
                          style: const TextStyle(
                            color: Color(0xFF5E7471),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          _formatDate(notification['created_at']?.toString()),
                          style: const TextStyle(
                            color: Color(0xFF80928F),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static IconData _typeIcon(String type) {
    if (type.contains('appointment')) return Icons.calendar_month_outlined;
    if (type.contains('payment')) return Icons.payments_outlined;
    if (type.contains('prescription')) return Icons.medication_outlined;
    if (type.contains('doctor')) return Icons.medical_services_outlined;
    return Icons.notifications_active_outlined;
  }

  static Color _typeColor(String type) {
    if (type.contains('rejected') || type.contains('unavailable')) {
      return Colors.red;
    }
    if (type.contains('payment_verified') || type.contains('prescription')) {
      return Colors.green;
    }
    if (type.contains('reminder')) return Colors.orange;
    return const Color(0xFF087C72);
  }

  static String _formatDate(String? value) {
    final DateTime? date = value == null ? null : DateTime.tryParse(value);
    if (date == null) return '';
    final DateTime local = date.toLocal();
    final String hour = local.hour.toString().padLeft(2, '0');
    final String minute = local.minute.toString().padLeft(2, '0');
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}  '
        '$hour:$minute';
  }
}
