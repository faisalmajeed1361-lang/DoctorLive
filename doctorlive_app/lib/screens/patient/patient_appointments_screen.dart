import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../services/appointment_service.dart';
import '../shared/online_consultation_actions.dart';

/// Patient ki tamam appointments show aur manage karega.
class PatientAppointmentsScreen extends StatefulWidget {
  const PatientAppointmentsScreen({super.key});

  @override
  State<PatientAppointmentsScreen> createState() =>
      _PatientAppointmentsScreenState();
}

class _PatientAppointmentsScreenState extends State<PatientAppointmentsScreen> {
  final AppointmentService _appointmentService = AppointmentService();

  late Future<List<Map<String, dynamic>>> _appointmentsFuture;

  @override
  void initState() {
    super.initState();

    // Screen open hote hi appointment list load karega.
    _appointmentsFuture = _appointmentService.getAppointments();
  }

  /// Appointment list backend se dobara load karega.
  Future<void> _refreshAppointments() async {
    final Future<List<Map<String, dynamic>>> request = _appointmentService
        .getAppointments();

    setState(() {
      _appointmentsFuture = request;
    });

    await request;
  }

  /// Appointment cancel karne se pehle confirmation lega.
  Future<void> _showCancellationDialog(Map<String, dynamic> appointment) async {
    final TextEditingController reasonController = TextEditingController();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Cancel Appointment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Please provide a cancellation reason.'),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 3,
                maxLength: 250,
                decoration: const InputDecoration(
                  labelText: 'Cancellation reason',
                  hintText: 'Example: I am not available at this time.',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Keep Appointment'),
            ),
            FilledButton(
              onPressed: () {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cancellation reason is required.'),
                    ),
                  );
                  return;
                }

                Navigator.of(dialogContext).pop(true);
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Cancel Appointment'),
            ),
          ],
        );
      },
    );

    final String cancellationReason = reasonController.text.trim();

    reasonController.dispose();

    if (confirmed != true || cancellationReason.isEmpty) {
      return;
    }

    final int? appointmentId = _readInteger(appointment['id']);

    if (appointmentId == null) {
      _showMessage('Appointment ID is missing.', isError: true);
      return;
    }

    await _cancelAppointment(
      appointmentId: appointmentId,
      reason: cancellationReason,
    );
  }

  /// Selected appointment backend par cancel karega.
  Future<void> _cancelAppointment({
    required int appointmentId,
    required String reason,
  }) async {
    try {
      await _appointmentService.cancelAppointment(
        appointmentId: appointmentId,
        cancellationReason: reason,
      );

      if (!mounted) {
        return;
      }

      _showMessage('Appointment successfully cancelled.', isError: false);

      await _refreshAppointments();
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  /// Dynamic API ID ko integer mein convert karega.
  int? _readInteger(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '');
  }

  /// Success ya error notification show karega.
  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : const Color(0xFF15803D),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F8F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: const Color(0xFF153936),
        title: const Text(
          'My Appointments',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshAppointments,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _appointmentsFuture,
        builder:
            (
              BuildContext context,
              AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _AppointmentsError(
                  message: snapshot.error.toString().replaceFirst(
                    'Exception: ',
                    '',
                  ),
                  onRetry: _refreshAppointments,
                );
              }

              final List<Map<String, dynamic>> appointments =
                  snapshot.data ?? <Map<String, dynamic>>[];

              if (appointments.isEmpty) {
                return _EmptyAppointments(onRefresh: _refreshAppointments);
              }

              return RefreshIndicator(
                onRefresh: _refreshAppointments,
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final int columns = constraints.maxWidth >= 1200
                        ? 3
                        : constraints.maxWidth >= 750
                        ? 2
                        : 1;

                    return GridView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: appointments.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 18,
                        mainAxisSpacing: 18,
                        // Online session status/join button ke liye extra height.
                        mainAxisExtent: 470,
                      ),
                      itemBuilder: (BuildContext context, int index) {
                        final Map<String, dynamic> appointment =
                            appointments[index];

                        return _AppointmentCard(
                          appointment: appointment,
                          onCancel: () {
                            _showCancellationDialog(appointment);
                          },
                        );
                      },
                    );
                  },
                ),
              );
            },
      ),
    );
  }
}

