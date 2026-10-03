import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:intl/intl.dart';

import 'package:pdf/pdf.dart';

import 'package:pdf/widgets.dart' as pw;

import 'package:printing/printing.dart';

/// Verified payment ki official DoctorLive receipt.

class PaymentReceiptScreen extends StatelessWidget {
  const PaymentReceiptScreen({required this.payment, super.key});

  final Map<String, dynamic> payment;

  static const Color darkTeal = Color(0xFF075E59);

  static const Color green = Color(0xFF149B5F);

  static const Color textColor = Color(0xFF153936);

  static const Color muted = Color(0xFF687D83);

  String _value(String key, {String fallback = '-'}) {
    final String value = payment[key]?.toString().trim() ?? '';

    return value.isEmpty ? fallback : value;
  }

  String get receiptId => _value('appointment_reference');

  String get patientName => _value('patient_name');

  String get doctorName => _value('doctor_name');

  String get clinicName => _value('clinic_name');

  String get method =>
      _value('payment_method_display', fallback: _value('payment_method'));

  String get amount => _value('amount', fallback: '0.00');

  String get transactionReference {
    return _value('transaction_reference', fallback: 'Cash payment');
  }

  String _formattedDate(String key, {bool includeTime = false}) {
    final String raw = _value(key, fallback: '');

    if (raw.isEmpty) return '-';

    final DateTime? date = DateTime.tryParse(raw)?.toLocal();

    if (date == null) return raw;

    return DateFormat(
      includeTime ? 'dd MMM yyyy, hh:mm a' : 'dd MMM yyyy',
    ).format(date);
  }

  String get appointmentDateTime {
    final String date = _formattedDate('appointment_date');

    final String rawTime = _value('appointment_time', fallback: '');

    if (rawTime.isEmpty) return date;

    final List<String> parts = rawTime.split(':');

    if (parts.length < 2) return '$date, $rawTime';

    final DateTime time = DateTime(
      2000,

      1,

      1,

      int.tryParse(parts[0]) ?? 0,

      int.tryParse(parts[1]) ?? 0,
    );

    return '$date, ${DateFormat('hh:mm a').format(time)}';
  }

  List<MapEntry<String, String>> get receiptRows => <MapEntry<String, String>>[
    MapEntry<String, String>('Receipt number', receiptId),

    MapEntry<String, String>('Patient name', patientName),

    MapEntry<String, String>('Doctor name', doctorName),

    MapEntry<String, String>('Clinic', clinicName),

    MapEntry<String, String>('Appointment date / time', appointmentDateTime),

    MapEntry<String, String>('Payment method', method),

    MapEntry<String, String>('Transaction reference', transactionReference),

    MapEntry<String, String>('Amount paid', 'Rs. $amount'),

    MapEntry<String, String>(
      'Verification date / time',

      _formattedDate('verified_at', includeTime: true),
    ),

    const MapEntry<String, String>('Payment status', 'Verified / Paid'),
  ];

