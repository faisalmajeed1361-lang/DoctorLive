import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Creates the official DoctorLive prescription PDF from API data.
class PrescriptionPdfService {
  static const PdfColor _primary = PdfColor.fromInt(0xFF087C72);
  static const PdfColor _lightPrimary = PdfColor.fromInt(0xFFE4F6F3);
  static const PdfColor _textColor = PdfColor.fromInt(0xFF153936);

  /// Builds an A4 prescription that can be previewed, saved, or printed.
  Future<Uint8List> buildPrescription({
    required Map<String, dynamic> prescription,
    required Map<String, dynamic> patientProfile,
  }) async {
    final pw.Document document = pw.Document();
    final pw.MemoryImage? logo = await _loadLogo();
    // Embedded Open Sans fonts prevent broken glyphs and abnormal spacing.
    final pw.Font regularFont = await PdfGoogleFonts.openSansRegular();
    final pw.Font boldFont = await PdfGoogleFonts.openSansBold();
    final pw.Font italicFont = await PdfGoogleFonts.openSansItalic();
    final Map<String, dynamic> consultation = _map(
      prescription['consultation_details'],
    );
    final List<Map<String, dynamic>> medicines = _medicines(prescription);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(
          base: regularFont,
          bold: boldFont,
          italic: italicFont,
          fontFallback: <pw.Font>[regularFont],
        ),
        build: (pw.Context context) => <pw.Widget>[
          _header(logo),
          pw.SizedBox(height: 18),
          _sectionTitle('Patient Details'),
          _patientDetails(patientProfile, prescription),
          pw.SizedBox(height: 14),
          _sectionTitle('Doctor Details'),
          _doctorDetails(prescription),
          pw.SizedBox(height: 14),
          _sectionTitle('Diagnosis'),
          _textPanel(
            _value(<dynamic>[
              consultation['diagnosis'],
              prescription['diagnosis'],
            ], 'Not provided'),
          ),
          pw.SizedBox(height: 14),
          _medicineTable(medicines),
          pw.SizedBox(height: 14),
          _sectionTitle('Medical Advice / Follow-up'),
          _textPanel(
            _value(<dynamic>[
              consultation['medical_advice'],
              prescription['medical_advice'],
              prescription['additional_instructions'],
            ], 'No additional advice provided.'),
          ),
          pw.SizedBox(height: 14),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              pw.Expanded(
                child: _labelBox(
                  'Follow-up Date',
                  _value(<dynamic>[
                    consultation['follow_up_date'],
                    prescription['follow_up_date'],
                  ], 'Not required'),
                ),
              ),
              pw.SizedBox(width: 14),
              pw.Expanded(
                child: _labelBox(
                  'Doctor Signature & Stamp',
                  'Dr. ${_doctorName(prescription)}',
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 22),
          pw.Divider(color: _primary),
          pw.Center(
            child: pw.Text(
              'Generated securely by DoctorLive Healthcare Platform',
              style: const pw.TextStyle(color: _primary, fontSize: 9),
            ),
          ),
        ],
      ),
    );

