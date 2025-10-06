import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _websiteController = TextEditingController();
  final _supabase = Supabase.instance.client;

  Map<String, dynamic>? _profileData; // <<< The missing variable
  bool _isLoading = true;
  String? _avatarUrl;
  String? _headerUrl;
  String? _usernameError;
  File? _newAvatarFile;
  File? _newHeaderFile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final data = await _supabase.from('profiles').select().eq('id', userId).single();
      
      _profileData = data; // <<< Populate the variable
      _nameController.text = data['name'] ?? '';
      _usernameController.text = data['username'] ?? '';
      _bioController.text = data['bio'] ?? '';
      _websiteController.text = data['website'] ?? '';
      _avatarUrl = data['avatar_url'];
      _headerUrl = data['header_url'];

    } catch (e) {
      log("Error loading profile: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading profile data.'), backgroundColor: Theme.of(context).colorScheme.error));
      }
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndCropImage({required bool isAvatar}) async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);

    if (pickedFile == null) return;

    final CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      aspectRatio: isAvatar ? const CropAspectRatio(ratioX: 1, ratioY: 1) : const CropAspectRatio(ratioX: 16, ratioY: 9),
      uiSettings: [
        AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: const Color(0xFF27538C),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: isAvatar ? CropAspectRatioPreset.square : CropAspectRatioPreset.ratio16x9,
            lockAspectRatio: true),
        IOSUiSettings(
          title: 'Crop Image',
          aspectRatioLockEnabled: true,
        ),
      ],
    );

    if (croppedFile != null) {
      setState(() {
        if (isAvatar) {
          _newAvatarFile = File(croppedFile.path);
        } else {
          _newHeaderFile = File(croppedFile.path);
        }
      });
    }
  }

  Future<String?> _uploadImage(File imageFile, String bucket, String path) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final fileExt = imageFile.path.split('.').last;
      final fileName = '$path.$fileExt';
      await _supabase.storage.from(bucket).uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );
      return _supabase.storage.from(bucket).getPublicUrl(fileName);
    } catch (e) {
      log("Image Upload Error: $e");
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userId = _supabase.auth.currentUser!.id;
      final newUsername = _usernameController.text.trim();

      if (_newAvatarFile == null && _newHeaderFile == null && _nameController.text.trim() == _profileData?['name'] && newUsername == _profileData?['username'] && _bioController.text.trim() == _profileData?['bio'] && _websiteController.text.trim() == _profileData?['website']){
          Navigator.of(context).pop();
          return;
      }

      if (_profileData?['username'] != newUsername) {
        final existingUser = await _supabase.from('profiles').select('id').eq('username', newUsername).maybeSingle();
        if (existingUser != null) {
          setState(() {
             _usernameError = 'Username is already taken.';
             _isLoading = false;
          });
          return;
        }
      }

      String? newAvatarUrl = _avatarUrl;
      if (_newAvatarFile != null) {
        newAvatarUrl = await _uploadImage(_newAvatarFile!, 'avatars', userId);
        if(newAvatarUrl == null) throw Exception('Failed to upload avatar.');
      }

      String? newHeaderUrl = _headerUrl;
      if (_newHeaderFile != null) {
        newHeaderUrl = await _uploadImage(_newHeaderFile!, 'headers', userId);
        if(newHeaderUrl == null) throw Exception('Failed to upload header image.');
      }

      await _supabase.from('profiles').update({
        'name': _nameController.text.trim(),
        'username': newUsername,
        'bio': _bioController.text.trim(),
        'website': _websiteController.text.trim(),
        'avatar_url': newAvatarUrl,
        'header_url': newHeaderUrl,
      }).eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green));
        Navigator.of(context).pop(true);
      }

    } catch (e) {
      log("Error saving profile: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving profile: ${e.toString()}'), backgroundColor: Theme.of(context).colorScheme.error));
      }
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  // Helper getter for the header image
  DecorationImage? get _headerImage {
    if (_newHeaderFile != null) {
      return DecorationImage(image: FileImage(_newHeaderFile!), fit: BoxFit.cover);
    }
    if (_headerUrl != null && _headerUrl!.isNotEmpty) {
      return DecorationImage(image: NetworkImage(_headerUrl!), fit: BoxFit.cover);
    }
    return null;
  }

  // Helper getter for the avatar image
  ImageProvider? get _avatarImageProvider {
    if (_newAvatarFile != null) {
      return FileImage(_newAvatarFile!);
    }
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      return NetworkImage(_avatarUrl!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1B2E47)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: const Text('Save', style: TextStyle(color: Color(0xFF558DCA), fontSize: 16, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildImagePickers(),
                  const SizedBox(height: 24),
                  _buildTextFormField(_nameController, 'Name'),
                  const SizedBox(height: 16),
                  _buildTextFormField(_usernameController, 'Username', errorText: _usernameError, validator: (val) {
                     if (val == null || val.isEmpty) return 'Username cannot be empty';
                     if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(val)) return 'Invalid characters';
                     return null;
                  }),
                  const SizedBox(height: 16),
                  _buildTextFormField(_bioController, 'Bio', maxLines: 3),
                  const SizedBox(height: 16),
                  _buildTextFormField(_websiteController, 'Website'),
                ],
              ),
            ),
    );
  }
  
  Widget _buildImagePickers() {
    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () => _pickAndCropImage(isAvatar: false),
          child: Container(
            height: 150,
            decoration: BoxDecoration(
              color: const Color(0xFFE8E8E8),
              borderRadius: BorderRadius.circular(12),
              image: _headerImage,
            ),
            child: _headerImage == null 
              ? const Center(child: Icon(Icons.add_a_photo, color: Colors.grey, size: 40)) 
              : null,
          ),
        ),
        Positioned(
          top: 90, 
          child: GestureDetector(
            onTap: () => _pickAndCropImage(isAvatar: true),
            child: CircleAvatar(
              radius: 60,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 56,
                backgroundColor: const Color(0xFFF0F0F0),
                 backgroundImage: _avatarImageProvider,
                child: _avatarImageProvider == null
                  ? const Icon(Icons.person, size: 50, color: Colors.grey)
                  : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  TextFormField _buildTextFormField(TextEditingController controller, String label, {int? maxLines = 1, String? errorText, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        labelStyle: const TextStyle(color: Color(0xFF1B2E47), fontSize: 14, fontWeight: FontWeight.w400),
        filled: true,
        fillColor: const Color(0xFFF8F8F8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(width: 1.5, color: Color(0xFF5F5F5F))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(width: 1.5, color: Color(0xFF5F5F5F))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(width: 2, color: Color(0xFF558DCA))),
      ),
      validator: validator,
    );
  }
}
