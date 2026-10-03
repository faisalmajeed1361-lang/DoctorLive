import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../services/appointment_service.dart';
import '../../services/live_doctor_status_service.dart';

/// Selected doctor ke sath appointment booking form.
class BookAppointmentScreen extends StatefulWidget {
  const BookAppointmentScreen({required this.doctor, super.key});

  final Map<String, dynamic> doctor;

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final AppointmentService _appointmentService = AppointmentService();

  final LiveDoctorStatusService _liveStatusService = LiveDoctorStatusService();

  final TextEditingController _symptomController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int? _selectedDoctorClinicId;

  String _consultationMode = 'in_person';
  bool _isSubmitting = false;
  bool _isLiveStatusLoading = false;
  Map<String, dynamic>? _liveStatus;
  String? _liveStatusError;

  List<Map<String, dynamic>> get _clinicAssignments {
    final dynamic assignments = widget.doctor['clinic_assignments'];

    if (assignments is! List) {
      return <Map<String, dynamic>>[];
    }

    return assignments
        .whereType<Map>()
        .map((Map item) => Map<String, dynamic>.from(item))
        .toList();
  }

  /// Currently selected doctor-clinic assignment return karega.
  Map<String, dynamic>? get _selectedAssignment {
    for (final Map<String, dynamic> assignment in _clinicAssignments) {
      if (_readInteger(assignment['id']) == _selectedDoctorClinicId) {
        return assignment;
      }
    }
    return null;
  }

  /// Doctor video consultation offer karta hai ya nahi.
  bool get _offersVideoConsultation {
    return widget.doctor['offers_video_consultation'] == true;
  }

  /// Doctor audio consultation offer karta hai ya nahi.
  bool get _offersAudioConsultation {
    return widget.doctor['offers_audio_consultation'] == true;
  }

  String get _doctorName {
    final String fullName = widget.doctor['full_name']?.toString().trim() ?? '';

    if (fullName.isNotEmpty) {
      return fullName;
    }

    return widget.doctor['name']?.toString() ?? 'Doctor';
  }

  @override
  void initState() {
    super.initState();

    // Pehli clinic assignment default select karega.
    if (_clinicAssignments.isNotEmpty) {
      _selectedDoctorClinicId = _readInteger(_clinicAssignments.first['id']);

      // Initial screen ke liye nested status immediately show hoga.
      final dynamic rawStatus = _clinicAssignments.first['live_status'];
      if (rawStatus is Map) {
        _liveStatus = Map<String, dynamic>.from(rawStatus);
      }

      // Backend se selected clinic ka latest status load karega.
      _refreshLiveStatus();
    }
  }

  @override
  void dispose() {
    _symptomController.dispose();
    _liveStatusService.dispose();
    super.dispose();
  }

  /// Selected doctor-clinic ka latest live status backend se load karega.
  Future<void> _refreshLiveStatus() async {
    final int? doctorClinicId = _selectedDoctorClinicId;
    if (doctorClinicId == null) return;

    if (mounted) {
      setState(() {
        _isLiveStatusLoading = true;
        _liveStatusError = null;
      });
    }

    try {
      final Map<String, dynamic> result = await _liveStatusService
          .getLiveStatus(doctorClinicId: doctorClinicId);

      if (!mounted || doctorClinicId != _selectedDoctorClinicId) return;

      setState(() {
        _liveStatus = result;
        _liveStatusError = null;
      });
    } catch (error) {
      if (!mounted || doctorClinicId != _selectedDoctorClinicId) return;

      setState(() {
        _liveStatusError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted && doctorClinicId == _selectedDoctorClinicId) {
        setState(() => _isLiveStatusLoading = false);
      }
    }
  }

  /// Dynamic value ko integer ID mein convert karega.
  int? _readInteger(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '');
  }

