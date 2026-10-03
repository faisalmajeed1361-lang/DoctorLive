import 'package:flutter/material.dart';

import '../../config/app_theme.dart';

import '../../services/appointment_service.dart';

import '../../services/live_doctor_status_service.dart';

import '../shared/online_consultation_actions.dart';

import 'doctor_consultation_screen.dart';

/// Logged-in doctor ko uski patient appointments manage karne dega.

class DoctorAppointmentsScreen extends StatefulWidget {
  const DoctorAppointmentsScreen({super.key});

  @override
  State<DoctorAppointmentsScreen> createState() =>
      _DoctorAppointmentsScreenState();
}

class _DoctorAppointmentsScreenState extends State<DoctorAppointmentsScreen> {
  final AppointmentService _appointmentService = AppointmentService();

  final LiveDoctorStatusService _liveStatusService = LiveDoctorStatusService();

  late Future<List<Map<String, dynamic>>> _appointmentsFuture;

  String _selectedFilter = 'all';

  final Set<int> _processingAppointmentIds = <int>{};

  Map<String, dynamic>? _liveStatus;

  int? _doctorClinicId;

  bool _isLiveStatusLoading = false;

  bool _isLiveStatusUpdating = false;

  String? _liveStatusError;

  @override
  void initState() {
    super.initState();

    _appointmentsFuture = _loadAppointmentsAndLiveStatus();
  }

