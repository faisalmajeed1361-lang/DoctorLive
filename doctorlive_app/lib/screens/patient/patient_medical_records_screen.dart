import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../services/appointment_service.dart';
import '../../services/medical_records_service.dart';
import '../../services/profile_service.dart';
import 'prescription_preview_screen.dart';

/// Displays the patient's prescriptions and uploaded medical reports.
class PatientMedicalRecordsScreen extends StatefulWidget {
  const PatientMedicalRecordsScreen({super.key});

  @override
  State<PatientMedicalRecordsScreen> createState() =>
      _PatientMedicalRecordsScreenState();
}

class _PatientMedicalRecordsScreenState
    extends State<PatientMedicalRecordsScreen> {
  final MedicalRecordsService _service = MedicalRecordsService();
  final AppointmentService _appointmentService = AppointmentService();
  final ProfileService _profileService = ProfileService();

  List<Map<String, dynamic>> _prescriptions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _documents = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _appointments = <Map<String, dynamic>>[];
  Map<String, dynamic> _patientProfile = <String, dynamic>{};

  bool _isLoading = true;
  bool _isUploading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  /// Loads prescriptions, documents, appointments, and profile information.
  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<dynamic> results = await Future.wait<dynamic>([
        _service.getPrescriptions(),
        _service.getMedicalDocuments(),
        // Appointments are used by the upload dialog selector.
        _appointmentService.getAppointments(),
        // Patient identity will be printed on the digital prescription.
        _profileService.getProfile(),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _prescriptions = results[0] as List<Map<String, dynamic>>;
        _documents = results[1] as List<Map<String, dynamic>>;
        _appointments = results[2] as List<Map<String, dynamic>>;
        _patientProfile = results[3] as Map<String, dynamic>;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  /// Selects and uploads a supported medical document.
  Future<void> _uploadDocument() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.isEmpty || !mounted) return;

    final PlatformFile file = result.files.single;
    const int maximumBytes = 10 * 1024 * 1024;

    if (file.size > maximumBytes) {
      _showMessage('File size must not exceed 10 MB.', isError: true);
      return;
    }

    final _DocumentDetails? details = await showDialog<_DocumentDetails>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => _UploadDocumentDialog(
        initialTitle: file.name.split('.').first,
        appointments: _appointments,
      ),
    );

    if (details == null || !mounted) return;

    setState(() => _isUploading = true);

    try {
      await _service.uploadMedicalDocument(
        appointmentId: details.appointmentId,
        title: details.title,
        documentType: details.documentType,
        notes: details.notes,
        fileName: file.name,
        filePath: file.path,
        fileBytes: file.bytes,
      );

      if (!mounted) return;
      _showMessage('Medical document uploaded successfully.');
      await _loadRecords();
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  /// Upload result screen ke bottom par show karega.
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F8F7),
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          foregroundColor: const Color(0xFF153936),
          title: const Text(
            'Medical Records',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          actions: [
            IconButton(
              tooltip: 'Upload medical document',
              onPressed: _isLoading || _isUploading ? null : _uploadDocument,
              icon: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_rounded),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: _isLoading ? null : _loadRecords,
              icon: const Icon(Icons.refresh_rounded),
            ),
            const SizedBox(width: 8),
          ],
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: Color(0xFF6B7E7C),
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(icon: Icon(Icons.medication_outlined), text: 'Prescriptions'),
              Tab(icon: Icon(Icons.description_outlined), text: 'Documents'),
            ],
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _RecordsError(message: _errorMessage!, onRetry: _loadRecords);
    }

    return TabBarView(
      children: [
        _ResponsiveRecordsGrid(
          itemCount: _prescriptions.length,
          emptyIcon: Icons.medication_outlined,
          emptyMessage: 'No prescriptions found.',
          itemBuilder: (int index) => _PrescriptionCard(
            prescription: _prescriptions[index],
            patientProfile: _patientProfile,
          ),
        ),
        _ResponsiveRecordsGrid(
          itemCount: _documents.length,
          emptyIcon: Icons.folder_open_outlined,
          emptyMessage: 'No medical documents found.',
          itemBuilder: (int index) =>
              _DocumentCard(document: _documents[index]),
        ),
      ],
    );
  }
}