  /// Appointment date select karega.
  Future<void> _selectDate() async {
    final DateTime today = DateTime.now();

    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? today.add(const Duration(days: 1)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );

    if (date == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDate = date;
    });
  }

  /// Appointment time select karega.
  Future<void> _selectTime() async {
    final TimeOfDay initialTime =
        _selectedTime ??
        _assignmentStartTime() ??
        const TimeOfDay(hour: 10, minute: 0);

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (time == null || !mounted) {
      return;
    }

    setState(() {
      _selectedTime = time;
    });
  }

  /// Backend ke HH:MM:SS time ko Flutter TimeOfDay mein convert karega.
  TimeOfDay? _parseTime(dynamic value) {
    final String raw = value?.toString() ?? '';
    final List<String> parts = raw.split(':');

    if (parts.length < 2) return null;

    final int? hour = int.tryParse(parts[0]);
    final int? minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }

    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Selected clinic ka starting time return karega.
  TimeOfDay? _assignmentStartTime() {
    return _parseTime(_selectedAssignment?['start_time']);
  }

  /// Selected clinic ka ending time return karega.
  TimeOfDay? _assignmentEndTime() {
    return _parseTime(_selectedAssignment?['end_time']);
  }

  /// TimeOfDay ko minutes mein convert karke comparison easy banayega.
  int _minutes(TimeOfDay time) => time.hour * 60 + time.minute;

  /// Selected appointment clinic timing aur current time ke mutabiq validate karega.
  String? _validateAppointmentDateTime() {
    if (_selectedDate == null || _selectedTime == null) return null;

    final DateTime now = DateTime.now();
    final DateTime selected = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    if (!selected.isAfter(now)) {
      return 'Past date ya time par appointment book nahi ho sakti.';
    }

    final TimeOfDay? start = _assignmentStartTime();
    final TimeOfDay? end = _assignmentEndTime();

    if (start != null && _minutes(_selectedTime!) < _minutes(start)) {
      return 'Clinic ${start.format(context)} se open hoti hai.';
    }

    if (end != null && _minutes(_selectedTime!) > _minutes(end)) {
      return 'Clinic ${end.format(context)} tak available hai.';
    }

    return null;
  }

  /// Selected clinic ka readable schedule return karega.
  String _clinicSchedule(BuildContext context) {
    final TimeOfDay? start = _assignmentStartTime();
    final TimeOfDay? end = _assignmentEndTime();

    if (start == null || end == null) {
      return 'Clinic timing backend mein available nahi hai.';
    }

    return '${start.format(context)} - ${end.format(context)}';
  }

  /// TimeOfDay ko backend ke HH:MM:SS format mein convert karega.
  String _backendTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:00';
  }

  /// Selected date ko screen par readable format mein show karega.
  String _displayDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  /// Clinic assignment ka readable name return karega.
  String _clinicName(Map<String, dynamic> assignment) {
    final dynamic clinic = assignment['clinic'];

    if (clinic is Map<String, dynamic>) {
      return clinic['name']?.toString() ?? 'Clinic';
    }

    return assignment['clinic_name']?.toString() ??
        'Clinic assignment ${assignment['id']}';
  }

  String get _liveStatusCode {
    return _liveStatus?['status']?.toString().toLowerCase().trim() ?? 'unknown';
  }

  bool get _isLiveStatusStale {
    return _liveStatus?['is_status_stale'] == true ||
        _liveStatus?['is_stale'] == true;
  }

  int get _currentToken {
    return int.tryParse(_liveStatus?['current_token']?.toString() ?? '') ?? 0;
  }

  int get _averageConsultationMinutes {
    return int.tryParse(
          _selectedAssignment?['average_consultation_minutes']?.toString() ??
              '',
        ) ??
        0;
  }

  String get _statusNote {
    return (_liveStatus?['status_note'] ?? _liveStatus?['note'])
            ?.toString()
            .trim() ??
        '';
  }

  String get _statusUpdatedAt {
    final String raw = _liveStatus?['updated_at']?.toString().trim() ?? '';
    final DateTime? parsed = DateTime.tryParse(raw);

    if (parsed == null) return '';

    final DateTime local = parsed.toLocal();
    final String hour = local.hour.toString().padLeft(2, '0');
    final String minute = local.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  /// Form validate karke appointment backend mein submit karega.
  Future<void> _submitAppointment() async {
    if (_isSubmitting) {
      return;
    }

    final bool valid = _formKey.currentState?.validate() ?? false;

    if (!valid) {
      return;
    }

    if (_selectedDoctorClinicId == null) {
      _showMessage(
        'Doctor ki clinic assignment available nahi hai.',
        isError: true,
      );
      return;
    }

    if (_selectedDate == null) {
      _showMessage('Appointment date select karein.', isError: true);
      return;
    }

    if (_selectedTime == null) {
      _showMessage('Appointment time select karein.', isError: true);
      return;
    }

    final String? dateTimeError = _validateAppointmentDateTime();
    if (dateTimeError != null) {
      _showMessage(dateTimeError, isError: true);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Appointment backend mein submit karega.
      await _appointmentService.createAppointment(
        doctorClinicId: _selectedDoctorClinicId!,
        appointmentDate: _selectedDate!,
        appointmentTime: _backendTime(_selectedTime!),
        consultationMode: _consultationMode,
        symptomSummary: _symptomController.text,
      );

      if (!mounted) {
        return;
      }

      // Successful booking result previous screen ko return karega.
      // Pop se pehle loading state finish karne se layout error nahi aayega.
      setState(() {
        _isSubmitting = false;
      });

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      // Failed request ke baad submit button dobara enable karega.
      setState(() {
        _isSubmitting = false;
      });

      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  /// Success ya error message show karega.
  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasClinics = _clinicAssignments.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F8F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: const Color(0xFF153936),
        title: const Text(
          'Book Appointment',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFDCE9E7)),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DoctorHeader(doctorName: _doctorName),

                    const SizedBox(height: 28),

                    DropdownButtonFormField<int>(
                      initialValue: _selectedDoctorClinicId,
                      decoration: const InputDecoration(
                        labelText: 'Clinic',
                        prefixIcon: Icon(Icons.local_hospital_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: _clinicAssignments
                          .map((Map<String, dynamic> assignment) {
                            final int? id = _readInteger(assignment['id']);

                            if (id == null) {
                              return null;
                            }

                            return DropdownMenuItem<int>(
                              value: id,
                              child: Text(_clinicName(assignment)),
                            );
                          })
                          .whereType<DropdownMenuItem<int>>()
                          .toList(),
                      onChanged: hasClinics
                          ? (int? value) {
                              setState(() {
                                _selectedDoctorClinicId = value;
                                // Clinic change par purana time clear hoga.
                                _selectedTime = null;
                                _liveStatus = null;
                                _liveStatusError = null;
                              });

                              _refreshLiveStatus();
                            }
                          : null,
                      validator: (int? value) {
                        if (value == null) {
                          return 'Clinic select karein.';
                        }

                        return null;
                      },
                    ),

                    if (_selectedDoctorClinicId != null) ...[
                      const SizedBox(height: 12),
                      _ScheduleNotice(schedule: _clinicSchedule(context)),
                      const SizedBox(height: 12),
                      _LiveBookingStatusCard(
                        statusCode: _liveStatusCode,
                        currentToken: _currentToken,
                        averageMinutes: _averageConsultationMinutes,
                        statusNote: _statusNote,
                        updatedAt: _statusUpdatedAt,
                        isStale: _isLiveStatusStale,
                        isLoading: _isLiveStatusLoading,
                        errorMessage: _liveStatusError,
                        onRefresh: _refreshLiveStatus,
                      ),
                    ],

                    const SizedBox(height: 18),

                    LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                            final bool horizontal = constraints.maxWidth >= 560;

                            final Widget dateField = _SelectionField(
                              label: 'Appointment date',
                              value: _selectedDate == null
                                  ? 'Select date'
                                  : _displayDate(_selectedDate!),
                              icon: Icons.calendar_month_outlined,
                              onTap: _selectDate,
                            );

                            final Widget timeField = _SelectionField(
                              label: 'Appointment time',
                              value: _selectedTime == null
                                  ? 'Select time'
                                  : _selectedTime!.format(context),
                              icon: Icons.schedule_outlined,
                              onTap: _selectTime,
                            );

                            if (horizontal) {
                              return Row(
                                children: [
                                  Expanded(child: dateField),
                                  const SizedBox(width: 16),
                                  Expanded(child: timeField),
                                ],
                              );
                            }

                            return Column(
                              children: [
                                dateField,
                                const SizedBox(height: 16),
                                timeField,
                              ],
                            );
                          },
                    ),

                    const SizedBox(height: 18),

                    DropdownButtonFormField<String>(
                      initialValue: _consultationMode,
                      decoration: const InputDecoration(
                        labelText: 'Consultation mode',
                        prefixIcon: Icon(Icons.medical_services_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: <DropdownMenuItem<String>>[
                        const DropdownMenuItem<String>(
                          value: 'in_person',
                          child: Text('Clinic Visit'),
                        ),
                        if (_offersVideoConsultation)
                          const DropdownMenuItem<String>(
                            value: 'video',
                            child: Text('Video Consultation'),
                          ),
                        if (_offersAudioConsultation)
                          const DropdownMenuItem<String>(
                            value: 'audio',
                            child: Text('Audio Consultation'),
                          ),
                      ],
                      onChanged: (String? value) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          _consultationMode = value;
                        });
                      },
                    ),

                    const SizedBox(height: 18),

                    TextFormField(
                      controller: _symptomController,
                      maxLines: 4,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        labelText: 'Symptoms summary',
                        hintText: 'Apni problem aur symptoms briefly likhein.',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Symptoms summary zaroor likhein.';
                        }

                        if (value.trim().length < 5) {
                          return 'Symptoms ki thori detail likhein.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: hasClinics && !_isSubmitting
                            ? _submitAppointment
                            : null,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.calendar_month_rounded),
                        label: Text(
                          _isSubmitting ? 'Booking...' : 'Confirm Appointment',
                        ),
                      ),
                    ),

                    if (!hasClinics) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'Is doctor ki clinic assignment '
                        'available nahi hai.',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Selected doctor ki basic heading.
