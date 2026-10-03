import 'package:flutter/material.dart';

import '../../services/doctor_records_service.dart';

/// Logged-in doctor ki tamam saved consultation reports dikhayega.
class DoctorConsultationsHistoryScreen extends StatefulWidget {
  const DoctorConsultationsHistoryScreen({super.key});

  @override
  State<DoctorConsultationsHistoryScreen> createState() =>
      _DoctorConsultationsHistoryScreenState();
}

class _DoctorConsultationsHistoryScreenState
    extends State<DoctorConsultationsHistoryScreen> {
  final DoctorRecordsService _service = DoctorRecordsService();
  final TextEditingController _searchController = TextEditingController();
  late Future<List<Map<String, dynamic>>> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _service.getConsultations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Backend se consultation history dobara load karega.
  Future<void> _refresh() async {
    final request = _service.getConsultations();
    setState(() => _future = request);
    await request;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F8F7),
      appBar: AppBar(
        title: const Text('Consultations History'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
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
            return _ErrorView(
              message: snapshot.error.toString().replaceFirst(
                'Exception: ',
                '',
              ),
              onRetry: _refresh,
            );
          }

          final records = (snapshot.data ?? <Map<String, dynamic>>[])
              .where(
                (record) => _searchText(record).contains(_query.toLowerCase()),
              )
              .toList();

          return Column(
            children: <Widget>[
              _SearchBox(
                controller: _searchController,
                query: _query,
                hint: 'Search patient or diagnosis...',
                onChanged: (value) => setState(() => _query = value.trim()),
                onClear: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
              ),
              Expanded(
                child: records.isEmpty
                    ? const _EmptyView(
                        icon: Icons.history_edu_outlined,
                        message: 'No consultation history found.',
                      )
                    : RefreshIndicator(
                        onRefresh: _refresh,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                          itemCount: records.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 14),
                          itemBuilder: (_, index) =>
                              _ConsultationCard(record: records[index]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _searchText(Map<String, dynamic> record) {
    final appointment = _map(
      record['appointment_details'] ?? record['appointment'],
    );
    return '${record['patient_name']} ${appointment['patient_name']} '
            '${record['diagnosis']} ${record['symptoms']}'
        .toLowerCase();
  }
}

class _ConsultationCard extends StatelessWidget {
  const _ConsultationCard({required this.record});
  final Map<String, dynamic> record;

  @override
  Widget build(BuildContext context) {
    final appointment = _map(
      record['appointment_details'] ?? record['appointment'],
    );
    final patientName = _first(<dynamic>[
      record['patient_name'],
      appointment['patient_name'],
      record['patient'],
    ], 'Patient');

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
                  backgroundColor: Color(0xFFD5F4F0),
                  child: Icon(
                    Icons.medical_information_outlined,
                    color: Color(0xFF087C72),
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
                      Text(_date(record['created_at'])),
                    ],
                  ),
                ),
                if (record['follow_up_required'] == true)
                  const Chip(label: Text('Follow-up')),
              ],
            ),
            const Divider(height: 28),
            _detail('Diagnosis', record['diagnosis'], required: true),
            _detail('Symptoms', record['symptoms']),
            _detail('Clinical notes', record['clinical_notes']),
            _detail('Recommended tests', record['recommended_tests']),
            _detail('Medical advice', record['medical_advice']),
            if (record['follow_up_required'] == true)
              _detail('Follow-up date', record['follow_up_date']),
          ],
        ),
      ),
    );
  }

  Widget _detail(String label, dynamic value, {bool required = false}) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty && !required) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: text.isEmpty ? 'Not provided' : text),
          ],
        ),
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.controller,
    required this.query,
    required this.hint,
    required this.onChanged,
    required this.onClear,
  });
  final TextEditingController controller;
  final String query;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(22),
    child: TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: query.isEmpty
            ? null
            : IconButton(onPressed: onClear, icon: const Icon(Icons.close)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    ),
  );
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 72, color: const Color(0xFF91A5A2)),
        const SizedBox(height: 12),
        Text(message, style: const TextStyle(fontSize: 18)),
      ],
    ),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(message, style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Try Again'),
        ),
      ],
    ),
  );
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

String _first(List<dynamic> values, String fallback) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty && text != '{}') return text;
  }
  return fallback;
}

String _date(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) return value?.toString() ?? '';
  return '${parsed.day.toString().padLeft(2, '0')}/'
      '${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
}
