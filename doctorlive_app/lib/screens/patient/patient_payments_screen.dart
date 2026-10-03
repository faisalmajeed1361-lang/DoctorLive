import 'package:file_picker/file_picker.dart';

import 'package:flutter/material.dart';

import '../../config/app_theme.dart';

import '../../services/appointment_service.dart';

import '../../services/payment_service.dart';

import 'payment_receipt_screen.dart';

/// Patient ki payment history aur new payment submission screen.

class PatientPaymentsScreen extends StatefulWidget {
  const PatientPaymentsScreen({super.key});

  @override
  State<PatientPaymentsScreen> createState() => _PatientPaymentsScreenState();
}

class _PatientPaymentsScreenState extends State<PatientPaymentsScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final PaymentService _paymentService = PaymentService();

  final AppointmentService _appointmentService = AppointmentService();

  final TextEditingController _referenceController = TextEditingController();

  /// Patient ki pehle submit ki hui payments.

  List<Map<String, dynamic>> _payments = <Map<String, dynamic>>[];

  /// Patient ki appointments.

  List<Map<String, dynamic>> _appointments = <Map<String, dynamic>>[];

  /// Selected appointment ke clinic ke payment accounts.

  List<Map<String, dynamic>> _paymentAccounts = <Map<String, dynamic>>[];

  int? _selectedAppointmentId;

  int? _selectedAccountId;

  String _paymentMethod = 'cash';

  String? _proofPath;

  String? _proofName;

  bool _isLoading = true;

  bool _isSubmitting = false;

  bool _areAccountsLoading = false;

  String? _loadError;

  @override
  void initState() {
    super.initState();

    _loadData();
  }

  @override
  void dispose() {
    _referenceController.dispose();

    super.dispose();
  }

  /// Patient ki payments aur appointments load karega.

  ///

  /// Payment accounts initial load par nahi aayenge.

  /// Patient jab appointment select karega tab selected clinic

  /// ke accounts load honge.

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;

      _loadError = null;
    });

    try {
      final List<dynamic> results = await Future.wait<dynamic>([
        _paymentService.getPayments(),

        _appointmentService.getAppointments(),
      ]);

      if (!mounted) return;

      setState(() {
        _payments = results[0] as List<Map<String, dynamic>>;

        _appointments = results[1] as List<Map<String, dynamic>>;

        _paymentAccounts = <Map<String, dynamic>>[];

        _selectedAppointmentId = null;

        _selectedAccountId = null;

        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loadError = error.toString().replaceFirst('Exception: ', '');

        _isLoading = false;
      });
    }
  }

  /// Selected appointment ke clinic ki ID find karega.

  ///

  /// Primary field clinic_id hai. Nested backend response ko bhi

  /// fallback ke taur par handle karta hai.

  int? _appointmentClinicId(Map<String, dynamic> appointment) {
    final int? directClinicId = _asInt(appointment['clinic_id']);

    if (directClinicId != null) {
      return directClinicId;
    }

    final dynamic doctorClinic = appointment['doctor_clinic'];

    if (doctorClinic is Map) {
      final int? nestedClinicId = _asInt(doctorClinic['clinic_id']);

      if (nestedClinicId != null) {
        return nestedClinicId;
      }

      final dynamic clinic = doctorClinic['clinic'];

      if (clinic is Map) {
        return _asInt(clinic['id']);
      }

      return _asInt(clinic);
    }

    return null;
  }

  /// Patient jab appointment select karega to us appointment

  /// ke clinic ke payment accounts load honge.

  Future<void> _selectAppointment(int? appointmentId) async {
    setState(() {
      _selectedAppointmentId = appointmentId;

      _selectedAccountId = null;

      _paymentAccounts = <Map<String, dynamic>>[];

      _areAccountsLoading = appointmentId != null;
    });

    if (appointmentId == null) {
      return;
    }

    Map<String, dynamic>? selectedAppointment;

    for (final Map<String, dynamic> appointment in _appointments) {
      if (_asInt(appointment['id']) == appointmentId) {
        selectedAppointment = appointment;

        break;
      }
    }

    if (selectedAppointment == null) {
      if (mounted) {
        setState(() {
          _areAccountsLoading = false;
        });
      }

      _showMessage('Selected appointment nahi mili.', true);

      return;
    }

    final int? clinicId = _appointmentClinicId(selectedAppointment);

    if (clinicId == null) {
      if (mounted) {
        setState(() {
          _areAccountsLoading = false;
        });
      }

      _showMessage('Appointment mein clinic ID available nahi hai.', true);

      return;
    }

    try {
      final List<Map<String, dynamic>> accounts = await _paymentService
          .getPaymentAccounts(clinicId: clinicId);

      if (!mounted) return;

      /// Agar API request complete hone se pehle patient ne koi

      /// doosri appointment select kar li ho to purane accounts

      /// apply nahi honge.

      if (_selectedAppointmentId != appointmentId) {
        return;
      }

      setState(() {
        _paymentAccounts = accounts;

        _selectedAccountId = null;

        _areAccountsLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _paymentAccounts = <Map<String, dynamic>>[];

        _selectedAccountId = null;

        _areAccountsLoading = false;
      });

      _showMessage(error.toString().replaceFirst('Exception: ', ''), true);
    }
  }

  /// Selected payment method ke accounts return karega.

  ///

  /// Example:

  /// JazzCash select ho to sirf JazzCash account show hoga.

  List<Map<String, dynamic>> get _filteredAccounts {
    if (_paymentMethod == 'cash') {
      return <Map<String, dynamic>>[];
    }

    return _paymentAccounts.where((Map<String, dynamic> account) {
      return account['account_type']?.toString().toLowerCase() ==
          _paymentMethod.toLowerCase();
    }).toList();
  }

  /// Jinki payment pehle create ho chuki hai un appointments

  /// ko payment form mein dobara show nahi karega.

  List<Map<String, dynamic>> get _unpaidAppointments {
    final Set<int> paidAppointmentIds = _payments
        .map((Map<String, dynamic> payment) => _asInt(payment['appointment']))
        .whereType<int>()
        .toSet();

    return _appointments.where((Map<String, dynamic> appointment) {
      final int? id = _asInt(appointment['id']);

      final String status =
          appointment['status']?.toString().toLowerCase() ?? '';

      return id != null &&
          !paidAppointmentIds.contains(id) &&
          status != 'cancelled' &&
          status != 'no_show';
    }).toList();
  }

  /// Payment receipt ki image select karega.

  ///

  /// Backend mein payment_proof ImageField hai is liye PDF

  /// allow nahi ki ja rahi.

  Future<void> _pickProof() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,

      allowedExtensions: <String>['jpg', 'jpeg', 'png'],
    );

    if (result == null || result.files.isEmpty || !mounted) {
      return;
    }

    final PlatformFile file = result.files.single;

    if (file.path == null) {
      _showMessage('Selected file path available nahi hai.', true);

      return;
    }

    setState(() {
      _proofPath = file.path;

      _proofName = file.name;
    });
  }

  /// Form validate karke payment backend par submit karega.

  Future<void> _submitPayment() async {
    if (_isSubmitting) {
      return;
    }

    final bool valid = _formKey.currentState?.validate() ?? false;

    if (!valid) {
      return;
    }

    if (_selectedAppointmentId == null) {
      _showMessage('Appointment select karein.', true);

      return;
    }

    final bool onlinePayment = _paymentMethod != 'cash';

    if (onlinePayment && _areAccountsLoading) {
      _showMessage('Payment accounts load ho rahe hain.', true);

      return;
    }

    if (onlinePayment && _selectedAccountId == null) {
      _showMessage('Receiving account select karein.', true);

      return;
    }

    if (onlinePayment && _referenceController.text.trim().isEmpty) {
      _showMessage('Transaction reference enter karein.', true);

      return;
    }

    if (onlinePayment && _proofPath == null) {
      _showMessage('Payment receipt/proof select karein.', true);

      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _paymentService.submitPayment(
        appointmentId: _selectedAppointmentId!,

        paymentMethod: _paymentMethod,

        paymentAccountId: onlinePayment ? _selectedAccountId : null,

        transactionReference: onlinePayment
            ? _referenceController.text.trim()
            : '',

        paymentProofPath: onlinePayment ? _proofPath : null,
      );

      if (!mounted) return;

      _showMessage(
        onlinePayment
            ? 'Payment verification ke liye submit ho gayi.'
            : 'Cash payment successfully create ho gayi.',

        false,
      );

      _resetForm();

      await _loadData();
    } catch (error) {
      if (!mounted) return;

      _showMessage(error.toString().replaceFirst('Exception: ', ''), true);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  /// Successful submission ke baad form clear karega.

  void _resetForm() {
    _formKey.currentState?.reset();

    _referenceController.clear();

    setState(() {
      _selectedAppointmentId = null;

      _selectedAccountId = null;

      _paymentMethod = 'cash';

      _paymentAccounts = <Map<String, dynamic>>[];

      _proofPath = null;

      _proofName = null;

      _areAccountsLoading = false;
    });
  }

  /// Dynamic API value ko integer mein convert karega.

  int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is Map) {
      return int.tryParse(value['id']?.toString() ?? '');
    }

    return int.tryParse(value?.toString() ?? '');
  }

  /// Success ya error snackbar show karega.

  void _showMessage(String message, bool isError) {
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
    return Scaffold(
      backgroundColor: const Color(0xFFF3F8F7),

      appBar: AppBar(
        backgroundColor: Colors.white,

        surfaceTintColor: Colors.white,

        foregroundColor: const Color(0xFF153936),

        title: const Text(
          'Payments',

          style: TextStyle(fontWeight: FontWeight.w700),
        ),

        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',

            onPressed: _isLoading ? null : _loadData,

            icon: const Icon(Icons.refresh_rounded),
          ),

          const SizedBox(width: 8),
        ],
      ),

      body: _buildBody(),
    );
  }

  /// Loading, error aur main screen handle karega.

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),

          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: <Widget>[
              const Icon(
                Icons.error_outline_rounded,

                color: AppColors.error,

                size: 55,
              ),

              const SizedBox(height: 14),

              Text(_loadError!, textAlign: TextAlign.center),

              const SizedBox(height: 18),

              FilledButton(
                onPressed: _loadData,

                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool desktop = constraints.maxWidth >= 1000;

        final Widget form = _PaymentForm(
          formKey: _formKey,

          appointments: _unpaidAppointments,

          accounts: _filteredAccounts,

          selectedAppointmentId: _selectedAppointmentId,

          selectedAccountId: _selectedAccountId,

          paymentMethod: _paymentMethod,

          referenceController: _referenceController,

          proofName: _proofName,

          isSubmitting: _isSubmitting,

          areAccountsLoading: _areAccountsLoading,

          asInt: _asInt,

          onAppointmentChanged: (int? value) {
            _selectAppointment(value);
          },

          onMethodChanged: (String value) {
            setState(() {
              _paymentMethod = value;

              _selectedAccountId = null;

              _proofPath = null;

              _proofName = null;

              _referenceController.clear();
            });
          },

          onAccountChanged: (int? value) {
            setState(() {
              _selectedAccountId = value;
            });
          },

          onPickProof: _pickProof,

          onSubmit: _submitPayment,
        );

        final Widget history = _PaymentHistory(payments: _payments);

        if (desktop) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),

            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: <Widget>[
                SizedBox(width: 500, child: form),

                const SizedBox(width: 24),

                Expanded(child: history),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(18),

          children: <Widget>[form, const SizedBox(height: 24), history],
        );
      },
    );
  }
}