/// Single appointment ki complete summary card.
class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.appointment, required this.onCancel});

  final Map<String, dynamic> appointment;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final String status =
        appointment['status']?.toString().toLowerCase() ?? 'booked';

    final String statusDisplay =
        appointment['status_display']?.toString() ?? _titleCase(status);

    final String doctorName =
        appointment['doctor_name']?.toString() ?? 'Doctor';

    final String clinicName =
        appointment['clinic_name']?.toString() ?? 'Clinic not provided';

    final String clinicCity = appointment['clinic_city']?.toString() ?? '';

    final String appointmentDate =
        appointment['appointment_date']?.toString() ?? '-';

    final String appointmentTime =
        appointment['appointment_time']?.toString() ?? '-';

    final String tokenNumber = appointment['token_number']?.toString() ?? '-';

    final String consultationMode =
        appointment['consultation_mode_display']?.toString() ??
        _titleCase(appointment['consultation_mode']?.toString() ?? 'in person');

    final String symptoms =
        appointment['symptom_summary']?.toString() ?? 'No symptoms provided.';

    final bool canCancel =
        status == 'booked' || status == 'confirmed' || status == 'pending';

    final Color statusColor = _statusColor(status);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE9E7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 27,
                backgroundColor: Color(0xFFD6F4EF),
                child: Icon(
                  Icons.medical_services_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF153936),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      clinicName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF6B7E7C)),
                    ),
                  ],
                ),
              ),
              _StatusBadge(text: statusDisplay, color: statusColor),
            ],
          ),

          const SizedBox(height: 18),

          _AppointmentInfo(
            icon: Icons.calendar_month_outlined,
            label: 'Date',
            value: appointmentDate,
          ),
          const SizedBox(height: 9),
          _AppointmentInfo(
            icon: Icons.schedule_outlined,
            label: 'Time',
            value: appointmentTime,
          ),
          const SizedBox(height: 9),
          _AppointmentInfo(
            icon: Icons.confirmation_number_outlined,
            label: 'Token',
            value: tokenNumber,
          ),
          const SizedBox(height: 9),
          _AppointmentInfo(
            icon: Icons.video_call_outlined,
            label: 'Mode',
            value: consultationMode,
          ),
          const SizedBox(height: 9),
          _AppointmentInfo(
            icon: Icons.location_on_outlined,
            label: 'City',
            value: clinicCity.isEmpty ? 'Not provided' : clinicCity,
          ),

          const SizedBox(height: 14),

          Text(
            symptoms,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF6B7E7C), height: 1.4),
          ),

          const Spacer(),

          OnlineConsultationActions(appointment: appointment, isDoctor: false),

          if (canCancel) const SizedBox(height: 10),

          if (canCancel)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel Appointment'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Appointment status ke mutabiq color return karega.
  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFF15803D);
      case 'cancelled':
        return AppColors.error;
      case 'confirmed':
        return const Color(0xFF2563EB);
      case 'in_progress':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  /// Snake case text ko readable title mein convert karega.
  String _titleCase(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (String word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}'
                    '${word.substring(1)}',
        )
        .join(' ');
  }
}

/// Appointment ki reusable label aur value row.
class _AppointmentInfo extends StatelessWidget {
  const _AppointmentInfo({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 9),
        Text(
          '$label: ',
          style: const TextStyle(
            color: Color(0xFF6B7E7C),
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF153936)),
          ),
        ),
      ],
    );
  }
}

/// Appointment status badge.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Appointment list empty state.
class _EmptyAppointments extends StatelessWidget {
  const _EmptyAppointments({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.calendar_month_outlined,
            color: Color(0xFF6B7E7C),
            size: 60,
          ),
          const SizedBox(height: 14),
          const Text(
            'No appointments found.',
            style: TextStyle(
              color: Color(0xFF153936),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}

/// Appointment API error state.
class _AppointmentsError extends StatelessWidget {
  const _AppointmentsError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

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
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton(onPressed: onRetry, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}