  @override
  void dispose() {
    _liveStatusService.dispose();

    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadAppointmentsAndLiveStatus() async {
    final List<Map<String, dynamic>> appointments = await _appointmentService
        .getAppointments();

    _isLiveStatusLoading = true;

    _liveStatusError = null;

    try {
      // Logged-in doctor ka clinic appointment list se derive nahi hoga.

      // Backend ka /live-status/me/ endpoint exact clinic return karega.

      final Map<String, dynamic> liveStatus = await _liveStatusService
          .getMyLiveStatus();

      final int? doctorClinicId = int.tryParse(
        liveStatus['doctor_clinic']?.toString() ?? '',
      );

      _liveStatus = liveStatus;

      _doctorClinicId = doctorClinicId;

      if (doctorClinicId == null) {
        _liveStatusError = 'Backend response mein doctor clinic ID nahi mili.';
      }
    } catch (error) {
      _liveStatus = null;

      _doctorClinicId = null;

      _liveStatusError = error.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLiveStatusLoading = false;
    }

    return appointments;
  }

  Future<void> _loadLiveStatus(int doctorClinicId, {bool notify = true}) async {
    if (notify && mounted) {
      setState(() {
        _isLiveStatusLoading = true;

        _liveStatusError = null;
      });
    }

    try {
      _liveStatus = await _liveStatusService.getLiveStatus(
        doctorClinicId: doctorClinicId,
      );

      _liveStatusError = null;
    } catch (error) {
      _liveStatusError = error.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLiveStatusLoading = false;

      if (notify && mounted) setState(() {});
    }
  }

  Future<void> _updateLiveStatus(String newStatus) async {
    final int? doctorClinicId = _doctorClinicId;

    if (doctorClinicId == null || _isLiveStatusUpdating) return;

    setState(() => _isLiveStatusUpdating = true);

    try {
      final Map<String, dynamic> response = await _liveStatusService
          .updateLiveStatus(
            doctorClinicId: doctorClinicId,

            status: newStatus,

            currentToken: _currentLiveToken,

            statusNote: _defaultStatusNote(newStatus),
          );

      _applyLiveStatusResponse(response);

      if (!mounted) return;

      _showMessage(
        response['message']?.toString() ??
            'Live status successfully update ho gaya.',
      );
    } catch (error) {
      if (mounted) {
        _showMessage(
          error.toString().replaceFirst('Exception: ', ''),

          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLiveStatusUpdating = false);
    }
  }

  Future<void> _moveToNextToken() async {
    final int? doctorClinicId = _doctorClinicId;

    if (doctorClinicId == null || _isLiveStatusUpdating) return;

    setState(() => _isLiveStatusUpdating = true);

    try {
      final Map<String, dynamic> response = await _liveStatusService
          .moveToNextToken(doctorClinicId: doctorClinicId);

      _applyLiveStatusResponse(response);

      if (!mounted) return;

      _showMessage(
        response['message']?.toString() ?? 'Current token update ho gaya.',
      );
    } catch (error) {
      if (mounted) {
        _showMessage(
          error.toString().replaceFirst('Exception: ', ''),

          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLiveStatusUpdating = false);
    }
  }

  Future<void> _resetQueue() async {
    final int? doctorClinicId = _doctorClinicId;

    if (doctorClinicId == null || _isLiveStatusUpdating) return;

    final bool confirmed =
        await showDialog<bool>(
          context: context,

          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Reset queue?'),

            content: const Text(
              'Current token zero ho jayega aur status Available ho jayega.',
            ),

            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),

                child: const Text('Back'),
              ),

              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),

                child: const Text('Reset Queue'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;

    setState(() => _isLiveStatusUpdating = true);

    try {
      final Map<String, dynamic> response = await _liveStatusService.resetQueue(
        doctorClinicId: doctorClinicId,
      );

      _applyLiveStatusResponse(response);

      if (!mounted) return;

      _showMessage(
        response['message']?.toString() ?? 'Doctor queue reset ho gayi.',
      );
    } catch (error) {
      if (mounted) {
        _showMessage(
          error.toString().replaceFirst('Exception: ', ''),

          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLiveStatusUpdating = false);
    }
  }

  void _applyLiveStatusResponse(Map<String, dynamic> response) {
    final dynamic rawStatus = response['live_status'];

    if (rawStatus is Map) {
      _liveStatus = Map<String, dynamic>.from(rawStatus);
    }
  }

  int get _currentLiveToken =>
      int.tryParse(_liveStatus?['current_token']?.toString() ?? '') ?? 0;

  /// Backend se doctor ki latest appointment list load karega.

  Future<void> _refreshAppointments() async {
    final Future<List<Map<String, dynamic>>> request =
        _loadAppointmentsAndLiveStatus();

    setState(() {
      _appointmentsFuture = request;
    });

    await request;
  }

  /// Doctor confirmation ke baad appointment status backend par update karega.

  Future<void> _updateAppointmentStatus(
    Map<String, dynamic> appointment,

    String newStatus,
  ) async {
    final int? appointmentId = int.tryParse(
      appointment['id']?.toString() ?? '',
    );

    if (appointmentId == null) {
      _showMessage('Appointment ID available nahi hai.', isError: true);

      return;
    }

    final bool confirmed = await _confirmStatusChange(newStatus);

    if (!confirmed || !mounted) return;

    setState(() {
      _processingAppointmentIds.add(appointmentId);
    });

    try {
      final Map<String, dynamic> result = await _appointmentService
          .updateDoctorAppointmentStatus(
            appointmentId: appointmentId,

            newStatus: newStatus,
          );

      if (!mounted) return;

      _showMessage(
        result['message']?.toString() ??
            'Appointment status successfully update ho gaya.',
      );

      await _refreshAppointments();

      // Start ke baad doctor ko seedha clinical notes screen par le jayega.

      if (newStatus == 'in_consultation' && mounted) {
        final dynamic rawUpdatedAppointment = result['appointment'];

        await _openConsultation(
          rawUpdatedAppointment is Map
              ? Map<String, dynamic>.from(rawUpdatedAppointment)
              : <String, dynamic>{...appointment, 'status': 'in_consultation'},
        );
      }
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),

        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingAppointmentIds.remove(appointmentId);
        });
      }
    }
  }

  /// Active consultation ka notes aur prescription form open karega.

  Future<void> _openConsultation(Map<String, dynamic> appointment) async {
    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) =>
            DoctorConsultationScreen(appointment: appointment),
      ),
    );

    if (changed == true && mounted) {
      await _refreshAppointments();
    }
  }

  /// Destructive ya workflow-changing action se pehle confirmation lega.

  Future<bool> _confirmStatusChange(String newStatus) async {
    final String actionLabel = _actionLabel(newStatus);

    return await showDialog<bool>(
          context: context,

          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: Text(actionLabel),

              content: Text(
                'Kya aap appointment ko "$actionLabel" karna chahte hain?',
              ),

              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),

                  child: const Text('Back'),
                ),

                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),

                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  /// Success aur error feedback screen ke bottom par show karega.

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),

          backgroundColor: isError ? AppColors.error : AppColors.primary,
        ),
      );
  }

  /// Selected tab ke mutabiq appointment list filter karega.

  List<Map<String, dynamic>> _filteredAppointments(
    List<Map<String, dynamic>> appointments,
  ) {
    final DateTime now = DateTime.now();

    final DateTime today = DateTime(now.year, now.month, now.day);

    return appointments.where((Map<String, dynamic> appointment) {
      final String status = _appointmentStatus(appointment);

      final DateTime? date = _appointmentDate(appointment);

      switch (_selectedFilter) {
        case 'today':
          return date != null &&
              date.year == today.year &&
              date.month == today.month &&
              date.day == today.day;

        case 'upcoming':
          return date != null &&
              !date.isBefore(today) &&
              status != 'cancelled' &&
              status != 'completed';

        case 'completed':
          return status == 'completed';

        case 'cancelled':
          return status == 'cancelled';

        default:
          return true;
      }
    }).toList()..sort((
      Map<String, dynamic> first,
      Map<String, dynamic> second,
    ) {
      final DateTime firstDate = _appointmentDateTime(first) ?? DateTime(2100);

      final DateTime secondDate =
          _appointmentDateTime(second) ?? DateTime(2100);

      return firstDate.compareTo(secondDate);
    });
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
          'Appointments',

          style: TextStyle(fontWeight: FontWeight.w700),
        ),

        actions: [
          IconButton(
            tooltip: 'Refresh appointments',

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
                return _ErrorState(
                  message: snapshot.error.toString().replaceFirst(
                    'Exception: ',
                    '',
                  ),

                  onRetry: _refreshAppointments,
                );
              }

              final List<Map<String, dynamic>> allAppointments =
                  snapshot.data ?? <Map<String, dynamic>>[];

              final List<Map<String, dynamic>> appointments =
                  _filteredAppointments(allAppointments);

              return Column(
                children: [
                  _AppointmentFilters(
                    selectedFilter: _selectedFilter,

                    appointments: allAppointments,

                    onChanged: (String value) {
                      setState(() {
                        _selectedFilter = value;
                      });
                    },
                  ),

                  if (_doctorClinicId != null ||
                      _liveStatusError != null ||
                      _isLiveStatusLoading)
                    _LiveStatusPanel(
                      liveStatus: _liveStatus,

                      isLoading: _isLiveStatusLoading,

                      isUpdating: _isLiveStatusUpdating,

                      errorMessage: _liveStatusError,

                      onStatusChanged: _updateLiveStatus,

                      onNextToken: _moveToNextToken,

                      onResetQueue: _resetQueue,

                      onRefresh: () {
                        final int? doctorClinicId = _doctorClinicId;

                        if (doctorClinicId != null) {
                          _loadLiveStatus(doctorClinicId);
                        } else {
                          _refreshAppointments();
                        }
                      },
                    ),

                  Expanded(
                    child: appointments.isEmpty
                        ? const _EmptyAppointments()
                        : RefreshIndicator(
                            onRefresh: _refreshAppointments,

                            child: LayoutBuilder(
                              builder: (BuildContext context, BoxConstraints constraints) {
                                final int columns = constraints.maxWidth >= 1150
                                    ? 3
                                    : constraints.maxWidth >= 720
                                    ? 2
                                    : 1;

                                return GridView.builder(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),

                                  padding: const EdgeInsets.all(24),

                                  itemCount: appointments.length,

                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: columns,

                                        crossAxisSpacing: 18,

                                        mainAxisSpacing: 18,

                                        // Online session status/buttons ke liye extra height.
                                        mainAxisExtent: 520,
                                      ),

                                  itemBuilder:
                                      (BuildContext context, int index) {
                                        return _AppointmentCard(
                                          appointment: appointments[index],

                                          isProcessing:
                                              _processingAppointmentIds
                                                  .contains(
                                                    int.tryParse(
                                                      appointments[index]['id']
                                                              ?.toString() ??
                                                          '',
                                                    ),
                                                  ),

                                          onStatusChanged: (String newStatus) {
                                            _updateAppointmentStatus(
                                              appointments[index],

                                              newStatus,
                                            );
                                          },

                                          onOpenConsultation: () {
                                            _openConsultation(
                                              appointments[index],
                                            );
                                          },
                                        );
                                      },
                                );
                              },
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

/// Doctor ki live availability aur current queue controls.
class _LiveStatusPanel extends StatelessWidget {
  const _LiveStatusPanel({
    required this.liveStatus,
    required this.isLoading,
    required this.isUpdating,
    required this.errorMessage,
    required this.onStatusChanged,
    required this.onNextToken,
    required this.onResetQueue,
    required this.onRefresh,
  });

  final Map<String, dynamic>? liveStatus;
  final bool isLoading;
  final bool isUpdating;
  final String? errorMessage;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onNextToken;
  final VoidCallback onResetQueue;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (isLoading && liveStatus == null) {
      return const LinearProgressIndicator(minHeight: 3);
    }

    if (errorMessage != null && liveStatus == null) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error),
            const SizedBox(width: 12),
            Expanded(child: Text(errorMessage!)),
            TextButton(onPressed: onRefresh, child: const Text('Retry')),
          ],
        ),
      );
    }

    final Map<String, dynamic> status = liveStatus ?? <String, dynamic>{};
    final String selectedStatus = status['status']?.toString() ?? 'off_duty';
    final int currentToken =
        int.tryParse(status['current_token']?.toString() ?? '') ?? 0;
    final String clinicName =
        status['clinic_name']?.toString() ?? 'Doctor Clinic';
    final String note = status['status_note']?.toString().trim() ?? '';
    final bool stale = status['is_status_stale'] == true;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(18),
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
                backgroundColor: Color(0xFFD6F4EF),
                child: Icon(
                  Icons.monitor_heart_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Live Doctor Status & Queue',
                      style: TextStyle(
                        color: Color(0xFF153936),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      clinicName,
                      style: const TextStyle(color: Color(0xFF6B7E7C)),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh live status',
                onPressed: isUpdating ? null : onRefresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool compact = constraints.maxWidth < 760;
              final Widget statusField = DropdownButtonFormField<String>(
                initialValue: selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Doctor status',
                  prefixIcon: Icon(Icons.online_prediction_outlined),
                  border: OutlineInputBorder(),
                ),
                items: _liveStatusChoices
                    .map(
                      ((String, String) option) => DropdownMenuItem<String>(
                        value: option.$1,
                        child: Text(option.$2),
                      ),
                    )
                    .toList(),
                onChanged: isUpdating
                    ? null
                    : (String? value) {
                        if (value != null && value != selectedStatus) {
                          onStatusChanged(value);
                        }
                      },
              );
              final Widget tokenCard = Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F7F4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.confirmation_number_outlined,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Current Token: $currentToken',
                      style: const TextStyle(
                        color: Color(0xFF153936),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    statusField,
                    const SizedBox(height: 12),
                    tokenCard,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: statusField),
                  const SizedBox(width: 14),
                  tokenCard,
                ],
              );
            },
          ),
          if (note.isNotEmpty || stale) ...[
            const SizedBox(height: 12),
            Text(
              stale ? 'Status purana hai. Refresh ya update karein.' : note,
              style: TextStyle(
                color: stale
                    ? const Color(0xFFD97706)
                    : const Color(0xFF6B7E7C),
                fontWeight: stale ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (isUpdating)
            const LinearProgressIndicator(minHeight: 3)
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: onNextToken,
                  icon: const Icon(Icons.skip_next_rounded),
                  label: const Text('Next Token'),
                ),
                OutlinedButton.icon(
                  onPressed: onResetQueue,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Reset Queue'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Appointment status filters aur live counters show karega.

class _AppointmentFilters extends StatelessWidget {
  const _AppointmentFilters({
    required this.selectedFilter,

    required this.appointments,

    required this.onChanged,
  });

  final String selectedFilter;

  final List<Map<String, dynamic>> appointments;

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();

    final DateTime today = DateTime(now.year, now.month, now.day);

    int count(String filter) {
      return appointments.where((Map<String, dynamic> appointment) {
        final String status = _appointmentStatus(appointment);

        final DateTime? date = _appointmentDate(appointment);

        if (filter == 'today') {
          return date != null &&
              date.year == today.year &&
              date.month == today.month &&
              date.day == today.day;
        }

        if (filter == 'upcoming') {
          return date != null &&
              !date.isBefore(today) &&
              status != 'completed' &&
              status != 'cancelled';
        }

        return filter == 'all' ? true : status == filter;
      }).length;
    }

    final List<(String, String)> filters = <(String, String)>[
      ('all', 'All'),

      ('today', 'Today'),

      ('upcoming', 'Upcoming'),

      ('completed', 'Completed'),

      ('cancelled', 'Cancelled'),
    ];

    return Container(
      width: double.infinity,

      color: Colors.white,

      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),

      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,

        child: Row(
          children: filters.map(((String, String) filter) {
            final bool selected = selectedFilter == filter.$1;

            return Padding(
              padding: const EdgeInsets.only(right: 10),

              child: ChoiceChip(
                selected: selected,

                onSelected: (_) => onChanged(filter.$1),

                selectedColor: AppColors.primary,

                labelStyle: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF153936),

                  fontWeight: FontWeight.w600,
                ),

                label: Text('${filter.$2} (${count(filter.$1)})'),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Doctor appointment ki patient aur schedule details show karega.

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.appointment,

    required this.isProcessing,

    required this.onStatusChanged,

    required this.onOpenConsultation,
  });

  final Map<String, dynamic> appointment;

  final bool isProcessing;

  final ValueChanged<String> onStatusChanged;

  final VoidCallback onOpenConsultation;

  @override
  Widget build(BuildContext context) {
    final String status = _appointmentStatus(appointment);

    final _StatusStyle statusStyle = _statusStyle(status);

    final String patientName = _patientName(appointment);

    final String clinicName = _clinicName(appointment);

    final DateTime? appointmentDate = _appointmentDate(appointment);

    final String time = _appointmentTime(appointment);

    final String symptoms =
        appointment['symptom_summary']?.toString().trim() ??
        appointment['symptoms_summary']?.toString().trim() ??
        '';

    final String mode =
        appointment['consultation_mode']?.toString() ?? 'in_person';

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
                  Icons.person_outline_rounded,

                  color: AppColors.primary,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  patientName,

                  maxLines: 1,

                  overflow: TextOverflow.ellipsis,

                  style: const TextStyle(
                    color: Color(0xFF153936),

                    fontSize: 18,

                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,

                  vertical: 6,
                ),

                decoration: BoxDecoration(
                  color: statusStyle.background,

                  borderRadius: BorderRadius.circular(20),
                ),

                child: Text(
                  statusStyle.label,

                  style: TextStyle(
                    color: statusStyle.foreground,

                    fontWeight: FontWeight.w700,

                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          _InfoRow(
            icon: Icons.calendar_month_outlined,

            text: appointmentDate == null
                ? 'Date unavailable'
                : _displayDate(appointmentDate),
          ),

          const SizedBox(height: 10),

          _InfoRow(
            icon: Icons.schedule_outlined,

            text: time.isEmpty ? 'Time unavailable' : time,
          ),

          const SizedBox(height: 10),

          _InfoRow(icon: Icons.local_hospital_outlined, text: clinicName),

          const SizedBox(height: 10),

          _InfoRow(
            icon: mode == 'video'
                ? Icons.videocam_outlined
                : Icons.medical_services_outlined,

            text: mode == 'video' ? 'Video Consultation' : 'Clinic Visit',
          ),

          const SizedBox(height: 16),

          Text(
            symptoms.isEmpty ? 'No symptoms provided.' : symptoms,

            maxLines: 2,

            overflow: TextOverflow.ellipsis,

            style: const TextStyle(color: Color(0xFF6B7E7C)),
          ),

          const Spacer(),

          Align(
            alignment: Alignment.centerRight,

            child: Text(
              'Token: ${appointment['token_number'] ?? '-'}',

              style: const TextStyle(
                color: AppColors.primary,

                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          const SizedBox(height: 14),

          _AppointmentActions(
            status: status,

            isProcessing: isProcessing,

            onStatusChanged: onStatusChanged,

            onOpenConsultation: onOpenConsultation,
          ),

          OnlineConsultationActions(appointment: appointment, isDoctor: true),
        ],
      ),
    );
  }
}

/// Current appointment status ke mutabiq valid doctor actions show karega.

class _AppointmentActions extends StatelessWidget {
  const _AppointmentActions({
    required this.status,

    required this.isProcessing,

    required this.onStatusChanged,

    required this.onOpenConsultation,
  });

  final String status;

  final bool isProcessing;

  final ValueChanged<String> onStatusChanged;

  final VoidCallback onOpenConsultation;

  @override
  Widget build(BuildContext context) {
    final List<(String, String, IconData)> actions;

    switch (status) {
      case 'booked':
        actions = <(String, String, IconData)>[
          ('checked_in', 'Check In', Icons.how_to_reg_outlined),

          ('no_show', 'No Show', Icons.person_off_outlined),
        ];

        break;

      case 'checked_in':
        actions = <(String, String, IconData)>[
          ('in_consultation', 'Start', Icons.play_circle_outline),

          ('no_show', 'No Show', Icons.person_off_outlined),
        ];

        break;

      case 'in_consultation':
        return SizedBox(
          width: double.infinity,

          child: FilledButton.icon(
            onPressed: isProcessing ? null : onOpenConsultation,

            icon: const Icon(Icons.medical_information_outlined),

            label: const Text('Consultation Notes'),
          ),
        );

      default:
        actions = <(String, String, IconData)>[];

        break;
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    if (isProcessing) {
      return const Center(
        child: SizedBox(
          width: 24,

          height: 24,

          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    return Row(
      children: actions.map(((String, String, IconData) action) {
        final bool primaryAction = action.$1 != 'no_show';

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: action == actions.last ? 0 : 8),

            child: primaryAction
                ? FilledButton.icon(
                    onPressed: () => onStatusChanged(action.$1),

                    icon: Icon(action.$3, size: 18),

                    label: Text(action.$2),
                  )
                : OutlinedButton.icon(
                    onPressed: () => onStatusChanged(action.$1),

                    icon: Icon(action.$3, size: 18),

                    label: Text(action.$2),
                  ),
          ),
        );
      }).toList(),
    );
  }
}

/// Appointment card ki reusable information row.

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF6B7E7C), size: 19),

        const SizedBox(width: 9),

        Expanded(
          child: Text(
            text,

            maxLines: 1,

            overflow: TextOverflow.ellipsis,

            style: const TextStyle(color: Color(0xFF6B7E7C)),
          ),
        ),
      ],
    );
  }
}

/// Empty filtered appointment state.

class _EmptyAppointments extends StatelessWidget {
  const _EmptyAppointments();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,

        children: [
          Icon(
            Icons.event_available_outlined,

            color: Color(0xFF8CA19E),

            size: 60,
          ),

          SizedBox(height: 14),

          Text(
            'No appointments found.',

            style: TextStyle(color: Color(0xFF6B7E7C), fontSize: 16),
          ),
        ],
      ),
    );
  }
}

