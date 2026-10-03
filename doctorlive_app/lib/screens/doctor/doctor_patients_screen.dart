import 'package:flutter/material.dart';

import '../../services/doctor_records_service.dart';

/// Logged-in doctor ke appointment patients ki unique list.
class DoctorPatientsScreen extends StatefulWidget {
  const DoctorPatientsScreen({super.key});

  @override
  State<DoctorPatientsScreen> createState() => _DoctorPatientsScreenState();
}

class _DoctorPatientsScreenState extends State<DoctorPatientsScreen> {
  final DoctorRecordsService _service = DoctorRecordsService();
  final TextEditingController _searchController = TextEditingController();
  late Future<List<Map<String, dynamic>>> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _service.getPatients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Backend appointments se patient list refresh karega.
  Future<void> _refresh() async {
    final Future<List<Map<String, dynamic>>> request = _service.getPatients();
    setState(() => _future = request);
    await request;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F8F7),
      appBar: AppBar(
        title: const Text('My Patients'),
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
            return _RecordError(
              message: snapshot.error.toString().replaceFirst(
                'Exception: ',
                '',
              ),
              onRetry: _refresh,
            );
          }

          final List<Map<String, dynamic>> patients =
              (snapshot.data ?? <Map<String, dynamic>>[]).where((patient) {
                final String haystack =
                    '${patient['name']} ${patient['email']} '
                            '${patient['phone_number']} ${patient['city']}'
                        .toLowerCase();
                return haystack.contains(_query.toLowerCase());
              }).toList();

          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(22),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search patient...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded),
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
                child: patients.isEmpty
                    ? const _RecordEmpty(
                        icon: Icons.people_outline_rounded,
                        message: 'No patients found.',
                      )
                    : RefreshIndicator(
                        onRefresh: _refresh,
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 460,
                                mainAxisExtent: 220,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                          itemCount: patients.length,
                          itemBuilder: (context, index) {
                            return _PatientCard(patient: patients[index]);
                          },
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

class _PatientCard extends StatelessWidget {
  const _PatientCard({required this.patient});

  final Map<String, dynamic> patient;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> latest = patient['latest_appointment'] is Map
        ? Map<String, dynamic>.from(patient['latest_appointment'])
        : <String, dynamic>{};
    final String name = patient['name']?.toString() ?? 'Patient';

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
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFFD5F4F0),
                  child: Text(
                    name.isEmpty ? 'P' : name[0].toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF087C72),
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF153936),
                        ),
                      ),
                      Text('${patient['appointment_count']} appointment(s)'),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            _line(Icons.location_city_outlined, patient['city']),
            _line(
              Icons.calendar_month_outlined,
              'Latest: ${latest['appointment_date'] ?? '-'}',
            ),
            _line(
              Icons.info_outline,
              latest['status_display'] ?? latest['status'],
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(IconData icon, dynamic text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: const Color(0xFF087C72)),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text?.toString().trim().isNotEmpty == true
                  ? text.toString()
                  : 'Not available',
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordEmpty extends StatelessWidget {
  const _RecordEmpty({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 70, color: const Color(0xFF91A5A2)),
          const SizedBox(height: 14),
          Text(message, style: const TextStyle(fontSize: 18)),
        ],
      ),
    );
  }
}

class _RecordError extends StatelessWidget {
  const _RecordError({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
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
}