/// Upload dialog se return hone wali validated document information.
class _DocumentDetails {
  const _DocumentDetails({
    required this.appointmentId,
    required this.title,
    required this.documentType,
    required this.notes,
  });

  final int appointmentId;
  final String title;
  final String documentType;
  final String notes;
}

/// Medical document ka title, type aur notes collect karega.
class _UploadDocumentDialog extends StatefulWidget {
  const _UploadDocumentDialog({
    required this.initialTitle,
    required this.appointments,
  });

  final String initialTitle;
  final List<Map<String, dynamic>> appointments;

  @override
  State<_UploadDocumentDialog> createState() => _UploadDocumentDialogState();
}

class _UploadDocumentDialogState extends State<_UploadDocumentDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  final TextEditingController _notesController = TextEditingController();
  String _documentType = 'lab_report';
  int? _appointmentId;

  static const Map<String, String> _types = <String, String>{
    'lab_report': 'Lab Report',
    'xray': 'X-Ray',
    'scan': 'CT/MRI/Ultrasound Scan',
    'prescription': 'Previous Prescription',
    'discharge_summary': 'Discharge Summary',
    'other': 'Other Document',
  };

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);

    // List available ho to latest appointment default select karega.
    if (widget.appointments.isNotEmpty) {
      _appointmentId = _integerId(widget.appointments.first['id']);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.pop(
      context,
      _DocumentDetails(
        appointmentId: _appointmentId!,
        title: _titleController.text.trim(),
        documentType: _documentType,
        notes: _notesController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Upload Medical Document'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: _appointmentId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Related appointment',
                  prefixIcon: Icon(Icons.calendar_month_outlined),
                ),
                items: widget.appointments
                    .map((Map<String, dynamic> appointment) {
                      final int? id = _integerId(appointment['id']);
                      if (id == null) return null;

                      final String doctor =
                          appointment['doctor_name']?.toString() ?? 'Doctor';
                      final String date =
                          appointment['appointment_date']?.toString() ?? '-';
                      final String status =
                          appointment['status_display']?.toString() ??
                          appointment['status']?.toString() ??
                          '';

                      return DropdownMenuItem<int>(
                        value: id,
                        child: Text(
                          '$doctor • $date • $status',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    })
                    .whereType<DropdownMenuItem<int>>()
                    .toList(),
                onChanged: (int? value) {
                  setState(() => _appointmentId = value);
                },
                validator: (int? value) {
                  if (value == null) {
                    return 'Related appointment select karein.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Document title',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Document title is required.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _documentType,
                decoration: const InputDecoration(
                  labelText: 'Document type',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: _types.entries
                    .map(
                      (MapEntry<String, String> entry) =>
                          DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                    )
                    .toList(),
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() => _documentType = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                minLines: 3,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.upload_rounded),
          label: const Text('Upload'),
        ),
      ],
    );
  }
}

/// Desktop aur mobile ke mutabiq cards ka responsive layout banayega.
class _ResponsiveRecordsGrid extends StatelessWidget {
  const _ResponsiveRecordsGrid({
    required this.itemCount,
    required this.emptyIcon,
    required this.emptyMessage,
    required this.itemBuilder,
  });

  final int itemCount;
  final IconData emptyIcon;
  final String emptyMessage;
  final Widget Function(int index) itemBuilder;

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) {
      return _EmptyRecords(icon: emptyIcon, message: emptyMessage);
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 1200
            ? 3
            : constraints.maxWidth >= 760
            ? 2
            : 1;

        return GridView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: itemCount,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 18,
            mainAxisSpacing: 18,
            // Extra height keeps the medicine list and action button visible.
            mainAxisExtent: 320,
          ),
          itemBuilder: (BuildContext context, int index) {
            return itemBuilder(index);
          },
        );
      },
    );
  }
}

/// Displays one prescription and its medicines.
class _PrescriptionCard extends StatelessWidget {
  const _PrescriptionCard({
    required this.prescription,
    required this.patientProfile,
  });

  final Map<String, dynamic> prescription;
  final Map<String, dynamic> patientProfile;

