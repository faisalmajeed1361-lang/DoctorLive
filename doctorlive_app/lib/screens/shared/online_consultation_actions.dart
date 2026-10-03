import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_theme.dart';
import '../../services/consultation_service.dart';

/// Video/audio appointment ka session status aur relevant actions show karta hai.
///
/// Doctor session create, join aur end kar sakta hai.
/// Patient doctor ka banaya hua session join kar sakta hai.
class OnlineConsultationActions extends StatefulWidget {
  const OnlineConsultationActions({
    required this.appointment,
    required this.isDoctor,
    super.key,
  });

  final Map<String, dynamic> appointment;
  final bool isDoctor;

  @override
  State<OnlineConsultationActions> createState() =>
      _OnlineConsultationActionsState();
}

class _OnlineConsultationActionsState extends State<OnlineConsultationActions> {
  final ConsultationService _service = ConsultationService();

  Map<String, dynamic>? _session;
  bool _loading = true;
  bool _processing = false;
  String? _error;

  int? get _appointmentId =>
      int.tryParse(widget.appointment['id']?.toString() ?? '');

  String get _mode =>
      widget.appointment['consultation_mode']
          ?.toString()
          .toLowerCase()
          .trim() ??
      'in_person';

  bool get _isOnline => _mode == 'video' || _mode == 'audio';

  @override
  void initState() {
    super.initState();
    if (_isOnline) {
      _loadSession();
    } else {
      _loading = false;
    }
  }

  Future<void> _loadSession() async {
    final int? appointmentId = _appointmentId;
    if (appointmentId == null) {
      setState(() {
        _loading = false;
        _error = 'Appointment ID is missing.';
      });
      return;
    }

    try {
      final Map<String, dynamic>? result = await _service
          .getSessionForAppointment(appointmentId);
      if (!mounted) return;
      setState(() {
        _session = result;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _cleanError(error);
      });
    }
  }

  Future<void> _createSession() async {
    final int? appointmentId = _appointmentId;
    if (appointmentId == null) return;

    await _runAction(() async {
      _session = await _service.createSession(
        appointmentId: appointmentId,
        sessionType: _mode,
      );
      _showMessage('${_titleCase(_mode)} session created successfully.');
    });
  }

  Future<void> _joinSession() async {
    final int? sessionId = int.tryParse(_session?['id']?.toString() ?? '');
    if (sessionId == null) {
      _showMessage('Session ID is missing.', isError: true);
      return;
    }

    await _runAction(() async {
      final Map<String, dynamic> response = await _service.joinSession(
        sessionId,
      );
      final dynamic updated = response['session'];
      if (updated is Map) {
        _session = Map<String, dynamic>.from(updated);
      }

      final String link = _session?['meeting_url']?.toString().trim() ?? '';
      if (link.isEmpty) {
        throw Exception('Meeting link is not available.');
      }

      final Uri uri = Uri.parse(link);
      final bool opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        throw Exception('Meeting link could not be opened.');
      }
    });
  }

  Future<void> _endSession() async {
    final int? sessionId = int.tryParse(_session?['id']?.toString() ?? '');
    if (sessionId == null) return;

    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('End consultation?'),
            content: const Text(
              'Both users will no longer be able to join this session.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Back'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('End Session'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;

    await _runAction(() async {
      final Map<String, dynamic> response = await _service.endSession(
        sessionId,
      );
      final dynamic updated = response['session'];
      if (updated is Map) {
        _session = Map<String, dynamic>.from(updated);
      }
      _showMessage('Consultation session ended.');
    });
  }

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() => _processing = true);
    try {
      await action();
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        _showMessage(_cleanError(error), isError: true);
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
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

  @override
  Widget build(BuildContext context) {
    if (!_isOnline) return const SizedBox.shrink();

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
            IconButton(
              tooltip: 'Retry',
              onPressed: _loadSession,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
      );
    }

    final String status =
        _session?['status']?.toString().toLowerCase() ?? 'not_created';
    final bool closed = status == 'ended' || status == 'cancelled';

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _mode == 'video'
                    ? Icons.videocam_outlined
                    : Icons.call_outlined,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_titleCase(_mode)} session',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              _SessionStatusBadge(status: status),
            ],
          ),
          const SizedBox(height: 10),
          if (_processing)
            const Center(child: CircularProgressIndicator())
          else if (_session == null && widget.isDoctor)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _createSession,
                icon: const Icon(Icons.add_link_rounded),
                label: const Text('Create Online Session'),
              ),
            )
          else if (_session == null)
            const Text(
              'Waiting for the doctor to create the online session.',
              style: TextStyle(color: Color(0xFF6B7E7C)),
            )
          else if (!closed)
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _joinSession,
                    icon: Icon(
                      _mode == 'video'
                          ? Icons.video_call_rounded
                          : Icons.call_rounded,
                    ),
                    label: const Text('Join Consultation'),
                  ),
                ),
                if (widget.isDoctor) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _endSession,
                    icon: const Icon(Icons.call_end_rounded),
                    label: const Text('End'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                  ),
                ],
              ],
            )
          else
            const Text(
              'This online consultation session is closed.',
              style: TextStyle(color: Color(0xFF6B7E7C)),
            ),
        ],
      ),
    );
  }
}

class _SessionStatusBadge extends StatelessWidget {
  const _SessionStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (status) {
      'active' => const Color(0xFF15803D),
      'waiting' => const Color(0xFFF59E0B),
      'ended' || 'cancelled' => AppColors.error,
      'scheduled' => const Color(0xFF2563EB),
      _ => const Color(0xFF64748B),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status == 'not_created' ? 'Not created' : _titleCase(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _titleCase(String value) {
  if (value.isEmpty) return value;
  final String normalized = value.replaceAll('_', ' ');
  return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
}

String _cleanError(Object error) {
  return error.toString().replaceFirst('Exception: ', '');
}