/// Appointment API error aur retry button show karega.

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

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

              size: 56,
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

const List<(String, String)> _liveStatusChoices = <(String, String)>[
  ('available', 'Available Now'),
  ('consulting', 'Consulting Patients'),
  ('busy', 'Temporarily Busy'),
  ('operation', 'In Operation'),
  ('emergency', 'Handling Emergency'),
  ('break', 'On Break'),
  ('off_duty', 'Off Duty'),
  ('video_only', 'Video Consultation Only'),
];

/// Selected live status ka patient-facing default note.
String _defaultStatusNote(String status) {
  switch (status) {
    case 'available':
      return 'Doctor patients ke liye available hain.';
    case 'consulting':
      return 'Doctor patients check kar rahe hain.';
    case 'busy':
      return 'Doctor temporarily busy hain.';
    case 'operation':
      return 'Doctor operation mein hain.';
    case 'emergency':
      return 'Doctor emergency handle kar rahe hain.';
    case 'break':
      return 'Doctor break par hain.';
    case 'video_only':
      return 'Doctor sirf video consultation ke liye available hain.';
    default:
      return 'Doctor off duty hain.';
  }
}

/// Backend appointment status ko normalized lowercase value mein return karega.

String _appointmentStatus(Map<String, dynamic> appointment) {
  return appointment['status']?.toString().toLowerCase().trim() ?? 'booked';
}

