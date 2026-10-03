import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../services/appointment_service.dart';
import '../../services/consultation_service.dart';

/// Doctor ko diagnosis, notes aur prescription save karne dega.
class DoctorConsultationScreen extends StatefulWidget {
  const DoctorConsultationScreen({required this.appointment, super.key});

  final Map<String, dynamic> appointment;

  @override
  State<DoctorConsultationScreen> createState() =>
      _DoctorConsultationScreenState();
}

class _DoctorConsultationScreenState extends State<DoctorConsultationScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ConsultationService _consultationService = ConsultationService();
  final AppointmentService _appointmentService = AppointmentService();

  final TextEditingController _diagnosisController = TextEditingController();
  final TextEditingController _symptomsController = TextEditingController();
  final TextEditingController _clinicalNotesController =
      TextEditingController();
  final TextEditingController _testsController = TextEditingController();
  final TextEditingController _adviceController = TextEditingController();
  final TextEditingController _additionalInstructionsController =
      TextEditingController();

  final List<_MedicineControllers> _medicines = <_MedicineControllers>[];
  bool _followUpRequired = false;
  DateTime? _followUpDate;
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _existingConsultation;

  int? get _appointmentId =>
      int.tryParse(widget.appointment['id']?.toString() ?? '');

  @override
  void initState() {
    super.initState();
    _symptomsController.text =
        widget.appointment['symptoms_summary']?.toString() ??
        widget.appointment['symptom_summary']?.toString() ??
        '';
    _medicines.add(_MedicineControllers());
    _loadExistingConsultation();
  }

  /// Existing report dobara create hone se rokega aur saved data show karega.
  Future<void> _loadExistingConsultation() async {
    final int? appointmentId = _appointmentId;

    if (appointmentId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final Map<String, dynamic>? consultation = await _consultationService
          .getConsultationForAppointment(appointmentId);

      if (!mounted) return;

      if (consultation != null) {
        _existingConsultation = consultation;
        _diagnosisController.text = consultation['diagnosis']?.toString() ?? '';
        _symptomsController.text = consultation['symptoms']?.toString() ?? '';
        _clinicalNotesController.text =
            consultation['clinical_notes']?.toString() ?? '';
        _testsController.text =
            consultation['recommended_tests']?.toString() ?? '';
        _adviceController.text =
            consultation['medical_advice']?.toString() ?? '';
        _followUpRequired = consultation['follow_up_required'] == true;
        _followUpDate = DateTime.tryParse(
          consultation['follow_up_date']?.toString() ?? '',
        );
        _loadPrescription(consultation['prescription']);
      }
    } catch (error) {
      if (mounted) _showMessage(_cleanError(error), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Saved prescription medicines form mein load karega.
  void _loadPrescription(dynamic rawPrescription) {
    if (rawPrescription is! Map) return;

    _additionalInstructionsController.text =
        rawPrescription['additional_instructions']?.toString() ?? '';
    final dynamic rawMedicines = rawPrescription['medicines'];

    if (rawMedicines is! List || rawMedicines.isEmpty) return;

    for (final _MedicineControllers medicine in _medicines) {
      medicine.dispose();
    }
    _medicines.clear();

    for (final dynamic rawMedicine in rawMedicines) {
      if (rawMedicine is Map) {
        _medicines.add(
          _MedicineControllers.fromMap(Map<String, dynamic>.from(rawMedicine)),
        );
      }
    }
  }

  /// Follow-up date picker open karega.
  Future<void> _selectFollowUpDate() async {
    final DateTime now = DateTime.now();
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: _followUpDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );

    if (selected != null && mounted) {
      setState(() => _followUpDate = selected);
    }
  }

  /// Consultation, optional prescription aur completed status sequence save karega.
  Future<void> _saveAndComplete() async {
    if (!_formKey.currentState!.validate()) return;

    if (_followUpRequired && _followUpDate == null) {
      _showMessage('Please select a follow-up date.', isError: true);
      return;
    }

    final int? appointmentId = _appointmentId;
    if (appointmentId == null) {
      _showMessage('Appointment ID is missing.', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      Map<String, dynamic> consultation =
          _existingConsultation ?? <String, dynamic>{};

      if (_existingConsultation == null) {
        consultation = await _consultationService.createConsultation(
          appointmentId: appointmentId,
          diagnosis: _diagnosisController.text,
          symptoms: _symptomsController.text,
          clinicalNotes: _clinicalNotesController.text,
          recommendedTests: _testsController.text,
          medicalAdvice: _adviceController.text,
          followUpRequired: _followUpRequired,
          followUpDate: _followUpDate,
        );
        _existingConsultation = consultation;
      }

      final int? consultationId = int.tryParse(
        consultation['id']?.toString() ?? '',
      );
      final bool prescriptionExists = consultation['prescription'] is Map;
      final List<Map<String, String>> medicines = _validMedicines();

      if (!prescriptionExists && medicines.isNotEmpty) {
        if (consultationId == null) {
          throw Exception('Consultation ID is missing.');
        }

        await _consultationService.createPrescription(
          consultationId: consultationId,
          additionalInstructions: _additionalInstructionsController.text,
          medicines: medicines,
        );
      }

      await _appointmentService.updateDoctorAppointmentStatus(
        appointmentId: appointmentId,
        newStatus: 'completed',
      );

      if (!mounted) return;
      _showMessage('Consultation and prescription saved successfully.');
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _showMessage(_cleanError(error), isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Sirf filled medicines ko API payload mein convert karega.
  List<Map<String, String>> _validMedicines() {
    return _medicines
        .where((_MedicineControllers medicine) => medicine.hasAnyValue)
        .map((_MedicineControllers medicine) => medicine.toMap())
        .toList();
  }

  void _addMedicine() {
    setState(() => _medicines.add(_MedicineControllers()));
  }

  void _removeMedicine(int index) {
    if (_medicines.length == 1) {
      _medicines.first.clear();
      setState(() {});
      return;
    }

    final _MedicineControllers removed = _medicines.removeAt(index);
    removed.dispose();
    setState(() {});
  }

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

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  @override
  void dispose() {
    _diagnosisController.dispose();
    _symptomsController.dispose();
    _clinicalNotesController.dispose();
    _testsController.dispose();
    _adviceController.dispose();
    _additionalInstructionsController.dispose();
    for (final _MedicineControllers medicine in _medicines) {
      medicine.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String patientName = _patientName(widget.appointment);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F8F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: const Color(0xFF153936),
        title: Text('Consultation - $patientName'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PatientHeader(
                          patientName: patientName,
                          token:
                              widget.appointment['token_number']?.toString() ??
                              '-',
                        ),
                        const SizedBox(height: 20),
                        LayoutBuilder(
                          builder:
                              (
                                BuildContext context,
                                BoxConstraints constraints,
                              ) {
                                final bool wide = constraints.maxWidth >= 850;
                                final Widget notes = _NotesSection(
                                  diagnosisController: _diagnosisController,
                                  symptomsController: _symptomsController,
                                  clinicalNotesController:
                                      _clinicalNotesController,
                                  testsController: _testsController,
                                  adviceController: _adviceController,
                                  followUpRequired: _followUpRequired,
                                  followUpDate: _followUpDate,
                                  readOnly: _existingConsultation != null,
                                  onFollowUpChanged: (bool value) {
                                    setState(() {
                                      _followUpRequired = value;
                                      if (!value) _followUpDate = null;
                                    });
                                  },
                                  onSelectDate: _selectFollowUpDate,
                                );
                                final Widget prescription =
                                    _PrescriptionSection(
                                      medicines: _medicines,
                                      additionalInstructionsController:
                                          _additionalInstructionsController,
                                      readOnly:
                                          _existingConsultation?['prescription']
                                              is Map,
                                      onAdd: _addMedicine,
                                      onRemove: _removeMedicine,
                                    );

                                if (!wide) {
                                  return Column(
                                    children: [
                                      notes,
                                      const SizedBox(height: 20),
                                      prescription,
                                    ],
                                  );
                                }

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: notes),
                                    const SizedBox(width: 20),
                                    Expanded(child: prescription),
                                  ],
                                );
                              },
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton.icon(
                            onPressed: _isSaving ? null : _saveAndComplete,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.task_alt_rounded),
                            label: Text(
                              _isSaving
                                  ? 'Saving...'
                                  : 'Save Consultation & Complete',
                            ),
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
}

class _PatientHeader extends StatelessWidget {
  const _PatientHeader({required this.patientName, required this.token});

  final String patientName;
  final String token;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration,
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: Color(0xFFD6F4EF),
            child: Icon(Icons.person_outline, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Patient',
                  style: TextStyle(color: Color(0xFF6B7E7C)),
                ),
                Text(
                  patientName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF153936),
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Token: $token',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesSection extends StatelessWidget {
  const _NotesSection({
    required this.diagnosisController,
    required this.symptomsController,
    required this.clinicalNotesController,
    required this.testsController,
    required this.adviceController,
    required this.followUpRequired,
    required this.followUpDate,
    required this.readOnly,
    required this.onFollowUpChanged,
    required this.onSelectDate,
  });

  final TextEditingController diagnosisController;
  final TextEditingController symptomsController;
  final TextEditingController clinicalNotesController;
  final TextEditingController testsController;
  final TextEditingController adviceController;
  final bool followUpRequired;
  final DateTime? followUpDate;
  final bool readOnly;
  final ValueChanged<bool> onFollowUpChanged;
  final VoidCallback onSelectDate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.medical_information_outlined,
            title: 'Clinical Notes',
          ),
          const SizedBox(height: 18),
          _field(
            controller: diagnosisController,
            label: 'Diagnosis *',
            readOnly: readOnly,
            validator: (String? value) => value == null || value.trim().isEmpty
                ? 'Diagnosis is required.'
                : null,
          ),
          _field(
            controller: symptomsController,
            label: 'Symptoms',
            readOnly: readOnly,
          ),
          _field(
            controller: clinicalNotesController,
            label: 'Clinical notes',
            readOnly: readOnly,
            lines: 3,
          ),
          _field(
            controller: testsController,
            label: 'Recommended tests',
            readOnly: readOnly,
          ),
          _field(
            controller: adviceController,
            label: 'Medical advice',
            readOnly: readOnly,
            lines: 3,
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: followUpRequired,
            onChanged: readOnly ? null : onFollowUpChanged,
            title: const Text('Follow-up required'),
          ),
          if (followUpRequired)
            OutlinedButton.icon(
              onPressed: readOnly ? null : onSelectDate,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(
                followUpDate == null
                    ? 'Select follow-up date'
                    : _dateLabel(followUpDate!),
              ),
            ),
        ],
      ),
    );
  }
}

class _PrescriptionSection extends StatelessWidget {
  const _PrescriptionSection({
    required this.medicines,
    required this.additionalInstructionsController,
    required this.readOnly,
    required this.onAdd,
    required this.onRemove,
  });

  final List<_MedicineControllers> medicines;
  final TextEditingController additionalInstructionsController;
  final bool readOnly;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: _SectionTitle(
                  icon: Icons.medication_outlined,
                  title: 'Prescription',
                ),
              ),
              if (!readOnly)
                IconButton(
                  tooltip: 'Add medicine',
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_circle, color: AppColors.primary),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...List<Widget>.generate(medicines.length, (int index) {
            final _MedicineControllers medicine = medicines[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAFA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFDCE9E7)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Medicine ${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (!readOnly)
                        IconButton(
                          tooltip: 'Remove medicine',
                          onPressed: () => onRemove(index),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppColors.error,
                          ),
                        ),
                    ],
                  ),
                  _field(
                    controller: medicine.name,
                    label: 'Medicine name',
                    readOnly: readOnly,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          controller: medicine.dosage,
                          label: 'Dosage',
                          readOnly: readOnly,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _field(
                          controller: medicine.frequency,
                          label: 'Frequency',
                          readOnly: readOnly,
                        ),
                      ),
                    ],
                  ),
                  _field(
                    controller: medicine.duration,
                    label: 'Duration',
                    readOnly: readOnly,
                  ),
                  _field(
                    controller: medicine.instructions,
                    label: 'Instructions',
                    readOnly: readOnly,
                  ),
                ],
              ),
            );
          }),
          _field(
            controller: additionalInstructionsController,
            label: 'Additional instructions',
            readOnly: readOnly,
            lines: 3,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(width: 9),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF153936),
          ),
        ),
      ],
    );
  }
}

