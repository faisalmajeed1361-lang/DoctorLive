import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import 'admin_payments_screen.dart';

/// Main dashboard shell for DoctorLive administrators.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() {
    return _AdminDashboardScreenState();
  }
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AuthService _authService = AuthService();

  bool _isLoggingOut = false;

  Future<void> _confirmLogout() async {
    if (_isLoggingOut) return;

    final bool shouldLogout =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Logout?'),
              content: const Text(
                'Do you want to logout from the admin account?',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(false);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(true);
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Logout'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldLogout || !mounted) return;

    setState(() {
      _isLoggingOut = true;
    });

    await _authService.logout();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return const LoginScreen();
        },
      ),
      (Route<dynamic> route) => false,
    );
  }

  void _handleSystemBack(bool didPop, dynamic result) {
    if (!didPop) {
      _confirmLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _handleSystemBack,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F8F7),
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          foregroundColor: const Color(0xFF153936),
          automaticallyImplyLeading: false,
          title: const Text(
            'DoctorLive Admin — Payment Verification',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          actions: <Widget>[
            IconButton(
              tooltip: 'Logout',
              onPressed: _isLoggingOut ? null : _confirmLogout,
              icon: _isLoggingOut
                  ? const SizedBox(
                      width: 21,
                      height: 21,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout_rounded),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: const AdminPaymentsScreen(embedded: true),
      ),
    );
  }
}
