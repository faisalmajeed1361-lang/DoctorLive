import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/doctor_records_service.dart';
import '../../services/prescription_pdf_service.dart';
import '../patient/prescription_preview_screen.dart';

/// Logged-in doctor ki issue ki hui prescriptions dikhayega.
class DoctorPrescriptionsScreen extends StatefulWidget {
  const DoctorPrescriptionsScreen({super.key});

  @override
  State<DoctorPrescriptionsScreen> createState() =>
      _DoctorPrescriptionsScreenState();
}

class _DoctorPrescriptionsScreenState extends State<DoctorPrescriptionsScreen> {
  final DoctorRecordsService _service = DoctorRecordsService();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getPrescriptions();
  }

  /// Prescription list refresh karega.
  Future<void> _refresh() async {
    final request = _service.getPrescriptions();
    setState(() => _future = request);
    await request;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F8F7),
      appBar: AppBar(
        title: const Text('Prescriptions'),
        actions: <Widget>[
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _PrescriptionMessage(
              icon: Icons.error_outline,
              message: snapshot.error.toString().replaceFirst(
                'Exception: ',
                '',
              ),
              onRetry: _refresh,
            );
          }
          final records = snapshot.data ?? <Map<String, dynamic>>[];
          if (records.isEmpty) {
            return const _PrescriptionMessage(
              icon: Icons.medication_outlined,
              message: 'No prescriptions found.',
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: GridView.builder(
              padding: const EdgeInsets.all(22),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 620,
                mainAxisExtent: 420,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: records.length,
              itemBuilder: (_, index) =>
                  _PrescriptionCard(data: records[index]),
            ),
          );
        },
      ),
    );
  }
}

class _PrescriptionCard extends StatelessWidget {
  const _PrescriptionCard({required this.data});
  final Map<String, dynamic> data;

  /// Creates the small patient map required by the shared PDF screen.
  Map<String, dynamic> _patientProfile(
    Map<String, dynamic> consultation,
    Map<String, dynamic> appointment,
    String patientName,
  ) {
    return <String, dynamic>{
      'id':
          data['patient_id'] ??
          consultation['patient_id'] ??
          appointment['patient_id'],
      'first_name': patientName,
      'last_name': '',
      'username': patientName,
    };
  }

  /// Opens the official digital prescription preview.
  void _openPdf(BuildContext context, Map<String, dynamic> patientProfile) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PrescriptionPreviewScreen(
          prescription: data,
          patientProfile: patientProfile,
        ),
      ),
    );
  }

  /// Builds the PDF and lets the doctor choose a Windows save location.
  Future<void> _downloadPdf(
    BuildContext context,
    Map<String, dynamic> patientProfile,
  ) async {
    try {
      final String id = data['id']?.toString() ?? 'record';
      final String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save DoctorLive prescription',
        fileName: 'DoctorLive_Prescription_$id.pdf',
        type: FileType.custom,
        allowedExtensions: <String>['pdf'],
      );

      // The user closed the save dialog without selecting a location.
      if (outputPath == null) return;

      final bytes = await PrescriptionPdfService().buildPrescription(
        prescription: data,
        patientProfile: patientProfile,
      );
      await File(outputPath).writeAsBytes(bytes, flush: true);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF saved successfully: $outputPath'),
          backgroundColor: const Color(0xFF087C72),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF could not be saved: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final consultation = _asMap(
      data['consultation_details'] ?? data['consultation'],
    );
    final appointment = _asMap(
      consultation['appointment_details'] ?? consultation['appointment'],
    );
    final patientName = _text(<dynamic>[
      data['patient_name'],
      consultation['patient_name'],
      appointment['patient_name'],
    ], 'Patient');
    final patientProfile = _patientProfile(
      consultation,
      appointment,
      patientName,
    );
    final medicines = data['medicines'] is List
        ? (data['medicines'] as List)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFD5E5E2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const CircleAvatar(
                  backgroundColor: Color(0xFFECE5FF),
                  child: Icon(
                    Icons.medication_outlined,
                    color: Color(0xFF7950F2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        patientName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text('Issued: ${_formatDate(data['issued_at'])}'),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 26),
            const Text(
              'Medicines',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: medicines.isEmpty
                  ? const Text('No medicines added.')
                  : ListView.separated(
                      itemCount: medicines.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (_, index) {
                        final medicine = medicines[index];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.medication_rounded,
                            color: Color(0xFF087C72),
                          ),
                          title: Text(
                            medicine['medicine_name']?.toString() ?? 'Medicine',
                          ),
                          subtitle: Text(
                            '${medicine['dosage'] ?? '-'} • '
                            '${medicine['frequency'] ?? '-'} • '
                            '${medicine['duration'] ?? '-'}\n'
                            '${medicine['instructions'] ?? ''}',
                          ),
                        );
                      },
                    ),
            ),
            if (data['additional_instructions']?.toString().trim().isNotEmpty ==
                true)
              Text('Instructions: ${data['additional_instructions']}'),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openPdf(context, patientProfile),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('View PDF'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _downloadPdf(context, patientProfile),
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Download PDF'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF087C72),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PrescriptionMessage extends StatelessWidget {
  const _PrescriptionMessage({
    required this.icon,
    required this.message,
    this.onRetry,
  });
  final IconData icon;
  final String message;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 72, color: const Color(0xFF91A5A2)),
        const SizedBox(height: 12),
        Text(message),
        if (onRetry != null) ...<Widget>[
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Try Again')),
        ],
      ],
    ),
  );
}

Map<String, dynamic> _asMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

String _text(List<dynamic> values, String fallback) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty && text != '{}') return text;
  }
  return fallback;
}

String _formatDate(dynamic value) {
  final date = DateTime.tryParse(value?.toString() ?? '');
  if (date == null) return value?.toString() ?? '-';
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}