    return document.save();
  }

  Future<pw.MemoryImage?> _loadLogo() async {
    try {
      final ByteData bytes = await rootBundle.load(
        'assets/images/doctorlive_logo.png',
      );
      return pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      // The PDF still works if the optional logo asset is unavailable.
      return null;
    }
  }

  pw.Widget _header(pw.MemoryImage? logo) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: <pw.Widget>[
        pw.Row(
          children: <pw.Widget>[
            if (logo != null) pw.Image(logo, width: 54, height: 54),
            if (logo != null) pw.SizedBox(width: 10),
            pw.Text(
              'DoctorLive',
              style: pw.TextStyle(
                color: _primary,
                fontSize: 28,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: pw.BoxDecoration(
            color: _lightPrimary,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Text(
            'PRESCRIPTION',
            style: pw.TextStyle(
              color: _textColor,
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _sectionTitle(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        color: _lightPrimary,
        borderRadius: const pw.BorderRadius.only(
          topLeft: pw.Radius.circular(7),
          topRight: pw.Radius.circular(7),
        ),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          color: _textColor,
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _patientDetails(
    Map<String, dynamic> profile,
    Map<String, dynamic> prescription,
  ) {
    final String fullName = _value(<dynamic>[
      prescription['patient_name'],
      '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'.trim(),
      profile['username'],
    ], 'Patient');
    final String id = _value(<dynamic>[
      prescription['patient_id'],
      profile['id'],
    ], '-');

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: _lightPrimary)),
      child: pw.Row(
        children: <pw.Widget>[
          pw.Expanded(child: _infoLine('Patient Name', fullName)),
          pw.SizedBox(width: 20),
          pw.Expanded(child: _infoLine('Patient ID', id)),
          pw.SizedBox(width: 20),
          pw.Expanded(child: _infoLine('Date', _issuedDate(prescription))),
        ],
      ),
    );
  }

  pw.Widget _doctorDetails(Map<String, dynamic> prescription) {
    final String doctor = _doctorName(prescription);
    final String qualification = _value(<dynamic>[
      prescription['doctor_qualification'],
      prescription['qualification'],
    ], 'Qualification not provided');
    final String clinic = _value(<dynamic>[
      prescription['clinic_name'],
    ], 'DoctorLive Healthcare');
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: _lightPrimary)),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Text(
                  'Dr. $doctor',
                  style: pw.TextStyle(
                    color: _textColor,
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(qualification),
              ],
            ),
          ),
          pw.SizedBox(width: 20),
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: <pw.Widget>[
                pw.Text(
                  'Hospital / Clinic',
                  style: pw.TextStyle(
                    color: _textColor,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(clinic, textAlign: pw.TextAlign.right),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _medicineTable(List<Map<String, dynamic>> medicines) {
    final List<List<String>> rows = medicines.isEmpty
        ? <List<String>>[
            <String>['No medicine added', '-', '-', '-'],
          ]
        : medicines
              .map(
                (medicine) => <String>[
                  _value(<dynamic>[medicine['medicine_name']], 'Medicine'),
                  _value(<dynamic>[medicine['dosage']], '-'),
                  _value(<dynamic>[medicine['frequency']], '-'),
                  _value(<dynamic>[medicine['duration']], '-'),
                ],
              )
              .toList();

    final List<List<String>> tableRows = <List<String>>[
      const <String>['Medicine', 'Dosage', 'Frequency', 'Duration'],
      ...rows,
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: _primary, width: 0.6),
      columnWidths: <int, pw.TableColumnWidth>{
        0: const pw.FlexColumnWidth(2.2),
        1: const pw.FlexColumnWidth(1.2),
        2: const pw.FlexColumnWidth(1.4),
        3: const pw.FlexColumnWidth(1.2),
      },
      children: tableRows.asMap().entries.map((entry) {
        final bool isHeader = entry.key == 0;
        return pw.TableRow(
          decoration: pw.BoxDecoration(
            color: isHeader ? _primary : PdfColors.white,
          ),
          children: entry.value.map((String value) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                value,
                style: pw.TextStyle(
                  color: isHeader ? PdfColors.white : _textColor,
                  fontSize: 10,
                  fontWeight: isHeader
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  pw.Widget _infoLine(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(value),
      ],
    );
  }

  pw.Widget _textPanel(String text) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: _lightPrimary)),
      child: pw.Text(text),
    );
  }

  pw.Widget _labelBox(String label, String value) {
    return pw.Container(
      height: 76,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _lightPrimary),
        borderRadius: pw.BorderRadius.circular(7),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(value),
        ],
      ),
    );
  }

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  List<Map<String, dynamic>> _medicines(Map<String, dynamic> prescription) {
    final dynamic value = prescription['medicines'];
    if (value is! List) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((Map item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String _doctorName(Map<String, dynamic> prescription) {
    return _value(<dynamic>[
      prescription['doctor_name'],
      prescription['prescribed_by_name'],
    ], 'Doctor');
  }

  String _issuedDate(Map<String, dynamic> prescription) {
    final dynamic raw = prescription['issued_at'] ?? prescription['created_at'];
    final DateTime? date = DateTime.tryParse(raw?.toString() ?? '');
    if (date == null) return raw?.toString() ?? '-';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _value(List<dynamic> values, String fallback) {
    for (final dynamic value in values) {
      final String text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text != 'null') return text;
    }
    return fallback;
  }
}
