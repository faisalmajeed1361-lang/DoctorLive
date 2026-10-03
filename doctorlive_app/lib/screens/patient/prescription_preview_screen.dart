import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../services/prescription_pdf_service.dart';

/// Displays the official prescription and provides print/PDF actions.
class PrescriptionPreviewScreen extends StatelessWidget {
  PrescriptionPreviewScreen({
    required this.prescription,
    required this.patientProfile,
    super.key,
  });

  final Map<String, dynamic> prescription;
  final Map<String, dynamic> patientProfile;
  final PrescriptionPdfService _pdfService = PrescriptionPdfService();

  @override
  Widget build(BuildContext context) {
    final String id = prescription['id']?.toString() ?? 'record';

    return Scaffold(
      appBar: AppBar(title: const Text('Digital Prescription')),
      body: PdfPreview(
        pdfFileName: 'DoctorLive_Prescription_$id.pdf',
        canChangeOrientation: false,
        canChangePageFormat: false,
        allowPrinting: true,
        allowSharing: true,
        build: (_) => _pdfService.buildPrescription(
          prescription: prescription,
          patientProfile: patientProfile,
        ),
      ),
    );
  }
}
