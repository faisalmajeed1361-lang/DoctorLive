import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/profile_service.dart';

/// Patient aur doctor dono ke liye editable account profile screen.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _city = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final TextEditingController _qualification = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _username = '';
  String _role = '';
  String? _imageUrl;
  String? _newImagePath;
  Uint8List? _newImageBytes;
  String? _newImageName;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _city.dispose();
    _address.dispose();
    _qualification.dispose();
    super.dispose();
  }

  /// Backend se latest profile data load karke form fill karega.
  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final Map<String, dynamic> data = await _profileService.getProfile();
      if (!mounted) return;

      _username = data['username']?.toString() ?? '';
      _role = data['role']?.toString() ?? '';
      _imageUrl = data['profile_image_url']?.toString();
      _firstName.text = data['first_name']?.toString() ?? '';
      _lastName.text = data['last_name']?.toString() ?? '';
      _email.text = data['email']?.toString() ?? '';
      _phone.text = data['phone_number']?.toString() ?? '';
      _city.text = data['city']?.toString() ?? '';
      _address.text = data['address']?.toString() ?? '';
      _qualification.text = data['qualification']?.toString() ?? '';
    } catch (error) {
      _error = error.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// Gallery/file picker se JPG ya PNG profile image select karega.
  Future<void> _pickImage() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final PlatformFile file = result.files.single;
    if (file.size > 5 * 1024 * 1024) {
      _showMessage('Profile image 5 MB se zyada nahi ho sakti.', true);
      return;
    }

    setState(() {
      _newImageName = file.name;
      _newImagePath = file.path;
      _newImageBytes = file.bytes;
    });
  }

  /// Form validate karke profile backend database mein save karega.
  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false) || _saving) return;

    setState(() => _saving = true);
    try {
      final Map<String, dynamic> data = await _profileService.updateProfile(
        firstName: _firstName.text,
        lastName: _lastName.text,
        email: _email.text,
        phoneNumber: _phone.text,
        city: _city.text,
        address: _address.text,
        qualification: _qualification.text,
        imagePath: _newImagePath,
        imageBytes: _newImageBytes,
        imageName: _newImageName,
      );
      if (!mounted) return;

      setState(() {
        _imageUrl = data['profile_image_url']?.toString() ?? _imageUrl;
        _newImagePath = null;
        _newImageBytes = null;
        _newImageName = null;
      });
      _showMessage('Profile successfully updated.', false);
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString().replaceFirst('Exception: ', ''), true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message, bool error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : const Color(0xFF13877C),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F8F7),
      appBar: AppBar(
        title: Text(_role == 'doctor' ? 'Doctor Profile' : 'My Profile'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadProfile,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loadProfile,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: Color(0xFFD6E5E2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _profileHeader(),
                    const SizedBox(height: 30),
                    LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints box) {
                        final bool wide = box.maxWidth >= 650;
                        return Wrap(
                          spacing: 18,
                          runSpacing: 18,
                          children: <Widget>[
                            _field(
                              _firstName,
                              'First name',
                              Icons.person,
                              wide,
                            ),
                            _field(
                              _lastName,
                              'Last name',
                              Icons.person_outline,
                              wide,
                            ),
                            _field(
                              _email,
                              'Email',
                              Icons.email_outlined,
                              wide,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            _field(
                              _phone,
                              'Phone number',
                              Icons.phone_outlined,
                              wide,
                              keyboardType: TextInputType.phone,
                            ),
                            _field(_city, 'City', Icons.location_city, wide),
                            _field(
                              _address,
                              'Address',
                              Icons.home_outlined,
                              wide,
                            ),
                            if (_role == 'doctor')
                              _field(
                                _qualification,
                                'Qualification',
                                Icons.workspace_premium_outlined,
                                wide,
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _saveProfile,
                        icon: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(_saving ? 'Saving...' : 'Save Profile'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF13877C),
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
    );
  }

  Widget _profileHeader() {
    ImageProvider<Object>? image;
    if (_newImageBytes != null) {
      image = MemoryImage(_newImageBytes!);
    } else if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      image = NetworkImage(_imageUrl!);
    }

    return Row(
      children: <Widget>[
        Stack(
          children: <Widget>[
            CircleAvatar(
              radius: 52,
              backgroundColor: const Color(0xFFD5F4F0),
              backgroundImage: image,
              child: image == null
                  ? const Icon(Icons.person, size: 52, color: Color(0xFF08796F))
                  : null,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: IconButton.filled(
                tooltip: 'Change photo',
                onPressed: _pickImage,
                icon: const Icon(Icons.camera_alt_outlined, size: 19),
              ),
            ),
          ],
        ),
        const SizedBox(width: 22),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${_firstName.text} ${_lastName.text}'.trim().isEmpty
                    ? _username
                    : '${_firstName.text} ${_lastName.text}'.trim(),
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF153936),
                ),
              ),
              const SizedBox(height: 5),
              Text('@$_username  •  ${_role.toUpperCase()}'),
              const SizedBox(height: 7),
              const Text('JPG/PNG, maximum 5 MB'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon,
    bool wide, {
    TextInputType? keyboardType,
  }) {
    final double width = wide ? 397 : double.infinity;
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: (String? value) {
          if ((label == 'First name' || label == 'Email') &&
              (value == null || value.trim().isEmpty)) {
            return '$label is required.';
          }
          if (label == 'Email' && !value!.contains('@')) {
            return 'Enter a valid email.';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
