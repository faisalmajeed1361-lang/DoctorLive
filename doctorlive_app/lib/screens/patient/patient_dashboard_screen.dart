import 'package:flutter/material.dart';
import '../shared/profile_screen.dart';
import '../shared/notifications_screen.dart';
import '../../config/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/dashboard_service.dart';
import '../auth/login_screen.dart';
import 'find_doctors_screen.dart';
import 'patient_appointments_screen.dart';
import 'patient_medical_records_screen.dart';
import 'patient_payments_screen.dart';

/// Logged-in patient ka main dashboard.
class PatientDashboardScreen extends StatefulWidget {
  const PatientDashboardScreen({super.key});

  @override
  State<PatientDashboardScreen> createState() => _PatientDashboardScreenState();
}

class _PatientDashboardScreenState extends State<PatientDashboardScreen> {
  final DashboardService _dashboardService = DashboardService();

  final AuthService _authService = AuthService();

  late Future<Map<String, dynamic>> _dashboardFuture;

  @override
  void initState() {
    super.initState();

    // Screen open hote hi dashboard data load karega.
    _dashboardFuture = _dashboardService.getPatientDashboard();
  }

  /// Dashboard API ko dobara call karega.
  Future<void> _refreshDashboard() async {
    setState(() {
      _dashboardFuture = _dashboardService.getPatientDashboard();
    });

    await _dashboardFuture;
  }