class _DoctorHeader extends StatelessWidget {
  const _DoctorHeader({required this.doctorName});

  final String doctorName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 30,
          backgroundColor: Color(0xFFD6F4EF),
          child: Icon(
            Icons.person_outline_rounded,
            color: AppColors.primary,
            size: 32,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Appointment with',
                style: TextStyle(color: Color(0xFF6B7E7C)),
              ),
              const SizedBox(height: 4),
              Text(
                doctorName,
                style: const TextStyle(
                  color: Color(0xFF153936),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Selected clinic ki real backend timing patient ko show karega.
class _ScheduleNotice extends StatelessWidget {
  const _ScheduleNotice({required this.schedule});

  final String schedule;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F7F4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time_rounded, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Available clinic timing: $schedule',
              style: const TextStyle(
                color: Color(0xFF153936),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Booking se pehle selected clinic ka current doctor status show karega.
class _LiveBookingStatusCard extends StatelessWidget {
  const _LiveBookingStatusCard({
    required this.statusCode,
    required this.currentToken,
    required this.averageMinutes,
    required this.statusNote,
    required this.updatedAt,
    required this.isStale,
    required this.isLoading,
    required this.errorMessage,
    required this.onRefresh,
  });

  final String statusCode;
  final int currentToken;
  final int averageMinutes;
  final String statusNote;
  final String updatedAt;
  final bool isStale;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (isLoading && statusCode == 'unknown') {
      return const LinearProgressIndicator(minHeight: 3);
    }

    if (errorMessage != null && statusCode == 'unknown') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                errorMessage!,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
            TextButton(onPressed: onRefresh, child: const Text('Retry')),
          ],
        ),
      );
    }

    final String label = _bookingStatusLabel(statusCode);
    final Color color = _bookingStatusColor(statusCode);
    final IconData icon = _bookingStatusIcon(statusCode);
    final bool hasWarning =
        isStale ||
        statusCode == 'busy' ||
        statusCode == 'operation' ||
        statusCode == 'emergency' ||
        statusCode == 'break' ||
        statusCode == 'off_duty';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasWarning
            ? const Color(0xFFFFF7ED)
            : color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasWarning
              ? const Color(0xFFFED7AA)
              : color.withValues(alpha: 0.30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isStale ? Icons.history_toggle_off_rounded : icon,
                color: isStale ? const Color(0xFFD97706) : color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isStale ? '$label (update required)' : label,
                  style: TextStyle(
                    color: isStale ? const Color(0xFFD97706) : color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh doctor status',
                onPressed: isLoading ? null : onRefresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          if (isLoading) const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _StatusDetail(
                icon: Icons.confirmation_number_outlined,
                text: 'Current token: $currentToken',
              ),
              if (averageMinutes > 0)
                _StatusDetail(
                  icon: Icons.timelapse_rounded,
                  text: 'Average: $averageMinutes min/patient',
                ),
              if (updatedAt.isNotEmpty)
                _StatusDetail(
                  icon: Icons.update_rounded,
                  text: 'Updated: $updatedAt',
                ),
            ],
          ),
          if (statusNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(statusNote, style: const TextStyle(color: Color(0xFF6B7E7C))),
          ],
          if (hasWarning) ...[
            const SizedBox(height: 8),
            const Text(
              'You can book a future appointment, but confirm the latest '
              'doctor availability before visiting the clinic.',
              style: TextStyle(
                color: Color(0xFFD97706),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusDetail extends StatelessWidget {
  const _StatusDetail({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: const Color(0xFF6B7E7C)),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(color: Color(0xFF6B7E7C), fontSize: 12),
        ),
      ],
    );
  }
}

String _bookingStatusLabel(String status) {
  switch (status) {
    case 'available':
      return 'Available Now';
    case 'consulting':
      return 'Consulting Patients';
    case 'busy':
      return 'Temporarily Busy';
    case 'operation':
      return 'In Operation';
    case 'emergency':
      return 'Handling Emergency';
    case 'break':
      return 'On Break';
    case 'off_duty':
      return 'Off Duty';
    case 'video_only':
      return 'Video Consultation Only';
    default:
      return 'Status Not Updated';
  }
}

Color _bookingStatusColor(String status) {
  switch (status) {
    case 'available':
      return const Color(0xFF16A34A);
    case 'consulting':
    case 'video_only':
      return const Color(0xFF2563EB);
    case 'busy':
    case 'break':
      return const Color(0xFFD97706);
    case 'operation':
    case 'emergency':
      return const Color(0xFFDC2626);
    case 'off_duty':
    default:
      return const Color(0xFF64748B);
  }
}

IconData _bookingStatusIcon(String status) {
  switch (status) {
    case 'available':
      return Icons.check_circle_rounded;
    case 'consulting':
      return Icons.medical_services_rounded;
    case 'video_only':
      return Icons.videocam_rounded;
    case 'busy':
      return Icons.schedule_rounded;
    case 'operation':
      return Icons.local_hospital_rounded;
    case 'emergency':
      return Icons.emergency_rounded;
    case 'break':
      return Icons.coffee_rounded;
    case 'off_duty':
    default:
      return Icons.offline_bolt_outlined;
  }
}

/// Date aur time selection ka reusable field.
class _SelectionField extends StatelessWidget {
  const _SelectionField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
        child: Text(value),
      ),
    );
  }
}
