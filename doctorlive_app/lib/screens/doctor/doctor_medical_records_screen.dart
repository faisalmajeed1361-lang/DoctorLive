import 'package:flutter/material.dart';

import '../../services/doctor_records_service.dart';

/// Doctor ko accessible patients ke uploaded medical documents dikhayega.
class DoctorMedicalRecordsScreen extends StatefulWidget {
  const DoctorMedicalRecordsScreen({super.key});

  @override
  State<DoctorMedicalRecordsScreen> createState() =>
      _DoctorMedicalRecordsScreenState();
}

class _DoctorMedicalRecordsScreenState
    extends State<DoctorMedicalRecordsScreen> {
  final DoctorRecordsService _service = DoctorRecordsService();
  final TextEditingController _searchController = TextEditingController();
  late Future<List<Map<String, dynamic>>> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _service.getMedicalDocuments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Patient medical documents refresh karega.
  Future<void> _refresh() async {
    final request = _service.getMedicalDocuments();
    setState(() => _future = request);
    await request;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F8F7),
      appBar: AppBar(
        title: const Text('Patient Medical Records'),
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
            return _DocumentMessage(
              icon: Icons.error_outline,
              message: snapshot.error.toString().replaceFirst(
                'Exception: ',
                '',
              ),
              onRetry: _refresh,
            );
          }
          final records = (snapshot.data ?? <Map<String, dynamic>>[]).where((
            item,
          ) {
            final text =
                '${item['title']} ${item['patient_name']} '
                        '${item['document_type_display']} ${item['notes']}'
                    .toLowerCase();
            return text.contains(_query.toLowerCase());
          }).toList();

          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(22),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search document or patient...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close),
                          ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: records.isEmpty
                    ? const _DocumentMessage(
                        icon: Icons.folder_open_outlined,
                        message: 'No patient medical documents found.',
                      )
                    : RefreshIndicator(
                        onRefresh: _refresh,
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 480,
                                mainAxisExtent: 225,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                          itemCount: records.length,
                          itemBuilder: (_, index) =>
                              _DocumentCard(data: records[index]),
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

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final title = data['title']?.toString().trim().isNotEmpty == true
        ? data['title'].toString()
        : 'Medical Document';
    final type =
        data['document_type_display'] ?? data['document_type'] ?? 'Document';
    final patient =
        data['patient_name'] ?? data['patient_username'] ?? 'Patient';

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
                  radius: 26,
                  backgroundColor: Color(0xFFD5F4F0),
                  child: Icon(
                    Icons.description_outlined,
                    color: Color(0xFF087C72),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(type.toString()),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            _row(Icons.person_outline, patient),
            _row(
              Icons.calendar_today_outlined,
              _documentDate(data['created_at']),
            ),
            _row(
              Icons.notes_outlined,
              data['notes']?.toString().trim().isNotEmpty == true
                  ? data['notes']
                  : 'No notes provided.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, dynamic value) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      children: <Widget>[
        Icon(icon, size: 18, color: const Color(0xFF087C72)),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            value?.toString() ?? '-',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

class _DocumentMessage extends StatelessWidget {
  const _DocumentMessage({
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

String _documentDate(dynamic value) {
  final date = DateTime.tryParse(value?.toString() ?? '');
  if (date == null) return value?.toString() ?? '-';
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}
