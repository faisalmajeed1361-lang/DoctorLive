import 'package:flutter/material.dart';

import '../../config/app_theme.dart';

import '../../services/auth_service.dart';

import '../../services/payment_service.dart';

import '../auth/login_screen.dart';

/// Clinic staff aur superuser ke liye payment verification screen.

class AdminPaymentsScreen extends StatefulWidget {
  const AdminPaymentsScreen({this.embedded = false, super.key});

  /// When true, only the payment content is rendered so this screen can be
  /// placed safely inside AdminDashboardScreen without a nested Scaffold.
  final bool embedded;

  @override
  State<AdminPaymentsScreen> createState() {
    return _AdminPaymentsScreenState();
  }
}

class _AdminPaymentsScreenState extends State<AdminPaymentsScreen> {
  final PaymentService _paymentService = PaymentService();

  final AuthService _authService = AuthService();

  List<Map<String, dynamic>> _payments = <Map<String, dynamic>>[];

  String _selectedFilter = 'submitted';

  bool _isLoading = true;

  bool _isLoggingOut = false;

  int? _busyPaymentId;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _loadPayments();
  }

  /// Authorized clinic payments backend se load karega.

  Future<void> _loadPayments() async {
    if (_isLoggingOut) {
      return;
    }

    setState(() {
      _isLoading = true;

      _errorMessage = null;
    });

    try {
      final List<Map<String, dynamic>> payments = await _paymentService
          .getAdminPayments(status: _selectedFilter);

      if (!mounted) {
        return;
      }

      setState(() {
        _payments = payments;

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

  /// Logout confirmation dialog show karega.

  Future<void> _confirmLogout() async {
    if (_isLoggingOut) {
      return;
    }

    final bool shouldLogout =
        await showDialog<bool>(
          context: context,

          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Logout?'),

              content: const Text(
                'Kya aap admin account se logout karna chahte hain?',
              ),

              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(false);
                  },

                  child: const Text('Cancel'),
                ),

                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(true);
                  },

                  icon: const Icon(Icons.logout_rounded),

                  label: const Text('Logout'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldLogout || !mounted) {
      return;
    }

    await _logout();
  }

  /// Backend aur local device se login session remove karega.

  Future<void> _logout() async {
    if (_isLoggingOut) {
      return;
    }

    setState(() {
      _isLoggingOut = true;
    });

    await _authService.logout();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return const LoginScreen();
        },
      ),

      (Route<dynamic> route) => false,
    );
  }

  /// Windows/Android system Back ko secure logout banayega.

  void _handleSystemBack(bool didPop, dynamic result) {
    if (!didPop) {
      _confirmLogout();
    }
  }

  /// Dynamic ID ko safe integer mein convert karega.

  int? _paymentId(Map<String, dynamic> payment) {
    final dynamic value = payment['id'];

    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '');
  }

  /// Selected payment verify karega.

  Future<void> _verifyPayment(Map<String, dynamic> payment) async {
    final int? paymentId = _paymentId(payment);

    if (paymentId == null) {
      _showMessage('Payment ID available nahi hai.', isError: true);

      return;
    }

    setState(() {
      _busyPaymentId = paymentId;
    });

    try {
      await _paymentService.verifyPayment(paymentId: paymentId);

      if (!mounted) {
        return;
      }

      _showMessage('Payment successfully verified.');

      await _loadPayments();
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),

        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyPaymentId = null;
        });
      }
    }
  }

  /// Payment rejection reason dialog show karega.

  Future<void> _rejectPayment(Map<String, dynamic> payment) async {
    final int? paymentId = _paymentId(payment);

    if (paymentId == null) {
      _showMessage('Payment ID available nahi hai.', isError: true);

      return;
    }

    final TextEditingController controller = TextEditingController();

    final String? reason = await showDialog<String>(
      context: context,

      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Reject payment?'),

          content: TextField(
            controller: controller,

            autofocus: true,

            minLines: 2,

            maxLines: 4,

            decoration: const InputDecoration(
              labelText: 'Rejection reason',

              hintText: 'Example: Transaction ID invalid hai.',

              border: OutlineInputBorder(),
            ),
          ),

          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },

              child: const Text('Cancel'),
            ),

            FilledButton(
              onPressed: () {
                final String value = controller.text.trim();

                if (value.isEmpty) {
                  return;
                }

                Navigator.of(dialogContext).pop(value);
              },

              child: const Text('Reject Payment'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (reason == null || reason.trim().isEmpty || !mounted) {
      return;
    }

    setState(() {
      _busyPaymentId = paymentId;
    });

    try {
      await _paymentService.rejectPayment(paymentId: paymentId, reason: reason);

      if (!mounted) {
        return;
      }

      _showMessage('Payment rejected.');

      await _loadPayments();
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),

        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyPaymentId = null;
        });
      }
    }
  }

  /// Success ya error message show karega.

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),

          backgroundColor: isError ? AppColors.error : const Color(0xFF15803D),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = ColoredBox(
      color: const Color(0xFFF3F8F7),

      child: Column(
        children: <Widget>[
          _buildFilters(),

          Expanded(child: _buildBody()),
        ],
      ),
    );

    if (widget.embedded) {
      return content;
    }

    return PopScope(
      canPop: false,

      onPopInvokedWithResult: _handleSystemBack,

      child: Scaffold(
        backgroundColor: const Color(0xFFF3F8F7),

        appBar: AppBar(
          backgroundColor: Colors.white,

          surfaceTintColor: Colors.white,

          foregroundColor: const Color(0xFF153936),

          /// Back button secure logout confirmation show karega.
          leading: IconButton(
            tooltip: 'Back to Login',

            onPressed: _isLoggingOut ? null : _confirmLogout,

            icon: const Icon(Icons.arrow_back_rounded),
          ),

          title: const Text(
            'Payment Verification',

            style: TextStyle(fontWeight: FontWeight.w700),
          ),

          actions: <Widget>[
            /// Payments refresh button.
            IconButton(
              tooltip: 'Refresh',

              onPressed: _isLoading || _isLoggingOut ? null : _loadPayments,

              icon: const Icon(Icons.refresh_rounded),
            ),

            /// Admin logout button.
            IconButton(
              tooltip: 'Logout',

              onPressed: _isLoggingOut ? null : _confirmLogout,

              icon: _isLoggingOut
                  ? const SizedBox(
                      width: 21,

                      height: 21,

                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout_rounded),
            ),

            const SizedBox(width: 8),
          ],
        ),

        body: content,
      ),
    );
  }

  /// Payment status filter buttons.

  Widget _buildFilters() {
    const Map<String, String> filters = <String, String>{
      '': 'All',

      'submitted': 'Submitted',

      'pending': 'Cash Pending',

      'verified': 'Verified',

      'rejected': 'Rejected',
    };

    return Container(
      width: double.infinity,

      color: Colors.white,

      padding: const EdgeInsets.all(16),

      child: Wrap(
        spacing: 10,

        runSpacing: 10,

        children: filters.entries.map((MapEntry<String, String> entry) {
          return ChoiceChip(
            label: Text(entry.value),

            selected: _selectedFilter == entry.key,

            onSelected: (bool selected) {
              if (!selected || _isLoading || _isLoggingOut) {
                return;
              }

              setState(() {
                _selectedFilter = entry.key;
              });

              _loadPayments();
            },
          );
        }).toList(),
      ),
    );
  }

  /// Loading, error, empty aur payment list handle karega.

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),

          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: <Widget>[
              const Icon(
                Icons.error_outline_rounded,

                size: 55,

                color: AppColors.error,
              ),

              const SizedBox(height: 14),

              Text(_errorMessage!, textAlign: TextAlign.center),

              const SizedBox(height: 18),

              FilledButton.icon(
                onPressed: _loadPayments,

                icon: const Icon(Icons.refresh_rounded),

                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_payments.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: <Widget>[
            Icon(Icons.payments_outlined, size: 60, color: Color(0xFF91A7A4)),

            SizedBox(height: 14),

            Text(
              'No payments found.',

              style: TextStyle(color: Color(0xFF6B7E7C), fontSize: 17),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(20),

      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 560,

        mainAxisExtent: 385,

        crossAxisSpacing: 18,

        mainAxisSpacing: 18,
      ),

      itemCount: _payments.length,

      itemBuilder: (BuildContext context, int index) {
        return _buildPaymentCard(_payments[index]);
      },
    );
  }

  /// Single payment ki information card.

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final int? paymentId = _paymentId(payment);

    final String paymentStatus = payment['status']?.toString() ?? 'pending';

    final bool isBusy = paymentId != null && paymentId == _busyPaymentId;

    final bool canReview =
        paymentStatus == 'submitted' || paymentStatus == 'pending';

    final String rejectionReason =
        payment['rejection_reason']?.toString() ?? '';

    final String transactionReference =
        payment['transaction_reference']?.toString().trim() ?? '';

    return Card(
      margin: EdgeInsets.zero,

      elevation: 0,

      color: Colors.white,

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),

        side: const BorderSide(color: Color(0xFFDCE9E7)),
      ),

      child: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: <Widget>[
            Row(
              children: <Widget>[
                const CircleAvatar(
                  radius: 24,

                  backgroundColor: Color(0xFFDDF5F1),

                  child: Icon(
                    Icons.account_balance_wallet_outlined,

                    color: Color(0xFF087F73),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    payment['patient_name']?.toString() ?? 'Patient',

                    style: const TextStyle(
                      color: Color(0xFF153936),

                      fontSize: 19,

                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                _buildStatusBadge(
                  paymentStatus,

                  payment['status_display']?.toString() ?? paymentStatus,
                ),
              ],
            ),

            const Divider(height: 28),

            _detailRow(
              'Appointment',

              payment['appointment_reference']?.toString() ??
                  '#${payment['appointment'] ?? '-'}',
            ),

            _detailRow('Doctor', payment['doctor_name']?.toString() ?? '-'),

            _detailRow('Clinic', payment['clinic_name']?.toString() ?? '-'),

            _detailRow(
              'Method',

              payment['payment_method_display']?.toString() ??
                  payment['payment_method']?.toString() ??
                  '-',
            ),

            _detailRow('Amount', 'Rs. ${payment['amount'] ?? '0'}'),

            _detailRow(
              'Transaction ID',

              transactionReference.isNotEmpty
                  ? transactionReference
                  : 'Cash payment',
            ),

            if (rejectionReason.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),

                child: Text(
                  'Reason: $rejectionReason',

                  style: const TextStyle(
                    color: AppColors.error,

                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            const Spacer(),

            if (canReview)
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isBusy
                          ? null
                          : () {
                              _rejectPayment(payment);
                            },

                      icon: const Icon(Icons.close_rounded),

                      label: const Text('Reject'),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: FilledButton.icon(
                      onPressed: isBusy
                          ? null
                          : () {
                              _verifyPayment(payment);
                            },

                      icon: isBusy
                          ? const SizedBox(
                              width: 18,

                              height: 18,

                              child: CircularProgressIndicator(
                                strokeWidth: 2,

                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.verified_rounded),

                      label: Text(isBusy ? 'Please wait...' : 'Verify'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Payment card information row.

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: <Widget>[
          SizedBox(
            width: 115,

            child: Text(
              '$label:',

              style: const TextStyle(
                color: Color(0xFF6B7E7C),

                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          Expanded(
            child: Text(
              value,

              style: const TextStyle(color: Color(0xFF153936)),
            ),
          ),
        ],
      ),
    );
  }

  /// Payment status ka colored badge.

  Widget _buildStatusBadge(String status, String display) {
    Color backgroundColor;

    Color foregroundColor;

    switch (status) {
      case 'verified':
        backgroundColor = const Color(0xFFDCFCE7);

        foregroundColor = const Color(0xFF15803D);

        break;

      case 'rejected':
        backgroundColor = const Color(0xFFFEE2E2);

        foregroundColor = AppColors.error;

        break;

      case 'submitted':
        backgroundColor = const Color(0xFFDBEAFE);

        foregroundColor = const Color(0xFF2563EB);

        break;

      default:
        backgroundColor = const Color(0xFFFEF3C7);

        foregroundColor = const Color(0xFFD97706);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),

      decoration: BoxDecoration(
        color: backgroundColor,

        borderRadius: BorderRadius.circular(20),
      ),

      child: Text(
        display,

        style: TextStyle(
          color: foregroundColor,

          fontSize: 12,

          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
