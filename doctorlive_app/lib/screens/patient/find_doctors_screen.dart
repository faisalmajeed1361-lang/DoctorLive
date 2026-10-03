import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../services/doctor_service.dart';
import 'book_appointment_screen.dart';

/// Patient ko city, hospital aur specialty ke through doctor search karne dega.
class FindDoctorsScreen extends StatefulWidget {
  const FindDoctorsScreen({super.key});

  @override
  State<FindDoctorsScreen> createState() => _FindDoctorsScreenState();
}

class _FindDoctorsScreenState extends State<FindDoctorsScreen> {
  final DoctorService _doctorService = DoctorService();

  late Future<_DoctorDirectoryData> _directoryFuture;

  String? _selectedCity;
  String? _selectedHospital;
  String? _selectedSpecialty;
  bool _availableOnly = false;

  @override
  void initState() {
    super.initState();

    // Doctors, clinics aur specialties ek sath load karega.
    _directoryFuture = _loadDirectory();
  }

  /// Selected filters ke sath complete doctor directory load karega.
  Future<_DoctorDirectoryData> _loadDirectory() async {
    final List<dynamic> results = await Future.wait<dynamic>([
      // Complete doctor list load hogi; selected filters screen par
      // apply honge taa-ke backend query format par dependency na rahe.
      _doctorService.getDoctors(),
      _doctorService.getClinics(),
      _doctorService.getSpecialties(),
    ]);

    return _DoctorDirectoryData.fromApi(
      doctors: results[0] as List<Map<String, dynamic>>,
      clinics: results[1] as List<Map<String, dynamic>>,
      specialties: results[2] as List<Map<String, dynamic>>,
    );
  }

  /// Backend se latest doctors dobara load karega.
  Future<void> _refreshDoctors() async {
    final Future<_DoctorDirectoryData> request = _loadDirectory();

    setState(() {
      _directoryFuture = request;
    });

    await request;
  }

  /// City change par dependent hospital filter reset karega.
  void _selectCity(String? value) {
    setState(() {
      _selectedCity = value;
      _selectedHospital = null;
      _directoryFuture = _loadDirectory();
    });
  }

  /// Tamam selected filters clear karega.
  void _clearFilters() {
    setState(() {
      _selectedCity = null;
      _selectedHospital = null;
      _selectedSpecialty = null;
      _availableOnly = false;
      _directoryFuture = _loadDirectory();
    });
  }