  /// Opens the printable digital prescription screen.
  void _openPrescription(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => PrescriptionPreviewScreen(
          prescription: prescription,
          patientProfile: patientProfile,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dynamic rawMedicines = prescription['medicines'];
    final List<dynamic> medicines = rawMedicines is List
        ? rawMedicines
        : <dynamic>[];

    final String doctorName = _firstValue(prescription, <String>[
      'doctor_name',
      'prescribed_by_name',
    ], fallback: 'Doctor');

    final String date = _formatDate(
      // Prefer the prescription model's official issue timestamp.
      prescription['issued_at'] ??
          prescription['created_at'] ??
          prescription['date'],
    );

    return _RecordCard(
      icon: Icons.medication_outlined,
      title: doctorName,
      subtitle: date,
      onTap: () => _openPrescription(context),
      child: medicines.isEmpty
          ? Text(
              _firstValue(prescription, <String>[
                'notes',
                'instructions',
              ], fallback: 'No medicine details available.'),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF6B7E7C)),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: medicines.take(4).map((dynamic item) {
                final Map<String, dynamic> medicine = item is Map
                    ? Map<String, dynamic>.from(item)
                    : <String, dynamic>{};

                final String name = _firstValue(medicine, <String>[
                  'medicine_name',
                  'name',
                ], fallback: 'Medicine');
                final String dosage = _firstValue(medicine, <String>[
                  'dosage',
                  'dose',
                  'frequency',
                ], fallback: '');

                return Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.circle,
                        size: 7,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          dosage.isEmpty ? name : '$name — $dosage',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

/// Displays one uploaded medical report.
class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.document});

  final Map<String, dynamic> document;

  @override
  Widget build(BuildContext context) {
    final String title = _firstValue(document, <String>[
      'title',
      'document_name',
      'name',
    ], fallback: 'Medical Document');
    final String type = _firstValue(document, <String>[
      'document_type_display',
      'document_type',
      'file_type',
    ], fallback: 'Document');
    final String date = _formatDate(
      document['created_at'] ?? document['uploaded_at'],
    );
    final String notes = _firstValue(document, <String>[
      'description',
      'notes',
    ], fallback: 'No description provided.');

    return _RecordCard(
      icon: Icons.description_outlined,
      title: title,
      subtitle: '$type  •  $date',
      child: Text(
        notes,
        maxLines: 5,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Color(0xFF6B7E7C), height: 1.45),
      ),
    );
  }
}

/// Shared visual container for prescription and document cards.
class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFDCE9E7)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD6F4EF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: AppColors.primary),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
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
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFF6B7E7C)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 30),
              Expanded(child: child),
              if (onTap != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('View Prescription'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Friendly state for an empty prescription or document list.
class _EmptyRecords extends StatelessWidget {
  const _EmptyRecords({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 65, color: const Color(0xFF8CA09E)),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: Color(0xFF6B7E7C), fontSize: 17),
          ),
        ],
      ),
    );
  }
}

/// API load failure ko retry button ke sath show karega.
class _RecordsError extends StatelessWidget {
  const _RecordsError({required this.message, required this.onRetry});

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

/// Multiple possible API keys mein se pehli usable string return karega.
String _firstValue(
  Map<String, dynamic> data,
  List<String> keys, {
  required String fallback,
}) {
  for (final String key in keys) {
    final String value = data[key]?.toString().trim() ?? '';
    if (value.isNotEmpty && value != 'null') {
      return value;
    }
  }
  return fallback;
}

/// ISO datetime ko simple YYYY-MM-DD date mein convert karega.
String _formatDate(dynamic value) {
  final String text = value?.toString() ?? '';
  if (text.isEmpty) {
    return 'Date unavailable';
  }

  final DateTime? parsed = DateTime.tryParse(text);
  if (parsed == null) {
    return text;
  }

  final String month = parsed.month.toString().padLeft(2, '0');
  final String day = parsed.day.toString().padLeft(2, '0');
  return '${parsed.year}-$month-$day';
}

/// Dynamic API ID ko safe integer mein convert karega.
int? _integerId(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}
