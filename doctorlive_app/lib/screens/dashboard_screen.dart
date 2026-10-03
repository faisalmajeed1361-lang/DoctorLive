import 'package:flutter/material.dart';

import 'admin/admin_dashboard_screen.dart';
import 'doctor/doctor_dashboard_screen.dart';
import 'patient/patient_dashboard_screen.dart';

/// Common dashboard entry point for all DoctorLive roles.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({required this.role, super.key});

  final String role;

  @override
  Widget build(BuildContext context) {
    final String normalizedRole = role.trim().toLowerCase();

    switch (normalizedRole) {
      case 'admin':
        return const AdminDashboardScreen();

      case 'doctor':
        return const DoctorDashboardScreen();

      case 'patient':
        return const PatientDashboardScreen();

      default:
        return _UnsupportedRoleScreen(role: normalizedRole);
    }
  }
}

class _UnsupportedRoleScreen extends StatelessWidget {
  const _UnsupportedRoleScreen({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DoctorLive')),
      body: Center(child: Text('Unsupported account role: $role')),
    );
  }
}