  Future<Uint8List> _buildPdf(PdfPageFormat format) async {
    final ByteData logoData = await rootBundle.load(
      'assets/images/doctorlive_logo.png',
    );

    final pw.MemoryImage logo = pw.MemoryImage(logoData.buffer.asUint8List());

    final pw.Document document = pw.Document(
      title: 'DoctorLive Payment Receipt $receiptId',

      author: 'DoctorLive',
    );

    const PdfColor teal = PdfColor.fromInt(0xFF075E59);

    const PdfColor success = PdfColor.fromInt(0xFF149B5F);

    const PdfColor line = PdfColor.fromInt(0xFFD5E8E4);

    const PdfColor grey = PdfColor.fromInt(0xFF687D83);

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,

        margin: const pw.EdgeInsets.all(30),

        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,

          children: <pw.Widget>[
            pw.Center(child: pw.Image(logo, height: 70)),

            pw.SizedBox(height: 18),

            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 24),

              decoration: pw.BoxDecoration(
                color: teal,

                borderRadius: pw.BorderRadius.circular(14),
              ),

              child: pw.Column(
                children: <pw.Widget>[
                  pw.Text(
                    'PAYMENT RECEIPT',

                    style: pw.TextStyle(
                      color: PdfColors.white,

                      fontSize: 28,

                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),

                  pw.SizedBox(height: 5),

                  pw.Text(
                    'YOUR HEALTH, OUR PRIORITY',

                    style: const pw.TextStyle(
                      color: PdfColor.fromInt(0xFFD7E6E4),

                      fontSize: 11,

                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 18),

            pw.Container(
              padding: const pw.EdgeInsets.all(18),

              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: line),

                borderRadius: pw.BorderRadius.circular(14),
              ),

              child: pw.Column(
                children: receiptRows.map((MapEntry<String, String> row) {
                  final bool status = row.key == 'Payment status';

                  return pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 8),

                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(color: line)),
                    ),

                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,

                      children: <pw.Widget>[
                        pw.SizedBox(
                          width: 180,

                          child: pw.Text(
                            row.key.toUpperCase(),

                            style: pw.TextStyle(
                              color: grey,

                              fontSize: 9,

                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),

                        pw.Expanded(
                          child: pw.Text(
                            row.value,

                            style: pw.TextStyle(
                              color: status ? success : teal,

                              fontSize: 12,

                              fontWeight: status
                                  ? pw.FontWeight.bold
                                  : pw.FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            pw.SizedBox(height: 18),

            pw.Container(
              padding: const pw.EdgeInsets.all(16),

              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFEAF8F2),

                borderRadius: pw.BorderRadius.circular(12),
              ),

              child: pw.Text(
                'Payment verified hai. Aap appointment service use kar sakte hain.',

                style: const pw.TextStyle(color: success, fontSize: 12),
              ),
            ),

            pw.Spacer(),

            pw.Divider(color: line),

            pw.Center(
              child: pw.Text(
                'Thank you for choosing DoctorLive',

                style: pw.TextStyle(
                  color: teal,

                  fontSize: 14,

                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return document.save();
  }

  Future<void> _printReceipt(BuildContext context) async {
    try {
      await Printing.layoutPdf(
        name: 'DoctorLive_Receipt_$receiptId.pdf',

        onLayout: _buildPdf,
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Receipt print nahi ho saki: $error')),
      );
    }
  }

  Future<void> _shareReceipt(BuildContext context) async {
    try {
      final String fileName = 'DoctorLive_Receipt_$receiptId.pdf';
      final String? selectedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save DoctorLive payment receipt',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const <String>['pdf'],
      );

      if (selectedPath == null) return;

      final String outputPath = selectedPath.toLowerCase().endsWith('.pdf')
          ? selectedPath
          : '$selectedPath.pdf';
      final Uint8List pdfBytes = await _buildPdf(PdfPageFormat.a4);
      await File(outputPath).writeAsBytes(pdfBytes, flush: true);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Receipt saved successfully:\n$outputPath')),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Receipt save nahi ho saki: $error')),
      );
    }
  }

  IconData _rowIcon(String label) {
    switch (label) {
      case 'Receipt number':
        return Icons.receipt_long_outlined;
      case 'Patient name':
        return Icons.person_outline_rounded;
      case 'Doctor name':
        return Icons.medical_services_outlined;
      case 'Clinic':
        return Icons.local_hospital_outlined;
      case 'Appointment date / time':
        return Icons.calendar_month_outlined;
      case 'Payment method':
        return Icons.payments_outlined;
      case 'Transaction reference':
        return Icons.confirmation_number_outlined;
      case 'Amount paid':
        return Icons.account_balance_wallet_outlined;
      case 'Verification date / time':
        return Icons.verified_user_outlined;
      case 'Payment status':
        return Icons.check_circle_outline_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F9F8),

      appBar: AppBar(
        title: const Text('Payment Receipt'),

        actions: <Widget>[
          IconButton(
            tooltip: 'Print receipt',

            onPressed: () => _printReceipt(context),

            icon: const Icon(Icons.print_outlined),
          ),

          IconButton(
            tooltip: 'Save or share PDF',

            onPressed: () => _shareReceipt(context),

            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
        ],
      ),

      body: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          child: SizedBox(
            width: 1120,
            height: 760,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xFFF5FFFC), Color(0xFFE2FAF3)],
                ),
              ),
              child: Stack(
                children: <Widget>[
                  const Positioned(
                    left: -90,
                    top: -100,
                    child: _BackgroundCircle(size: 260),
                  ),
                  const Positioned(
                    right: -110,
                    bottom: -140,
                    child: _BackgroundCircle(size: 330),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(42, 18, 42, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Image.asset(
                          'assets/images/doctorlive_logo.png',
                          height: 64,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 10),
                        const _ReceiptHeader(),
                        const SizedBox(height: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(22, 14, 22, 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.97),
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(
                                color: const Color(0xFFCBE6E0),
                              ),
                              boxShadow: const <BoxShadow>[
                                BoxShadow(
                                  color: Color(0x18075E59),
                                  blurRadius: 22,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              children: <Widget>[
                                Expanded(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: <Widget>[
                                      Expanded(
                                        child: Column(
                                          children: receiptRows
                                              .take(5)
                                              .map(
                                                (
                                                  MapEntry<String, String> row,
                                                ) => Expanded(
                                                  child: _ReceiptRow(
                                                    icon: _rowIcon(row.key),
                                                    label: row.key,
                                                    value: row.value,
                                                    status: false,
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      ),
                                      const VerticalDivider(
                                        width: 26,
                                        thickness: 1,
                                        color: Color(0xFFD8EBE7),
                                      ),
                                      Expanded(
                                        child: Column(
                                          children: receiptRows
                                              .skip(5)
                                              .map(
                                                (
                                                  MapEntry<String, String> row,
                                                ) => Expanded(
                                                  child: _ReceiptRow(
                                                    icon: _rowIcon(row.key),
                                                    label: row.key,
                                                    value: row.value,
                                                    status:
                                                        row.key ==
                                                        'Payment status',
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const _VerifiedNotice(),
                                const SizedBox(height: 8),
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: () => _printReceipt(context),
                                        icon: const Icon(Icons.print_outlined),
                                        label: const Text('Print Receipt'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _shareReceipt(context),
                                        icon: const Icon(
                                          Icons.picture_as_pdf_outlined,
                                        ),
                                        label: const Text('Save PDF'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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

class _ReceiptHeader extends StatelessWidget {
  const _ReceiptHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 116,

      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 28),

      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF075E59), Color(0xFF08746B)],
        ),

        borderRadius: BorderRadius.circular(26),
      ),

      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0x26FFFFFF),
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: EdgeInsets.all(15),
              child: Icon(
                Icons.receipt_long_outlined,
                color: Colors.white,
                size: 45,
              ),
            ),
          ),
          SizedBox(width: 24),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'PAYMENT RECEIPT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'YOUR HEALTH, OUR PRIORITY',
                style: TextStyle(
                  color: Color(0xFFD7E6E4),
                  fontSize: 13,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.icon,

    required this.label,

    required this.value,

    required this.status,
  });

  final IconData icon;

  final String label;

  final String value;

  final bool status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),

      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE0ECEA))),
      ),

      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFFE0F7F0),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: PaymentReceiptScreen.darkTeal, size: 25),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PaymentReceiptScreen.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: status
                      ? const EdgeInsets.symmetric(horizontal: 12, vertical: 5)
                      : EdgeInsets.zero,
                  decoration: status
                      ? BoxDecoration(
                          color: const Color(0xFFC9F7DF),
                          borderRadius: BorderRadius.circular(18),
                        )
                      : null,
                  child: Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: status
                          ? const Color(0xFF08783F)
                          : PaymentReceiptScreen.textColor,
                      fontSize: status ? 15 : 14,
                      fontWeight: status ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VerifiedNotice extends StatelessWidget {
  const _VerifiedNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),

      decoration: BoxDecoration(
        color: const Color(0xFFEAF8F2),

        borderRadius: BorderRadius.circular(18),
      ),

      child: const Row(
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFFD0F5E4),
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: EdgeInsets.all(8),
              child: Icon(
                Icons.verified_user_outlined,
                color: PaymentReceiptScreen.green,
              ),
            ),
          ),

          SizedBox(width: 12),

          Expanded(
            child: Text(
              'Payment verified hai. Aap appointment service use kar sakte hain.',

              style: TextStyle(color: PaymentReceiptScreen.green, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundCircle extends StatelessWidget {
  const _BackgroundCircle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0x2279E2C4),
        shape: BoxShape.circle,
      ),
    );
  }
}