  /// Patient profile screen open karega.
  Future<void> _openProfile() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
    );

    // Profile update ke baad dashboard name aur data refresh karega.
    if (mounted) {
      await _refreshDashboard();
    }
  }

  /// Patient notifications screen open karega.
  Future<void> _openNotifications() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
    );

    // Read status change hone ke baad dashboard badge refresh karega.
    if (mounted) {
      await _refreshDashboard();
    }
  }

  /// Local login session clear karke login screen kholega.
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
                return _DashboardError(
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

              final Map<String, dynamic> user =
                  data['user'] is Map<String, dynamic>
                  ? data['user'] as Map<String, dynamic>
                  : <String, dynamic>{};

              final Map<String, dynamic> statistics =
                  data['statistics'] is Map<String, dynamic>
                  ? data['statistics'] as Map<String, dynamic>
                  : <String, dynamic>{};

              final List<dynamic> appointments =
                  data['recent_appointments'] is List
                  ? data['recent_appointments'] as List<dynamic>
                  : <dynamic>[];

              final String fullName =
                  user['full_name']?.toString().trim() ?? '';

              final String displayName = fullName.isNotEmpty
                  ? fullName
                  : user['username']?.toString() ?? 'Patient';

              return Row(
                children: [
                  // Desktop navigation sidebar.
                  if (MediaQuery.sizeOf(context).width >= 900)
                    _PatientSidebar(
                      onFindDoctors: () {
                        // Find Doctors screen open karega.
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const FindDoctorsScreen(),
                          ),
                        );
                      },
                      onAppointments: () {
                        // Patient appointments list screen open karega.
                        Navigator.of(context)
                            .push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    const PatientAppointmentsScreen(),
                              ),
                            )
                            .then((_) {
                              // List screen se wapas aane par dashboard
                              // statistics aur recent appointments refresh karega.
                              if (mounted) {
                                _refreshDashboard();
                              }
                            });
                      },
                      onPayments: () {
                        // Patient payments aur new payment submission
                        // screen open karega.
                        Navigator.of(context)
                            .push(
                              MaterialPageRoute<void>(
                                builder: (_) => const PatientPaymentsScreen(),
                              ),
                            )
                            .then((_) {
                              // Wapas aane par payment statistics refresh
                              // karega.
                              if (mounted) {
                                _refreshDashboard();
                              }
                            });
                      },
                      onMedicalRecords: () {
                        // Patient prescriptions aur medical documents
                        // screen open karega.
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const PatientMedicalRecordsScreen(),
                          ),
                        );
                      },
                      onProfile: _openProfile,
                      onNotifications: _openNotifications,
                      onLogout: _logout,
                    ),

                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _refreshDashboard,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(
                            child: _DashboardHeader(
                              displayName: displayName,
                              onProfile: _openProfile,
                              onNotifications: _openNotifications,
                              onLogout: _logout,
                            ),
                          ),

                          SliverPadding(
                            padding: const EdgeInsets.all(24),
                            sliver: SliverToBoxAdapter(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _WelcomeCard(displayName: displayName),

                                  const SizedBox(height: 24),

                                  _StatisticsGrid(statistics: statistics),

                                  const SizedBox(height: 28),

                                  const Text(
                                    'Recent Appointments',
                                    style: TextStyle(
                                      color: Color(0xFF153936),
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),

                                  const SizedBox(height: 14),

                                  _AppointmentsSection(
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

/// Patient dashboard desktop sidebar.
class _PatientSidebar extends StatelessWidget {
  const _PatientSidebar({
    required this.onFindDoctors,
    required this.onAppointments,
    required this.onPayments,
    required this.onMedicalRecords,
    required this.onProfile,
    required this.onNotifications,
    required this.onLogout,
  });

  final VoidCallback onFindDoctors;
  final VoidCallback onAppointments;
  final VoidCallback onPayments;
  final VoidCallback onMedicalRecords;
  final VoidCallback onProfile;
  final VoidCallback onNotifications;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: const Color(0xFF075E57),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // DoctorLive ka custom stethoscope logo.
              Container(
                width: 54,
                height: 54,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Image.asset(
                  'assets/images/doctorlive_logo.png',
                  fit: BoxFit.contain,

                  // Asset load failure par fallback icon show karega.
                  errorBuilder:
                      (
                        BuildContext context,
                        Object error,
                        StackTrace? stackTrace,
                      ) {
                        return const Icon(
                          Icons.health_and_safety_outlined,
                          color: AppColors.primary,
                          size: 32,
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

          const SizedBox(height: 46),

          const _SidebarItem(
            icon: Icons.dashboard_rounded,
            title: 'Dashboard',
            selected: true,
          ),

          _SidebarItem(
            icon: Icons.medical_services_outlined,
            title: 'Find Doctors',
            onTap: onFindDoctors,
          ),

          _SidebarItem(
            icon: Icons.calendar_month_outlined,
            title: 'Appointments',
            onTap: onAppointments,
          ),

          _SidebarItem(
            icon: Icons.payments_outlined,
            title: 'Payments',
            onTap: onPayments,
          ),

          _SidebarItem(
            icon: Icons.description_outlined,
            title: 'Medical Records',
            onTap: onMedicalRecords,
          ),

          _SidebarItem(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            onTap: onNotifications,
          ),

          _SidebarItem(
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

/// Sidebar ka reusable navigation item.
class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
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

/// Dashboard ka upper header.
class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.displayName,
    required this.onProfile,
    required this.onNotifications,
    required this.onLogout,
  });

  final String displayName;
  final VoidCallback onProfile;
  final VoidCallback onNotifications;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 26),
      color: Colors.white,
      child: Row(
        children: [
          const Text(
            'Patient Dashboard',
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

          const SizedBox(width: 18),

          Tooltip(
            message: 'Open Profile',
            child: InkWell(
              onTap: onProfile,
              borderRadius: BorderRadius.circular(24),
              child: CircleAvatar(
                backgroundColor: const Color(0xFFD6F4EF),
                child: Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : 'P',
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

/// Patient welcome section.
class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.displayName});

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
            'Welcome, $displayName',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 9),
          const Text(
            'Manage your appointments, payments and '
            'medical records from one secure place.',
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

/// Patient statistics responsive grid.
class _StatisticsGrid extends StatelessWidget {
  const _StatisticsGrid({required this.statistics});

  final Map<String, dynamic> statistics;

  @override
  Widget build(BuildContext context) {
    final List<_StatisticData> cards = [
      _StatisticData(
        title: 'Total Appointments',
        value: statistics['total_appointments'],
        icon: Icons.calendar_month_rounded,
        color: const Color(0xFF2563EB),
      ),
      _StatisticData(
        title: 'Upcoming',
        value: statistics['upcoming_appointments'],
        icon: Icons.upcoming_rounded,
        color: const Color(0xFF0F9D8A),
      ),
      _StatisticData(
        title: 'Completed',
        value: statistics['completed_appointments'],
        icon: Icons.task_alt_rounded,
        color: const Color(0xFF16A34A),
      ),
      _StatisticData(
        title: 'Pending Payments',
        value: statistics['pending_payments'],
        icon: Icons.account_balance_wallet_outlined,
        color: const Color(0xFFF59E0B),
      ),
      _StatisticData(
        title: 'Prescriptions',
        value: statistics['prescriptions'],
        icon: Icons.medication_outlined,
        color: const Color(0xFF8B5CF6),
      ),
      _StatisticData(
        title: 'Notifications',
        value: statistics['unread_notifications'],
        icon: Icons.notifications_active_outlined,
        color: const Color(0xFFEF4444),
      ),
    ];

    final double width = MediaQuery.sizeOf(context).width;

    final int columns = width >= 1250
        ? 3
        : width >= 700
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
        mainAxisExtent: 105,
      ),
      itemBuilder: (BuildContext context, int index) {
        final _StatisticData card = cards[index];

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
  }
}

/// Recent appointments show karega.
class _AppointmentsSection extends StatelessWidget {
  const _AppointmentsSection({required this.appointments});

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
          'No recent appointments found.',
          style: TextStyle(color: Color(0xFF6B7E7C)),
        ),
      );
    }

    return Column(
      children: appointments.map((dynamic item) {
        final Map<String, dynamic> appointment = item is Map<String, dynamic>
            ? item
            : <String, dynamic>{};

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
                child: Icon(Icons.person_outline, color: AppColors.primary),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment['doctor_name']?.toString() ?? 'Doctor',
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
                  ],
                ),
              ),
              Text(
                appointment['status']?.toString() ?? 'Booked',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Dashboard loading failure widget.
class _DashboardError extends StatelessWidget {
  const _DashboardError({
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

/// Single statistic card ka data model.
class _StatisticData {
  const _StatisticData({
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
