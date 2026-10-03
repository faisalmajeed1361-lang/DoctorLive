import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/dashboard_service.dart';
import '../auth/login_screen.dart';
import '../shared/profile_screen.dart';
import '../shared/notifications_screen.dart';
import 'doctor_appointments_screen.dart';
import 'doctor_consultations_history_screen.dart';
import 'doctor_medical_records_screen.dart';
import 'doctor_patients_screen.dart';
import 'doctor_prescriptions_screen.dart';

/// Logged-in doctor ka main dashboard.
class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  final DashboardService _dashboardService = DashboardService();

  final AuthService _authService = AuthService();

  late Future<Map<String, dynamic>> _dashboardFuture;

  @override
  void initState() {
    super.initState();

    // Screen open hote hi doctor dashboard data load karega.
    _dashboardFuture = _dashboardService.getDoctorDashboard();
  }

  /// Doctor dashboard data dobara load karega.
  Future<void> _refreshDashboard() async {
    setState(() {
      _dashboardFuture = _dashboardService.getDoctorDashboard();
    });

    await _dashboardFuture;
  }

  /// Local session clear karke login screen open karega.
  Future<void> _logout() async {
    await _authService.clearSession();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  /// Doctor appointments management screen open karega.
  Future<void> _openAppointments() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const DoctorAppointmentsScreen()),
    );

    if (mounted) {
      // Appointments screen se wapas aane par dashboard counts refresh honge.
      await _refreshDashboard();
    }
  }

  /// Logged-in doctor ki profile screen open karega.
  Future<void> _openProfile() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
    );

    // Profile update ke baad dashboard ka doctor name refresh karega.
    if (mounted) {
      await _refreshDashboard();
    }
  }

  /// Doctor notifications screen open karega.
  Future<void> _openNotifications() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
    );

    // Notifications read hone ke baad dashboard counts refresh karega.
    if (mounted) {
      await _refreshDashboard();
    }
  }

  /// Doctor ke unique appointment patients ki screen open karega.
  void _openPatients() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const DoctorPatientsScreen()),
    );
  }

  /// Doctor ki saved consultation history screen open karega.
  void _openConsultations() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const DoctorConsultationsHistoryScreen(),
      ),
    );
  }

  /// Doctor ki issue ki hui prescriptions screen open karega.
  void _openPrescriptions() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const DoctorPrescriptionsScreen(),
      ),
    );
  }

  /// Doctor ko accessible patient documents screen open karega.
  void _openMedicalRecords() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const DoctorMedicalRecordsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F8F7),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dashboardFuture,
        builder:
            (
              BuildContext context,
              AsyncSnapshot<Map<String, dynamic>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _DoctorDashboardError(
                  message: snapshot.error.toString().replaceFirst(
                    'Exception: ',
                    '',
                  ),
                  onRetry: _refreshDashboard,
                  onLogout: _logout,
                );
              }

              final Map<String, dynamic> data =
                  snapshot.data ?? <String, dynamic>{};

              final Map<String, dynamic> doctor =
                  data['doctor'] is Map<String, dynamic>
                  ? data['doctor'] as Map<String, dynamic>
                  : <String, dynamic>{};

              final Map<String, dynamic> statistics =
                  data['statistics'] is Map<String, dynamic>
                  ? data['statistics'] as Map<String, dynamic>
                  : <String, dynamic>{};

              final List<dynamic> appointments =
                  data['upcoming_patient_appointments'] is List
                  ? data['upcoming_patient_appointments'] as List<dynamic>
                  : <dynamic>[];

              final String fullName =
                  doctor['full_name']?.toString().trim() ?? '';

              final String displayName = fullName.isNotEmpty
                  ? fullName
                  : doctor['username']?.toString() ?? 'Doctor';

              return Row(
                children: [
                  // Desktop par doctor navigation sidebar.
                  if (MediaQuery.sizeOf(context).width >= 900)
                    _DoctorSidebar(
                      onLogout: _logout,
                      onAppointments: _openAppointments,
                      onProfile: _openProfile,
                      onNotifications: _openNotifications,
                      onPatients: _openPatients,
                      onConsultations: _openConsultations,
                      onPrescriptions: _openPrescriptions,
                      onMedicalRecords: _openMedicalRecords,
                    ),

                  // Dashboard ka main content.
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _refreshDashboard,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(
                            child: _DoctorHeader(
                              displayName: displayName,
                              onLogout: _logout,
                              onAppointments: _openAppointments,
                              onProfile: _openProfile,
                              onNotifications: _openNotifications,
                            ),
                          ),

                          SliverPadding(
                            padding: const EdgeInsets.all(24),
                            sliver: SliverToBoxAdapter(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _DoctorWelcomeCard(displayName: displayName),

                                  const SizedBox(height: 24),

                                  _DoctorStatisticsGrid(statistics: statistics),

                                  const SizedBox(height: 28),

                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'Upcoming Patient Appointments',
                                          style: TextStyle(
                                            color: Color(0xFF153936),
                                            fontSize: 22,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: _openAppointments,
                                        icon: const Icon(
                                          Icons.arrow_forward_rounded,
                                        ),
                                        label: const Text('View All'),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 14),

                                  _DoctorAppointmentsSection(
                                    appointments: appointments,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
      ),
    );
  }
}

/// Doctor dashboard desktop navigation sidebar.
class _DoctorSidebar extends StatelessWidget {
  const _DoctorSidebar({
    required this.onLogout,
    required this.onAppointments,
    required this.onProfile,
    required this.onNotifications,
    required this.onPatients,
    required this.onConsultations,
    required this.onPrescriptions,
    required this.onMedicalRecords,
  });

  final VoidCallback onLogout;
  final VoidCallback onAppointments;
  final VoidCallback onProfile;
  final VoidCallback onNotifications;
  final VoidCallback onPatients;
  final VoidCallback onConsultations;
  final VoidCallback onPrescriptions;
  final VoidCallback onMedicalRecords;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: const Color(0xFF075E57),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // DoctorLive custom logo.
              Container(
                width: 46,
                height: 46,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Image.asset(
                  'assets/images/doctorlive_logo.png',
                  fit: BoxFit.contain,
                  errorBuilder:
                      (
                        BuildContext context,
                        Object error,
                        StackTrace? stackTrace,
                      ) {
                        return const Icon(
                          Icons.health_and_safety_outlined,
                          color: AppColors.primary,
                        );
                      },
                ),
              ),

              const SizedBox(width: 12),

              const Text(
                'DoctorLive',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 44),

          const _DoctorSidebarItem(
            icon: Icons.dashboard_rounded,
            title: 'Dashboard',
            selected: true,
          ),

          _DoctorSidebarItem(
            icon: Icons.calendar_month_outlined,
            title: 'Appointments',
            onTap: onAppointments,
          ),

          _DoctorSidebarItem(
            icon: Icons.people_outline_rounded,
            title: 'Patients',
            onTap: onPatients,
          ),

          _DoctorSidebarItem(
            icon: Icons.video_call_outlined,
            title: 'Consultations',
            onTap: onConsultations,
          ),

          _DoctorSidebarItem(
            icon: Icons.medication_outlined,
            title: 'Prescriptions',
            onTap: onPrescriptions,
          ),

          _DoctorSidebarItem(
            icon: Icons.description_outlined,
            title: 'Medical Records',
            onTap: onMedicalRecords,
          ),

          _DoctorSidebarItem(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            onTap: onNotifications,
          ),

          _DoctorSidebarItem(
            icon: Icons.person_outline_rounded,
            title: 'Profile',
            onTap: onProfile,
          ),

          const Spacer(),

          ListTile(
            onTap: onLogout,
            leading: const Icon(Icons.logout_rounded, color: Colors.white70),
            title: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

/// Doctor sidebar ka reusable item.
class _DoctorSidebarItem extends StatelessWidget {
  const _DoctorSidebarItem({
    required this.icon,
    required this.title,
    this.selected = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected
            ? const Color.fromRGBO(255, 255, 255, 0.16)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: Colors.white),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Doctor dashboard ka upper header.
class _DoctorHeader extends StatelessWidget {
  const _DoctorHeader({
    required this.displayName,
    required this.onLogout,
    required this.onAppointments,
    required this.onProfile,
    required this.onNotifications,
  });

  final String displayName;
  final VoidCallback onLogout;
  final VoidCallback onAppointments;
  final VoidCallback onProfile;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 26),
      color: Colors.white,
      child: Row(
        children: [
          const Text(
            'Doctor Dashboard',
            style: TextStyle(
              color: Color(0xFF153936),
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),

          const Spacer(),

          IconButton(
            tooltip: 'Notifications',
            onPressed: onNotifications,
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.primary,
            ),
          ),

          if (MediaQuery.sizeOf(context).width < 900) ...[
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Appointments',
              onPressed: onAppointments,
              icon: const Icon(
                Icons.calendar_month_outlined,
                color: AppColors.primary,
              ),
            ),
          ],

          const SizedBox(width: 18),

          Tooltip(
            message: 'Open Profile',
            child: InkWell(
              onTap: onProfile,
              borderRadius: BorderRadius.circular(24),
              child: CircleAvatar(
                backgroundColor: const Color(0xFFD6F4EF),
                child: Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : 'D',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          if (MediaQuery.sizeOf(context).width >= 650)
            InkWell(
              onTap: onProfile,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                  displayName,
                  style: const TextStyle(
                    color: Color(0xFF153936),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

          // Small screens par header logout button.
          if (MediaQuery.sizeOf(context).width < 900) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Logout',
              onPressed: onLogout,
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ],
      ),
    );
  }
}

/// Doctor welcome information card.
class _DoctorWelcomeCard extends StatelessWidget {
  const _DoctorWelcomeCard({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF075E57), Color(0xFF13A89E)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome, Dr. $displayName',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 9),
          const Text(
            'Manage patient appointments, consultations '
            'and prescriptions from one secure dashboard.',
            style: TextStyle(
              color: Color(0xFFD9FFFA),
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Doctor dashboard statistics grid.
class _DoctorStatisticsGrid extends StatelessWidget {
  const _DoctorStatisticsGrid({required this.statistics});

  final Map<String, dynamic> statistics;

  @override
  Widget build(BuildContext context) {
    final List<_DoctorStatisticData> cards = [
      _DoctorStatisticData(
        title: 'Total Appointments',
        value: statistics['total_appointments'],
        icon: Icons.calendar_month_rounded,
        color: const Color(0xFF2563EB),
      ),
      _DoctorStatisticData(
        title: 'Today',
        value: statistics['today_appointments'],
        icon: Icons.today_rounded,
        color: const Color(0xFF0F9D8A),
      ),
      _DoctorStatisticData(
        title: 'Upcoming',
        value: statistics['upcoming_appointments'],
        icon: Icons.upcoming_rounded,
        color: const Color(0xFFF59E0B),
      ),
      _DoctorStatisticData(
        title: 'Completed',
        value: statistics['completed_appointments'],
        icon: Icons.task_alt_rounded,
        color: const Color(0xFF16A34A),
      ),
      _DoctorStatisticData(
        title: 'Consultations',
        value: statistics['consultations_completed'],
        icon: Icons.video_call_outlined,
        color: const Color(0xFF0891B2),
      ),
      _DoctorStatisticData(
        title: 'Prescriptions',
        value: statistics['prescriptions_created'],
        icon: Icons.medication_outlined,
        color: const Color(0xFF8B5CF6),
      ),
      _DoctorStatisticData(
        title: 'Active Sessions',
        value: statistics['active_sessions'],
        icon: Icons.online_prediction_rounded,
        color: const Color(0xFFEC4899),
      ),
      _DoctorStatisticData(
        title: 'Notifications',
        value: statistics['unread_notifications'],
        icon: Icons.notifications_active_outlined,
        color: const Color(0xFFEF4444),
      ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Available dashboard width ke mutabiq columns set karega.
        final double width = MediaQuery.sizeOf(context).width;

        // Desktop par 3 cards per row honge.
        // Isse 6 statistics sirf 2 rows mein fit hongi.
        final int columns = width >= 650
            ? 3
            : width >= 420
            ? 2
            : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 106,
          ),
          itemBuilder: (BuildContext context, int index) {
            final _DoctorStatisticData card = cards[index];

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: card.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(card.icon, color: card.color),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${card.value ?? 0}',
                          style: const TextStyle(
                            color: Color(0xFF153936),
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          card.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFF6B7E7C)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Upcoming patient appointment list.
class _DoctorAppointmentsSection extends StatelessWidget {
  const _DoctorAppointmentsSection({required this.appointments});

  final List<dynamic> appointments;

  @override
  Widget build(BuildContext context) {
    if (appointments.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Text(
          'No upcoming patient appointments found.',
          style: TextStyle(color: Color(0xFF6B7E7C)),
        ),
      );
    }

    return Column(
      children: appointments.map((dynamic item) {
        final Map<String, dynamic> appointment = item is Map<String, dynamic>
            ? item
            : <String, dynamic>{};

        final String date = appointment['appointment_date']?.toString() ?? '';

        final String time = appointment['appointment_time']?.toString() ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 25,
                backgroundColor: Color(0xFFD6F4EF),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment['patient_name']?.toString() ?? 'Patient',
                      style: const TextStyle(
                        color: Color(0xFF153936),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      appointment['clinic_name']?.toString() ?? 'Clinic',
                      style: const TextStyle(color: Color(0xFF6B7E7C)),
                    ),
                    if (date.isNotEmpty || time.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        '$date  $time',
                        style: const TextStyle(
                          color: Color(0xFF6B7E7C),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFD6F4EF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  appointment['status']?.toString() ?? 'Booked',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Dashboard API failure screen.
class _DoctorDashboardError extends StatelessWidget {
  const _DoctorDashboardError({
    required this.message,
    required this.onRetry,
    required this.onLogout,
  });

  final String message;
  final Future<void> Function() onRetry;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 55,
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(onPressed: onRetry, child: const Text('Try Again')),
            TextButton(onPressed: onLogout, child: const Text('Logout')),
          ],
        ),
      ),
    );
  }
}

/// Doctor statistic card ka data model.
class _DoctorStatisticData {
  const _DoctorStatisticData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final dynamic value;
  final IconData icon;
  final Color color;
}
