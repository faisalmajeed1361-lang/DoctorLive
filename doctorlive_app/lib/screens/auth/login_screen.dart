import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../services/auth_service.dart';
import '../dashboard_screen.dart';

/// Shared login screen for patient, doctor and administrator accounts.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  String? _selectedRole;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    if (_isLoading) return;

    if (_selectedRole == null) {
      _showMessage(
        'Select Patient, Doctor or Admin before login.',
        isError: true,
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final Map<String, dynamic> result = await _authService.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      final Map<String, dynamic> user = result['user'] is Map
          ? Map<String, dynamic>.from(result['user'] as Map)
          : <String, dynamic>{};

      final String actualRole = (result['role'] ?? user['role'] ?? 'patient')
          .toString()
          .trim()
          .toLowerCase();

      const Set<String> supportedRoles = <String>{'patient', 'doctor', 'admin'};

      if (!supportedRoles.contains(actualRole)) {
        await _authService.logout();
        throw Exception('Unsupported account role: $actualRole');
      }

      if (actualRole != _selectedRole) {
        await _authService.logout();
        throw Exception(
          'This account is registered as ${_roleLabel(actualRole)}. '
          'Please select ${_roleLabel(actualRole)} and login again.',
        );
      }

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (BuildContext context) {
            return DashboardScreen(role: actualRole);
          },
        ),
        (Route<dynamic> route) => false,
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showMessage(String message, {required bool isError}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.error : AppColors.primary,
        ),
      );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'doctor':
        return 'Doctor';
      default:
        return 'Patient';
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F8F7),
      body: SafeArea(
        child: Row(
          children: <Widget>[
            if (screenWidth >= 900)
              const Expanded(flex: 5, child: _BrandingPanel()),
            Expanded(
              flex: screenWidth >= 900 ? 6 : 1,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                        side: const BorderSide(color: Color(0xFFD8E7E4)),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(screenWidth < 600 ? 22 : 34),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const _MobileLogo(),
                              const SizedBox(height: 22),
                              const Text(
                                'Welcome to DoctorLive',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Choose your account type, then enter your '
                                'username and password.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 15,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Select account type',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              LayoutBuilder(
                                builder:
                                    (
                                      BuildContext context,
                                      BoxConstraints constraints,
                                    ) {
                                      final bool stackCards =
                                          constraints.maxWidth < 470;

                                      final List<Widget> cards = <Widget>[
                                        _RoleCard(
                                          role: 'patient',
                                          label: 'Patient',
                                          subtitle: 'Book and manage care',
                                          icon: Icons.person_outline_rounded,
                                          selected: _selectedRole == 'patient',
                                          enabled: !_isLoading,
                                          onTap: _selectRole,
                                        ),
                                        _RoleCard(
                                          role: 'doctor',
                                          label: 'Doctor',
                                          subtitle: 'Consult and prescribe',
                                          icon: Icons.medical_services_outlined,
                                          selected: _selectedRole == 'doctor',
                                          enabled: !_isLoading,
                                          onTap: _selectRole,
                                        ),
                                        _RoleCard(
                                          role: 'admin',
                                          label: 'Admin',
                                          subtitle: 'Verify and manage',
                                          icon: Icons
                                              .admin_panel_settings_outlined,
                                          selected: _selectedRole == 'admin',
                                          enabled: !_isLoading,
                                          onTap: _selectRole,
                                        ),
                                      ];

                                      if (stackCards) {
                                        return Column(
                                          children: cards
                                              .map(
                                                (Widget card) => Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 10,
                                                      ),
                                                  child: card,
                                                ),
                                              )
                                              .toList(),
                                        );
                                      }

                                      return Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: cards
                                            .map(
                                              (Widget card) => Expanded(
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 5,
                                                      ),
                                                  child: card,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                      );
                                    },
                              ),
                              const SizedBox(height: 24),
                              TextFormField(
                                controller: _usernameController,
                                enabled: !_isLoading,
                                textInputAction: TextInputAction.next,
                                autocorrect: false,
                                decoration: const InputDecoration(
                                  labelText: 'Username',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                validator: (String? value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Username is required.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),
                              TextFormField(
                                controller: _passwordController,
                                enabled: !_isLoading,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) {
                                  if (!_isLoading) _login();
                                },
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    tooltip: _obscurePassword
                                        ? 'Show password'
                                        : 'Hide password',
                                    onPressed: _isLoading
                                        ? null
                                        : () {
                                            setState(() {
                                              _obscurePassword =
                                                  !_obscurePassword;
                                            });
                                          },
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                validator: (String? value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Password is required.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 26),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: FilledButton.icon(
                                  onPressed: _isLoading ? null : _login,
                                  icon: _isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.login_rounded),
                                  label: Text(
                                    _selectedRole == null
                                        ? 'Select account and login'
                                        : 'Login as ${_roleLabel(_selectedRole!)}',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              const Center(
                                child: Text(
                                  'Your account role is securely verified '
                                  'by DoctorLive.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectRole(String role) {
    if (_isLoading) return;
    setState(() {
      _selectedRole = role;
    });
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String role;
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = selected
        ? AppColors.primary
        : const Color(0xFFD3E2DF);

    return Semantics(
      button: true,
      selected: selected,
      label: '$label account',
      child: InkWell(
        onTap: enabled ? () => onTap(role) : null,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE2F5F2) : const Color(0xFFF9FBFB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
          ),
          child: Column(
            children: <Widget>[
              Icon(
                icon,
                color: selected ? AppColors.primary : AppColors.textSecondary,
                size: 30,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandingPanel extends StatelessWidget {
  const _BrandingPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      padding: const EdgeInsets.all(64),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF064E49),
            AppColors.primary,
            AppColors.secondary,
          ],
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _DoctorLiveLogo(color: Colors.white),
          Spacer(),
          _BrandLogoImage(size: 115),
          SizedBox(height: 26),
          Text(
            'One platform.\nThree secure roles.\nBetter healthcare.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 42,
              height: 1.15,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 22),
          Text(
            'Patients, doctors and administrators can access their own '
            'secure workspace from the same DoctorLive application.',
            style: TextStyle(
              color: Color(0xFFD6FFFA),
              fontSize: 17,
              height: 1.6,
            ),
          ),
          Spacer(),
          Text(
            'DoctorLive Healthcare Platform',
            style: TextStyle(color: Color(0xFFCCFBF1)),
          ),
        ],
      ),
    );
  }
}

class _MobileLogo extends StatelessWidget {
  const _MobileLogo();

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= 900) {
      return const SizedBox.shrink();
    }
    return const _DoctorLiveLogo(color: AppColors.primary);
  }
}

class _DoctorLiveLogo extends StatelessWidget {
  const _DoctorLiveLogo({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 56,
          height: 56,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Image.asset(
            'assets/images/doctorlive_logo.png',
            fit: BoxFit.contain,
            errorBuilder:
                (BuildContext context, Object error, StackTrace? stackTrace) {
                  return const Icon(
                    Icons.health_and_safety_outlined,
                    color: AppColors.primary,
                    size: 34,
                  );
                },
          ),
        ),
        const SizedBox(width: 14),
        Text(
          'DoctorLive',
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _BrandLogoImage extends StatelessWidget {
  const _BrandLogoImage({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.12),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Image.asset(
        'assets/images/doctorlive_logo.png',
        fit: BoxFit.contain,
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) {
              return const Icon(
                Icons.health_and_safety_outlined,
                color: AppColors.primary,
                size: 70,
              );
            },
      ),
    );
  }
}