Widget _field({
  required TextEditingController controller,
  required String label,
  required bool readOnly,
  int lines = 1,
  String? Function(String?)? validator,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      readOnly: readOnly,
      minLines: lines,
      maxLines: lines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        filled: readOnly,
        fillColor: readOnly ? const Color(0xFFF3F8F7) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}

class _MedicineControllers {
  _MedicineControllers();

  factory _MedicineControllers.fromMap(Map<String, dynamic> data) {
    final _MedicineControllers item = _MedicineControllers();
    item.name.text = data['medicine_name']?.toString() ?? '';
    item.dosage.text = data['dosage']?.toString() ?? '';
    item.frequency.text = data['frequency']?.toString() ?? '';
    item.duration.text = data['duration']?.toString() ?? '';
    item.instructions.text = data['instructions']?.toString() ?? '';
    return item;
  }

  final TextEditingController name = TextEditingController();
  final TextEditingController dosage = TextEditingController();
  final TextEditingController frequency = TextEditingController();
  final TextEditingController duration = TextEditingController();
  final TextEditingController instructions = TextEditingController();

  bool get hasAnyValue => <String>[
    name.text,
    dosage.text,
    frequency.text,
    duration.text,
    instructions.text,
  ].any((String value) => value.trim().isNotEmpty);

  Map<String, String> toMap() {
    return <String, String>{
      'medicine_name': name.text.trim(),
      'dosage': dosage.text.trim(),
      'frequency': frequency.text.trim(),
      'duration': duration.text.trim(),
      'instructions': instructions.text.trim(),
    };
  }

  void clear() {
    name.clear();
    dosage.clear();
    frequency.clear();
    duration.clear();
    instructions.clear();
  }

  void dispose() {
    name.dispose();
    dosage.dispose();
    frequency.dispose();
    duration.dispose();
    instructions.dispose();
  }
}

String _patientName(Map<String, dynamic> appointment) {
  final dynamic rawPatient = appointment['patient'];
  if (rawPatient is Map) {
    final String fullName = rawPatient['full_name']?.toString().trim() ?? '';
    if (fullName.isNotEmpty) return fullName;
    return rawPatient['username']?.toString() ?? 'Patient';
  }
  return appointment['patient_name']?.toString() ?? 'Patient';
}

String _dateLabel(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

final BoxDecoration _cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(20),
  border: Border.all(color: const Color(0xFFDCE9E7)),
);