/// Appointment ki date safe parse karega.

DateTime? _appointmentDate(Map<String, dynamic> appointment) {
  final String raw = appointment['appointment_date']?.toString() ?? '';

  return DateTime.tryParse(raw);
}

/// Appointment date aur time ko combined DateTime mein parse karega.

DateTime? _appointmentDateTime(Map<String, dynamic> appointment) {
  final String date = appointment['appointment_date']?.toString() ?? '';

  final String time = appointment['appointment_time']?.toString() ?? '00:00:00';

  return DateTime.tryParse('${date}T$time');
}

/// Backend time ko compact readable value mein return karega.

String _appointmentTime(Map<String, dynamic> appointment) {
  final String raw = appointment['appointment_time']?.toString() ?? '';

  return raw.length >= 5 ? raw.substring(0, 5) : raw;
}

/// Nested patient object se patient ka name return karega.

String _patientName(Map<String, dynamic> appointment) {
  final dynamic rawPatient = appointment['patient'];

  if (rawPatient is Map) {
    final Map<String, dynamic> patient = Map<String, dynamic>.from(rawPatient);

    final String fullName = patient['full_name']?.toString().trim() ?? '';

    if (fullName.isNotEmpty) return fullName;

    final String names = <String>[
      patient['first_name']?.toString().trim() ?? '',

      patient['last_name']?.toString().trim() ?? '',
    ].where((String value) => value.isNotEmpty).join(' ');

    if (names.isNotEmpty) return names;

    return patient['username']?.toString() ?? 'Patient';
  }

  return appointment['patient_name']?.toString() ?? 'Patient';
}