  /// Selected filters ke mutabiq doctor list client-side filter karega.
  List<Map<String, dynamic>> _filterDoctors(
    List<Map<String, dynamic>> doctors,
  ) {
    return doctors.where((Map<String, dynamic> doctor) {
      final String specialty = _specialtyName(doctor);
      final List<Map<String, dynamic>> assignments = _assignments(doctor);

      final bool specialtyMatches =
          _selectedSpecialty == null ||
          specialty.toLowerCase() == _selectedSpecialty!.toLowerCase();

      final bool assignmentMatches = assignments.any((
        Map<String, dynamic> assignment,
      ) {
        final Map<String, dynamic> clinic = _clinic(assignment);
        final String city = clinic['city']?.toString().trim() ?? '';
        final String hospital = clinic['name']?.toString().trim() ?? '';

        final bool cityMatches =
            _selectedCity == null ||
            city.toLowerCase() == _selectedCity!.toLowerCase();
        final bool hospitalMatches =
            _selectedHospital == null ||
            hospital.toLowerCase() == _selectedHospital!.toLowerCase();
        final bool availabilityMatches =
            !_availableOnly || _isAssignmentAvailable(assignment);

        return cityMatches && hospitalMatches && availabilityMatches;
      });

      // Assignment missing ho to sirf non-location filters apply honge.
      // Assignment na mile to backend-filtered doctor ko visible rakhega.
      final bool noAssignmentMatches = assignments.isEmpty;

      return specialtyMatches && (assignmentMatches || noAssignmentMatches);
    }).toList();
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
          'Find Doctors',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh doctors',
            onPressed: _refreshDoctors,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<_DoctorDirectoryData>(
        future: _directoryFuture,
        builder:
            (
              BuildContext context,
              AsyncSnapshot<_DoctorDirectoryData> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _DoctorError(
                  message: snapshot.error.toString().replaceFirst(
                    'Exception: ',
                    '',
                  ),
                  onRetry: _refreshDoctors,
                );
              }

              final _DoctorDirectoryData directory =
                  snapshot.data ??
                  const _DoctorDirectoryData(
                    doctors: <Map<String, dynamic>>[],
                    clinics: <Map<String, dynamic>>[],
                    specialties: <Map<String, dynamic>>[],
                  );
              final List<Map<String, dynamic>> allDoctors = directory.doctors;
              final List<Map<String, dynamic>> doctors = _filterDoctors(
                allDoctors,
              );

              return Column(
                children: [
                  _SearchFilters(
                    doctors: allDoctors,
                    clinics: directory.clinics,
                    specialtyRecords: directory.specialties,
                    selectedCity: _selectedCity,
                    selectedHospital: _selectedHospital,
                    selectedSpecialty: _selectedSpecialty,
                    availableOnly: _availableOnly,
                    onCityChanged: _selectCity,
                    onHospitalChanged: (String? value) {
                      setState(() {
                        _selectedHospital = value;
                      });
                    },
                    onSpecialtyChanged: (String? value) {
                      setState(() {
                        _selectedSpecialty = value;
                      });
                    },
                    onAvailabilityChanged: (bool value) {
                      setState(() {
                        _availableOnly = value;
                      });
                    },
                    onClear: _clearFilters,
                  ),
                  Expanded(
                    child: doctors.isEmpty
                        ? const _EmptyDoctors()
                        : RefreshIndicator(
                            onRefresh: _refreshDoctors,
                            child: _DoctorsGrid(
                              doctors: doctors,
                              selectedCity: _selectedCity,
                              selectedHospital: _selectedHospital,
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

/// City, hospital, specialty aur availability dropdown filters.
class _SearchFilters extends StatelessWidget {
  const _SearchFilters({
    required this.doctors,
    required this.clinics,
    required this.specialtyRecords,
    required this.selectedCity,
    required this.selectedHospital,
    required this.selectedSpecialty,
    required this.availableOnly,
    required this.onCityChanged,
    required this.onHospitalChanged,
    required this.onSpecialtyChanged,
    required this.onAvailabilityChanged,
    required this.onClear,
  });

  final List<Map<String, dynamic>> doctors;
  final List<Map<String, dynamic>> clinics;
  final List<Map<String, dynamic>> specialtyRecords;
  final String? selectedCity;
  final String? selectedHospital;
  final String? selectedSpecialty;
  final bool availableOnly;
  final ValueChanged<String?> onCityChanged;
  final ValueChanged<String?> onHospitalChanged;
  final ValueChanged<String?> onSpecialtyChanged;
  final ValueChanged<bool> onAvailabilityChanged;
  final VoidCallback onClear;

  List<String> get cities {
    final Set<String> values = <String>{};
    for (final Map<String, dynamic> clinic in clinics) {
      final String city = clinic['city']?.toString().trim() ?? '';
      if (city.isNotEmpty) values.add(city);
    }
    final List<String> result = values.toList()..sort();
    return result;
  }

  List<String> get hospitals {
    final Set<String> values = <String>{};
    for (final Map<String, dynamic> clinic in clinics) {
      final String city = clinic['city']?.toString().trim() ?? '';
      final String name = clinic['name']?.toString().trim() ?? '';
      final bool cityMatches =
          selectedCity == null ||
          city.toLowerCase() == selectedCity!.toLowerCase();
      if (cityMatches && name.isNotEmpty) values.add(name);
    }
    final List<String> result = values.toList()..sort();
    return result;
  }

  List<String> get specialties {
    final Set<String> values = specialtyRecords
        .map((Map<String, dynamic> item) {
          return item['name']?.toString().trim() ?? '';
        })
        .where((String value) => value.isNotEmpty)
        .toSet();

    // Specialty endpoint empty ho to doctor data fallback use karega.
    if (values.isEmpty) {
      values.addAll(
        doctors.map(_specialtyName).where((String value) => value.isNotEmpty),
      );
    }
    final List<String> result = values.toList()..sort();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool desktop = constraints.maxWidth >= 1000;

          final List<Widget> filters = [
            _FilterDropdown(
              label: 'City',
              hint: 'Select city',
              icon: Icons.location_on_outlined,
              value: selectedCity,
              options: cities,
              onChanged: onCityChanged,
            ),
            _FilterDropdown(
              label: 'Hospital / Clinic',
              hint: selectedCity == null
                  ? 'Select city first'
                  : 'Select hospital',
              icon: Icons.local_hospital_outlined,
              value: selectedHospital,
              options: hospitals,
              onChanged: selectedCity == null ? null : onHospitalChanged,
            ),
            _FilterDropdown(
              label: 'Specialty',
              hint: 'Select specialty',
              icon: Icons.medical_services_outlined,
              value: selectedSpecialty,
              options: specialties,
              onChanged: onSpecialtyChanged,
            ),
          ];

          final Widget availability = SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Available only'),
            value: availableOnly,
            activeThumbColor: AppColors.primary,
            onChanged: onAvailabilityChanged,
          );

          if (desktop) {
            return Row(
              children: [
                for (final Widget filter in filters) ...[
                  Expanded(child: filter),
                  const SizedBox(width: 12),
                ],
                SizedBox(width: 175, child: availability),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Clear'),
                ),
              ],
            );
          }

          return Column(
            children: [
              for (final Widget filter in filters) ...[
                filter,
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(child: availability),
                  OutlinedButton(
                    onPressed: onClear,
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Reusable dropdown filter field.
class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.hint,
    required this.icon,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final IconData icon;
  final String? value;
  final List<String> options;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      // Key dependent dropdown ko city change par properly reset karegi.
      key: ValueKey<String>('$label-$value-${options.length}'),
      initialValue: options.contains(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      hint: Text(hint),
      items: options
          .map(
            (String option) => DropdownMenuItem<String>(
              value: option,
              child: Text(option, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

/// Doctor cards ko responsive grid mein show karega.
class _DoctorsGrid extends StatelessWidget {
  const _DoctorsGrid({
    required this.doctors,
    required this.selectedCity,
    required this.selectedHospital,
  });

  final List<Map<String, dynamic>> doctors;
  final String? selectedCity;
  final String? selectedHospital;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 1200
            ? 3
            : constraints.maxWidth >= 750
            ? 2
            : 1;

        return GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          itemCount: doctors.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 18,
            mainAxisSpacing: 18,
            // Live status, queue and update information ke liye extra height.
            mainAxisExtent: 410,
          ),
          itemBuilder: (BuildContext context, int index) {
            return _DoctorCard(
              doctor: doctors[index],
              selectedCity: selectedCity,
              selectedHospital: selectedHospital,
            );
          },
        );
      },
    );
  }
}

/// Single doctor ki information aur booking button show karega.
class _DoctorCard extends StatelessWidget {
  const _DoctorCard({
    required this.doctor,
    required this.selectedCity,
    required this.selectedHospital,
  });

  final Map<String, dynamic> doctor;
  final String? selectedCity;
  final String? selectedHospital;

  @override
  Widget build(BuildContext context) {
    final String fullName = doctor['full_name']?.toString().trim() ?? '';
    final String displayName = fullName.isNotEmpty
        ? fullName
        : doctor['name']?.toString() ?? 'Doctor';
    final String specialty = _specialtyName(doctor);
    final List<Map<String, dynamic>> assignments = _assignments(doctor);
    final Map<String, dynamic> assignment = _selectedAssignment(
      assignments,
      selectedCity: selectedCity,
      selectedHospital: selectedHospital,
    );
    final Map<String, dynamic> clinic = _clinic(assignment);
    final String clinicName =
        clinic['name']?.toString() ?? 'Clinic not assigned';
    final String city = clinic['city']?.toString() ?? '';
    final String fee =
        doctor['consultation_fee']?.toString() ??
        assignment['consultation_fee']?.toString() ??
        '0';
    final Map<String, dynamic> liveStatus = _liveStatus(assignment);
    final String statusCode =
        liveStatus['status']?.toString().toLowerCase().trim() ?? 'unknown';
    final String statusLabel = _liveStatusLabel(statusCode);
    final Color statusColor = _liveStatusColor(statusCode);
    final IconData statusIcon = _liveStatusIcon(statusCode);
    final bool stale =
        liveStatus['is_status_stale'] == true || liveStatus['is_stale'] == true;
    final int currentToken =
        int.tryParse(liveStatus['current_token']?.toString() ?? '') ?? 0;
    final int averageMinutes =
        int.tryParse(
          assignment['average_consultation_minutes']?.toString() ?? '',
        ) ??
        0;
    final String statusNote =
        (liveStatus['status_note'] ?? liveStatus['note'])?.toString().trim() ??
        '';
    final String updatedAt = _formatStatusUpdate(
      liveStatus['updated_at']?.toString(),
    );

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
                radius: 30,
                backgroundColor: Color(0xFFD6F4EF),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.primary,
                  size: 32,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF153936),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      specialty,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _DoctorInfoRow(icon: Icons.local_hospital_outlined, text: clinicName),
          const SizedBox(height: 10),
          _DoctorInfoRow(
            icon: Icons.location_on_outlined,
            text: city.isEmpty ? 'Location not provided' : city,
          ),
          const SizedBox(height: 10),
          _DoctorInfoRow(
            icon: Icons.payments_outlined,
            text: 'Consultation fee: Rs. $fee',
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: stale
                  ? const Color(0xFFFFF7ED)
                  : statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: stale
                    ? const Color(0xFFFED7AA)
                    : statusColor.withValues(alpha: 0.30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      stale ? Icons.history_toggle_off_rounded : statusIcon,
                      color: stale ? const Color(0xFFD97706) : statusColor,
                      size: 19,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        stale ? '$statusLabel (update required)' : statusLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: stale ? const Color(0xFFD97706) : statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      'Token $currentToken',
                      style: const TextStyle(
                        color: Color(0xFF153936),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (statusNote.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    statusNote,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF6B7E7C),
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 7),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (averageMinutes > 0)
                      Text(
                        'Average: $averageMinutes min/patient',
                        style: const TextStyle(
                          color: Color(0xFF6B7E7C),
                          fontSize: 12,
                        ),
                      ),
                    if (updatedAt.isNotEmpty)
                      Text(
                        'Updated: $updatedAt',
                        style: const TextStyle(
                          color: Color(0xFF6B7E7C),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Icon(
                stale ? Icons.info_outline_rounded : statusIcon,
                color: stale ? const Color(0xFFD97706) : statusColor,
                size: 18,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  stale ? 'Confirm latest status' : statusLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: stale ? const Color(0xFFD97706) : statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Global button theme ki infinite width ko Row ke andar
              // bounded width dega aur desktop rendering crash rokega.
              SizedBox(
                width: 118,
                child: FilledButton(
                  onPressed: assignments.isEmpty
                      ? null
                      : () async {
                          // Selected doctor ka booking form open karega.
                          final bool? booked = await Navigator.of(context)
                              .push<bool>(
                                MaterialPageRoute<bool>(
                                  builder: (_) =>
                                      BookAppointmentScreen(doctor: doctor),
                                ),
                              );

                          if (booked == true && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Appointment successfully created.',
                                ),
                                backgroundColor: Color(0xFF15803D),
                              ),
                            );
                          }
                        },
                  child: const Text('Book Now'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Doctor card ki reusable information row.
class _DoctorInfoRow extends StatelessWidget {
  const _DoctorInfoRow({required this.icon, required this.text});

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

/// Empty doctor search result.
class _EmptyDoctors extends StatelessWidget {
  const _EmptyDoctors();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, color: Color(0xFF6B7E7C), size: 55),
          SizedBox(height: 14),
          Text(
            'No doctors found for selected filters.',
            style: TextStyle(color: Color(0xFF6B7E7C), fontSize: 16),
          ),
        ],
      ),
    );
  }
}

/// Doctor API failure state.
class _DoctorError extends StatelessWidget {
  const _DoctorError({required this.message, required this.onRetry});

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

/// Doctors, clinics aur specialties ko ek Future result mein rakhega.
class _DoctorDirectoryData {
  const _DoctorDirectoryData({
    required this.doctors,
    required this.clinics,
    required this.specialties,
  });

  final List<Map<String, dynamic>> doctors;
  final List<Map<String, dynamic>> clinics;
  final List<Map<String, dynamic>> specialties;

  /// Separate endpoints ke sath doctor ke nested clinic/specialty data ko
  /// merge karega. Is fallback se dropdowns empty nahi rahenge.
  factory _DoctorDirectoryData.fromApi({
    required List<Map<String, dynamic>> doctors,
    required List<Map<String, dynamic>> clinics,
    required List<Map<String, dynamic>> specialties,
  }) {
    final Map<String, Map<String, dynamic>> clinicById =
        <String, Map<String, dynamic>>{};
    final Map<String, Map<String, dynamic>> specialtyByName =
        <String, Map<String, dynamic>>{};

    void addClinic(Map<String, dynamic> clinic) {
      final String id = clinic['id']?.toString() ?? '';
      final String name = clinic['name']?.toString().trim() ?? '';
      final String key = id.isNotEmpty ? 'id:$id' : 'name:$name';
      if (name.isNotEmpty) clinicById[key] = clinic;
    }

    void addSpecialty(Map<String, dynamic> specialty) {
      final String name = specialty['name']?.toString().trim() ?? '';
      if (name.isNotEmpty) {
        specialtyByName[name.toLowerCase()] = specialty;
      }
    }

    for (final Map<String, dynamic> clinic in clinics) {
      addClinic(clinic);
    }
    for (final Map<String, dynamic> specialty in specialties) {
      addSpecialty(specialty);
    }

    for (final Map<String, dynamic> doctor in doctors) {
      for (final Map<String, dynamic> assignment in _assignments(doctor)) {
        final Map<String, dynamic> clinic = _clinic(assignment);
        if (clinic.isNotEmpty) addClinic(clinic);
      }

      final dynamic rawSpecialty = doctor['specialty'];
      if (rawSpecialty is Map) {
        addSpecialty(Map<String, dynamic>.from(rawSpecialty));
      } else {
        final String name = _specialtyName(doctor);
        if (name.isNotEmpty) {
          addSpecialty(<String, dynamic>{'name': name});
        }
      }
    }

    return _DoctorDirectoryData(
      doctors: doctors,
      clinics: clinicById.values.toList(),
      specialties: specialtyByName.values.toList(),
    );
  }
}

/// Doctor ki clinic assignments ko safe map list mein convert karega.
List<Map<String, dynamic>> _assignments(Map<String, dynamic> doctor) {
  final dynamic raw = doctor['clinic_assignments'];
  if (raw is! List) return <Map<String, dynamic>>[];

  return raw
      .whereType<Map>()
      .map((Map item) => Map<String, dynamic>.from(item))
      .toList();
}

/// Assignment ke nested clinic/hospital object ko safe map banayega.
Map<String, dynamic> _clinic(Map<String, dynamic> assignment) {
  final dynamic raw = assignment['clinic'];
  return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
}

/// Doctor ka specialty name nested ya direct API value se nikalega.
String _specialtyName(Map<String, dynamic> doctor) {
  final dynamic raw = doctor['specialty'];

  if (raw is Map) {
    return raw['name']?.toString().trim() ?? 'General Physician';
  }

  final String value = raw?.toString().trim() ?? '';
  return value.isEmpty ? 'General Physician' : value;
}

/// Selected city/hospital se match karne wali doctor-clinic assignment dega.
Map<String, dynamic> _selectedAssignment(
  List<Map<String, dynamic>> assignments, {
  required String? selectedCity,
  required String? selectedHospital,
}) {
  if (assignments.isEmpty) return <String, dynamic>{};

  for (final Map<String, dynamic> assignment in assignments) {
    final Map<String, dynamic> clinic = _clinic(assignment);
    final String city = clinic['city']?.toString().trim() ?? '';
    final String hospital = clinic['name']?.toString().trim() ?? '';

    final bool cityMatches =
        selectedCity == null ||
        city.toLowerCase() == selectedCity.toLowerCase();
    final bool hospitalMatches =
        selectedHospital == null ||
        hospital.toLowerCase() == selectedHospital.toLowerCase();

    if (cityMatches && hospitalMatches) return assignment;
  }

  return assignments.first;
}

/// Assignment ka nested live-status object safe map mein convert karega.
Map<String, dynamic> _liveStatus(Map<String, dynamic> assignment) {
  final dynamic rawStatus = assignment['live_status'];

  return rawStatus is Map
      ? Map<String, dynamic>.from(rawStatus)
      : <String, dynamic>{};
}

/// Backend live-status code ka patient-facing label.
String _liveStatusLabel(String status) {
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

/// Status ke mutabiq consistent UI color.
Color _liveStatusColor(String status) {
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

/// Status ke mutabiq icon.
IconData _liveStatusIcon(String status) {
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

/// ISO backend date ko compact local time mein show karega.
String _formatStatusUpdate(String? rawValue) {
  if (rawValue == null || rawValue.trim().isEmpty) return '';

  final DateTime? parsed = DateTime.tryParse(rawValue);
  if (parsed == null) return '';

  final DateTime local = parsed.toLocal();
  final String hour = local.hour.toString().padLeft(2, '0');
  final String minute = local.minute.toString().padLeft(2, '0');

  return '$hour:$minute';
}

/// Doctor assignment ke nested live status se availability check karega.
bool _isAssignmentAvailable(Map<String, dynamic> assignment) {
  if (assignment['is_available'] == true) return true;

  final Map<String, dynamic> liveStatus = _liveStatus(assignment);
  if (liveStatus.isEmpty) return false;

  final bool stale =
      liveStatus['is_status_stale'] == true || liveStatus['is_stale'] == true;

  if (stale) return false;

  final String status =
      liveStatus['status']?.toString().toLowerCase().trim() ?? '';

  return status == 'available' || status == 'consulting';
}