/// New payment submission form.

class _PaymentForm extends StatelessWidget {
  const _PaymentForm({
    required this.formKey,

    required this.appointments,

    required this.accounts,

    required this.selectedAppointmentId,

    required this.selectedAccountId,

    required this.paymentMethod,

    required this.referenceController,

    required this.proofName,

    required this.isSubmitting,

    required this.areAccountsLoading,

    required this.asInt,

    required this.onAppointmentChanged,

    required this.onMethodChanged,

    required this.onAccountChanged,

    required this.onPickProof,

    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;

  final List<Map<String, dynamic>> appointments;

  final List<Map<String, dynamic>> accounts;

  final int? selectedAppointmentId;

  final int? selectedAccountId;

  final String paymentMethod;

  final TextEditingController referenceController;

  final String? proofName;

  final bool isSubmitting;

  final bool areAccountsLoading;

  final int? Function(dynamic) asInt;

  final ValueChanged<int?> onAppointmentChanged;

  final ValueChanged<String> onMethodChanged;

  final ValueChanged<int?> onAccountChanged;

  final VoidCallback onPickProof;

  final VoidCallback onSubmit;

  bool get onlinePayment => paymentMethod != 'cash';

  String get selectedMethodName {
    switch (paymentMethod) {
      case 'jazzcash':
        return 'JazzCash';

      case 'easypaisa':
        return 'Easypaisa';

      case 'bank_transfer':
        return 'Bank';

      default:
        return 'Payment';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(20),

        border: Border.all(color: const Color(0xFFDCE9E7)),
      ),

      child: Form(
        key: formKey,

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: <Widget>[
            const Text(
              'Submit Payment',

              style: TextStyle(
                color: Color(0xFF153936),

                fontSize: 21,

                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Appointment select karne ke baad us clinic ka receiving account show hoga.',

              style: TextStyle(color: Color(0xFF6B7E7C)),
            ),

            const SizedBox(height: 20),

            /// Appointment selection.
            DropdownButtonFormField<int>(
              initialValue: selectedAppointmentId,

              isExpanded: true,

              decoration: const InputDecoration(
                labelText: 'Appointment',

                prefixIcon: Icon(Icons.calendar_month_outlined),

                border: OutlineInputBorder(),
              ),

              items: appointments
                  .map((Map<String, dynamic> appointment) {
                    final int? id = asInt(appointment['id']);

                    if (id == null) {
                      return null;
                    }

                    final String reference =
                        appointment['appointment_reference']?.toString() ??
                        'DL-APT-${id.toString().padLeft(6, '0')}';

                    final String doctor =
                        appointment['doctor_name']?.toString() ?? 'Doctor';

                    final String token =
                        appointment['token_number']?.toString() ?? '-';

                    final String date =
                        appointment['appointment_date']?.toString() ?? '-';

                    final String time =
                        appointment['appointment_time']?.toString() ?? '-';

                    return DropdownMenuItem<int>(
                      value: id,

                      child: Text(
                        '$reference • Token $token • $doctor • $date $time',

                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  })
                  .whereType<DropdownMenuItem<int>>()
                  .toList(),

              onChanged: onAppointmentChanged,

              validator: (int? value) {
                if (value == null) {
                  return 'Appointment select karein.';
                }

                return null;
              },
            ),

            if (appointments.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),

                child: Text(
                  'Payment ke liye koi unpaid appointment available nahi hai.',

                  style: TextStyle(color: Color(0xFF6B7E7C), fontSize: 12),
                ),
              ),

            const SizedBox(height: 16),

            /// Payment method selection.
            DropdownButtonFormField<String>(
              initialValue: paymentMethod,

              isExpanded: true,

              decoration: const InputDecoration(
                labelText: 'Payment method',

                prefixIcon: Icon(Icons.payments_outlined),

                border: OutlineInputBorder(),
              ),

              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                  value: 'cash',

                  child: Text('Cash at Clinic'),
                ),

                DropdownMenuItem<String>(
                  value: 'bank_transfer',

                  child: Text('Bank Transfer'),
                ),

                DropdownMenuItem<String>(
                  value: 'jazzcash',

                  child: Text('JazzCash'),
                ),

                DropdownMenuItem<String>(
                  value: 'easypaisa',

                  child: Text('Easypaisa'),
                ),
              ],

              onChanged: (String? value) {
                if (value != null) {
                  onMethodChanged(value);
                }
              },
            ),

            /// Cash payment information.
            if (!onlinePayment) ...<Widget>[
              const SizedBox(height: 16),

              Container(
                width: double.infinity,

                padding: const EdgeInsets.all(14),

                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7E6),

                  borderRadius: BorderRadius.circular(12),

                  border: Border.all(color: const Color(0xFFF5D89A)),
                ),

                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: <Widget>[
                    Icon(Icons.info_outline, color: Color(0xFFD97706)),

                    SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        'Cash payment clinic par pay hogi. Staff payment receive karke verify karega.',

                        style: TextStyle(color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            /// Digital payment fields.
            if (onlinePayment) ...<Widget>[
              const SizedBox(height: 16),

              if (selectedAppointmentId == null)
                Container(
                  width: double.infinity,

                  padding: const EdgeInsets.all(12),

                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7E6),

                    borderRadius: BorderRadius.circular(10),
                  ),

                  child: const Text(
                    'Receiving account dekhne ke liye pehle appointment select karein.',

                    style: TextStyle(color: Color(0xFF92400E)),
                  ),
                ),

              if (areAccountsLoading) ...<Widget>[
                const LinearProgressIndicator(),

                const SizedBox(height: 10),

                const Text(
                  'Clinic ke payment accounts load ho rahe hain...',

                  style: TextStyle(color: Color(0xFF6B7E7C), fontSize: 12),
                ),
              ],

              if (!areAccountsLoading)
                DropdownButtonFormField<int>(
                  initialValue: selectedAccountId,

                  isExpanded: true,

                  decoration: InputDecoration(
                    labelText: 'Receiving account',

                    prefixIcon: const Icon(Icons.account_balance_outlined),

                    border: const OutlineInputBorder(),

                    helperText: selectedAppointmentId == null
                        ? 'Pehle appointment select karein.'
                        : null,
                  ),

                  items: accounts
                      .map((Map<String, dynamic> account) {
                        final int? id = asInt(account['id']);

                        if (id == null) {
                          return null;
                        }

                        final String title =
                            account['account_title']?.toString() ?? 'Account';

                        final String number =
                            account['account_number']?.toString() ?? '';

                        final String bankName =
                            account['bank_name']?.toString() ?? '';

                        return DropdownMenuItem<int>(
                          value: id,

                          child: Text(
                            bankName.isEmpty
                                ? '$title - $number'
                                : '$bankName • $title - $number',

                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      })
                      .whereType<DropdownMenuItem<int>>()
                      .toList(),

                  onChanged: selectedAppointmentId == null || accounts.isEmpty
                      ? null
                      : onAccountChanged,

                  validator: (int? value) {
                    if (onlinePayment && value == null) {
                      return 'Account select karein.';
                    }

                    return null;
                  },
                ),

              if (!areAccountsLoading &&
                  selectedAppointmentId != null &&
                  accounts.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),

                  child: Text(
                    'Is clinic ka $selectedMethodName account configured nahi hai.',

                    style: const TextStyle(
                      color: AppColors.error,

                      fontSize: 12,
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              /// Transaction ID.
              TextFormField(
                controller: referenceController,

                decoration: const InputDecoration(
                  labelText: 'Transaction reference',

                  hintText: 'Transaction ID enter karein',

                  prefixIcon: Icon(Icons.receipt_long_outlined),

                  border: OutlineInputBorder(),
                ),

                validator: (String? value) {
                  if (!onlinePayment) {
                    return null;
                  }

                  if (value == null || value.trim().isEmpty) {
                    return 'Transaction reference required hai.';
                  }

                  if (value.trim().length < 4) {
                    return 'Valid transaction reference enter karein.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              /// Receipt/proof image selection.
              SizedBox(
                width: double.infinity,

                child: OutlinedButton.icon(
                  onPressed: onPickProof,

                  icon: const Icon(Icons.upload_file_outlined),

                  label: Text(
                    proofName ?? 'Select payment proof',

                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              if (proofName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),

                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.check_circle_outline,

                        color: Color(0xFF15803D),

                        size: 18,
                      ),

                      const SizedBox(width: 6),

                      Expanded(
                        child: Text(
                          proofName!,

                          overflow: TextOverflow.ellipsis,

                          style: const TextStyle(
                            color: Color(0xFF15803D),

                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],

            const SizedBox(height: 22),

            /// Payment submit button.
            SizedBox(
              width: double.infinity,

              height: 50,

              child: FilledButton.icon(
                onPressed: isSubmitting || appointments.isEmpty
                    ? null
                    : onSubmit,

                icon: isSubmitting
                    ? const SizedBox(
                        width: 19,

                        height: 19,

                        child: CircularProgressIndicator(
                          strokeWidth: 2,

                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),

                label: Text(isSubmitting ? 'Submitting...' : 'Submit Payment'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Patient ki payment history.

class _PaymentHistory extends StatelessWidget {
  const _PaymentHistory({required this.payments});

  final List<Map<String, dynamic>> payments;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: <Widget>[
        const Text(
          'Payment History',

          style: TextStyle(
            color: Color(0xFF153936),

            fontSize: 21,

            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 14),

        if (payments.isEmpty)
          Container(
            width: double.infinity,

            padding: const EdgeInsets.all(24),

            decoration: BoxDecoration(
              color: Colors.white,

              borderRadius: BorderRadius.circular(18),

              border: Border.all(color: const Color(0xFFDCE9E7)),
            ),

            child: const Column(
              children: <Widget>[
                Icon(
                  Icons.account_balance_wallet_outlined,

                  size: 42,

                  color: Color(0xFF78908D),
                ),

                SizedBox(height: 10),

                Text(
                  'No payments found.',

                  style: TextStyle(color: Color(0xFF6B7E7C)),
                ),
              ],
            ),
          )
        else
          ...payments.map(
            (Map<String, dynamic> payment) => _PaymentCard(payment: payment),
          ),
      ],
    );
  }
}

/// Single payment history card.

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.payment});

  final Map<String, dynamic> payment;

  @override
  Widget build(BuildContext context) {
    final String status =
        payment['status']?.toString().toLowerCase() ?? 'pending';

    final Color color = _statusColor(status);

    final String doctorName =
        payment['doctor_name']?.toString() ?? 'Appointment Payment';

    final String clinicName = payment['clinic_name']?.toString() ?? '';

    final String appointmentReference =
        payment['appointment_reference']?.toString() ??
        'Appointment #${payment['appointment'] ?? '-'}';

    final String method =
        payment['payment_method_display']?.toString() ??
        payment['payment_method']?.toString() ??
        '-';

    final String amount = payment['amount']?.toString() ?? '0';

    final String statusDisplay =
        payment['status_display']?.toString() ?? status;

    final String rejectionReason =
        payment['rejection_reason']?.toString() ?? '';

    final String transactionReference =
        payment['transaction_reference']?.toString() ?? '';

    return Container(
      width: double.infinity,

      margin: const EdgeInsets.only(bottom: 12),

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: const Color(0xFFDCE9E7)),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),

                child: Icon(
                  Icons.account_balance_wallet_outlined,

                  color: color,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: <Widget>[
                    Text(
                      doctorName,

                      style: const TextStyle(
                        color: Color(0xFF153936),

                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    if (clinicName.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 3),

                      Text(
                        clinicName,

                        style: const TextStyle(
                          color: Color(0xFF6B7E7C),

                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,

                  vertical: 6,
                ),

                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),

                  borderRadius: BorderRadius.circular(20),
                ),

                child: Text(
                  statusDisplay,

                  style: TextStyle(
                    color: color,

                    fontSize: 12,

                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            appointmentReference,

            style: const TextStyle(
              color: Color(0xFF153936),

              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            '$method  •  Rs. $amount',

            style: const TextStyle(color: Color(0xFF6B7E7C)),
          ),

          if (transactionReference.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),

            Text(
              'Transaction: $transactionReference',

              style: const TextStyle(color: Color(0xFF6B7E7C), fontSize: 12),
            ),
          ],

          if (status == 'submitted') ...<Widget>[
            const SizedBox(height: 10),

            const Text(
              'Payment admin/clinic verification ka wait kar rahi hai.',

              style: TextStyle(color: Color(0xFFD97706), fontSize: 12),
            ),
          ],

          if (status == 'verified') ...<Widget>[
            const SizedBox(height: 10),

            const Text(
              'Payment verified hai. Aap appointment service use kar sakte hain.',

              style: TextStyle(color: Color(0xFF15803D), fontSize: 12),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,

              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) =>
                          PaymentReceiptScreen(payment: payment),
                    ),
                  );
                },

                icon: const Icon(Icons.receipt_long_outlined),

                label: const Text('View Receipt'),
              ),
            ),
          ],

          if (status == 'rejected' && rejectionReason.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),

            Container(
              width: double.infinity,

              padding: const EdgeInsets.all(10),

              decoration: BoxDecoration(
                color: const Color(0xFFFFEEEE),

                borderRadius: BorderRadius.circular(10),
              ),

              child: Text(
                'Rejected reason: $rejectionReason',

                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Payment status ka color return karega.

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
      case 'paid':
        return const Color(0xFF15803D);

      case 'rejected':
        return AppColors.error;

      case 'refunded':
        return const Color(0xFF2563EB);

      case 'submitted':
        return const Color(0xFF7C3AED);

      default:
        return const Color(0xFFF59E0B);
    }
  }
}