/// Nested doctor-clinic response se clinic name return karega.

String _clinicName(Map<String, dynamic> appointment) {
  final dynamic rawAssignment = appointment['doctor_clinic'];

  if (rawAssignment is Map) {
    final dynamic rawClinic = rawAssignment['clinic'];

    if (rawClinic is Map) {
      return rawClinic['name']?.toString() ?? 'Clinic';
    }

    return rawAssignment['clinic_name']?.toString() ?? 'Clinic';
  }

  return appointment['clinic_name']?.toString() ?? 'Clinic';
}

/// Date ko DD/MM/YYYY format mein show karega.

String _displayDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}

/// Appointment status label aur colors.

_StatusStyle _statusStyle(String status) {
  switch (status) {
    case 'completed':
      return const _StatusStyle(
        label: 'Completed',

        foreground: Color(0xFF15803D),

        background: Color(0xFFDCFCE7),
      );

    case 'cancelled':
      return const _StatusStyle(
        label: 'Cancelled',

        foreground: Color(0xFFDC2626),

        background: Color(0xFFFEE2E2),
      );

    case 'checked_in':
      return const _StatusStyle(
        label: 'Checked In',

        foreground: Color(0xFF2563EB),

        background: Color(0xFFDBEAFE),
      );

    case 'in_consultation':
      return const _StatusStyle(
        label: 'In Consultation',

        foreground: Color(0xFF7C3AED),

        background: Color(0xFFEDE9FE),
      );

    case 'no_show':
      return const _StatusStyle(
        label: 'No Show',

        foreground: Color(0xFF9F1239),

        background: Color(0xFFFFE4E6),
      );

    default:
      return const _StatusStyle(
        label: 'Booked',

        foreground: Color(0xFFD97706),

        background: Color(0xFFFEF3C7),
      );
  }
}

/// Backend status value ko confirmation dialog ka readable label banayega.

String _actionLabel(String status) {
  switch (status) {
    case 'checked_in':
      return 'Check In';

    case 'in_consultation':
      return 'Start Consultation';

    case 'completed':
      return 'Complete Appointment';

    case 'no_show':
      return 'Mark No Show';

    default:
      return 'Update Appointment';
  }
}

class _StatusStyle {
  const _StatusStyle({
    required this.label,

    required this.foreground,

    required this.background,
  });

  final String label;

  final Color foreground;

  final Color background;
}
