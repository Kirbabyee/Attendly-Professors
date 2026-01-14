import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:professor/Professor%20Page/professor_session.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;

import '../mainshell.dart';
import 'change_email.dart';

class AccountInformation extends StatefulWidget {
  const AccountInformation({super.key});

  @override
  State<AccountInformation> createState() => _AccountInformationState();
}

class _AccountInformationState extends State<AccountInformation> {
  final supabase = Supabase.instance.client;

  bool _uploading = false;
  String? _uploadError;
  String? _avatarUrl; // from DB

  final ImagePicker _picker = ImagePicker();
  File? _profileImage;

  Map<String, dynamic>? _professor;
  bool _loadingProfessor = true;
  String? _professorError;

  @override
  void initState() {
    super.initState();
    _loadProfessor();
  }

  Future<void> _loadProfessor() async {
    try {
      final s = await ProfessorSession.get(); // cached
      if (!mounted) return;

      final email = (s?['email'] ?? '').toString().trim();

      setState(() {
        _professor = s;
        _email = email.isEmpty ? null : email;

        _avatarUrl = (s?['avatar_url'] ?? '').toString().trim();
        if (_avatarUrl!.isEmpty) _avatarUrl = null;

        _loadingProfessor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _professorError = e.toString();
        _loadingProfessor = false;
      });
    }
  }


  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image == null) return;

    setState(() {
      _profileImage = File(image.path);
    });
  }

  Future<void> _uploadProfileImage() async {
    if (_profileImage == null) return;

    setState(() {
      _uploading = true;
      _uploadError = null;
    });

    try {
      final professorId = _professor?['id']?.toString();
      if (professorId == null || professorId.isEmpty) {
        throw Exception('Missing Professor id');
      }

      final file = _profileImage!;
      final bytes = await file.readAsBytes();

      // file extension + content type
      final ext = p.extension(file.path).toLowerCase(); // .jpg/.png
      final fileExt = (ext.isEmpty) ? '.jpg' : ext;
      final contentType = (fileExt == '.png') ? 'image/png' : 'image/jpeg';

      // storage path (overwrite same file per professor)
      final uid = supabase.auth.currentUser!.id;
      final path = '$uid/avatar$fileExt';

      // ✅ Upload (upsert = overwrite)
      await supabase.storage.from('avatars').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          contentType: contentType,
          upsert: true,
        ),
      );

      // ✅ Get public URL (works if bucket is PUBLIC)
      final baseUrl = supabase.storage.from('avatars').getPublicUrl(path);
      final publicUrl = '$baseUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      // ✅ Save to professors table
      final nowIso = DateTime.now().toUtc().toIso8601String();

      await supabase
          .from('professors')
          .update({
        'avatar_url': publicUrl,
      })
          .eq('id', professorId);

      final fresh = {
        ...?_professor,
        'avatar_url': publicUrl,
      };

      ProfessorSession.set(fresh);

      if (!mounted) return;
      setState(() {
        _professor = fresh;
        _avatarUrl = publicUrl;
        _profileImage = null;
      });

      _showBottomBanner(
        context,
        message: 'Profile picture updated!',
        success: true,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadError = e.toString());
      _showBottomBanner(
        context,
        message: 'Upload failed: $e',
        success: false,
      );
    } finally {
      if (!mounted) return;
      setState(() => _uploading = false);
    }
  }

  void _showBottomBanner(
      BuildContext context, {
        required String message,
        bool success = true,
      }) {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        // auto close after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (Navigator.of(context).canPop()) Navigator.of(context).pop();
        });

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: success ? const Color(0xFF018832) : const Color(0xFFB60202),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 10,
                      offset: Offset(0, 4),
                      color: Colors.black26,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      success ? Icons.check_circle : Icons.error,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        message,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }


  String? _email;

  String maskEmail(String email, {int keepStart = 3, int keepEnd = 2}) { // email masking
    email = email.trim();
    final atIndex = email.indexOf('@');
    if (atIndex == -1) return email; // not a valid email format

    final local = email.substring(0, atIndex);      // before @
    final domain = email.substring(atIndex + 1);    // after @

    if (local.length <= keepStart + keepEnd) {
      // Too short to mask nicely
      return '${local[0]}***@$domain';
    }

    final start = local.substring(0, keepStart);
    final end = local.substring(local.length - keepEnd);

    final stars = '*' * (local.length - keepStart - keepEnd);

    return '$start$stars$end@$domain';
  }


  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // HEADER (fixed)
            Container(
              height: 100,
              padding: EdgeInsets.symmetric(horizontal: 30),
              decoration: BoxDecoration(
                color: Color(0xFF004280),
                borderRadius: BorderRadius.vertical(
                  top: Radius.zero,
                  bottom: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadiusGeometry.circular(7),
                      color: Color(0x30FFFFFF),
                    ),
                    child: Icon(
                      Icons.settings,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                  SizedBox(width: 15),
                  Container(
                    height: 50,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Settings',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: screenHeight > 700 ? 10 : 5),
                        Text(
                          'Manage your preferences',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                          ),
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
            SizedBox(height: screenHeight > 370 ? 50 : 10,),
            Container(
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const Mainshell(initialIndex: 2,)),
                      );
                    },
                    icon: Icon(CupertinoIcons.arrow_left)
                  ),
                  Text('Back'),
                ],
              ),
            ),

            // Account Informaton
            SizedBox(height: screenHeight > 370 ? 20 : 0,),
            Container(
              width: 350,
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadiusGeometry.circular(8)
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 20,
                      ),
                      SizedBox(width: 10,),
                      Text(
                        'Account Information',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 30,),
                  Center(
                    child: Container(
                      child: Column(
                        children: [
                          SizedBox(
                            width: 180,
                            height: 180,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(90),
                              child: _profileImage != null
                                  ? Image.file(_profileImage!, fit: BoxFit.cover)
                                  : (_avatarUrl != null
                                  ? Image.network(_avatarUrl!, fit: BoxFit.cover)
                                  : Image.asset('assets/avatar.png', fit: BoxFit.cover)),
                            ),
                          ),
                          SizedBox(height: 20,),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Color(0xFF018832),
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadiusGeometry.circular(8)
                              )
                            ),
                            onPressed: _uploading
                                ? null
                                : () async {
                              await _pickImage();
                              if (_profileImage != null) {
                                await _uploadProfileImage();
                              }
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_uploading) ...[
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Uploading...',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: screenHeight * .015,
                                      fontWeight: FontWeight.w300,
                                    ),
                                  ),
                                ] else ...[
                                  Icon(Icons.upload, color: Colors.white, size: screenHeight * .023),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Upload',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: screenHeight * .015,
                                      fontWeight: FontWeight.w300,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (_uploadError != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _uploadError!,
                              style: TextStyle(color: Colors.red, fontSize: screenHeight * .014),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20,),
                  // ✅ Loading / Error state
                  if (_loadingProfessor)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: CircularProgressIndicator(),
                    )
                  else if (_professorError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        'Error: $_professorError',
                        style: TextStyle(color: Colors.red, fontSize: screenHeight * .014),
                      ),
                    )
                  else
                  Center(
                    child: Container(
                      width: 250,
                      decoration: BoxDecoration(
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Name:',
                                style: TextStyle(
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                _professor?['professor_name'] ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                    fontWeight: FontWeight.bold
                                ),
                              )
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Department:',
                                style: TextStyle(
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                _professor?['department'] ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                    fontWeight: FontWeight.bold
                                ),
                              )
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Email:',
                                style: TextStyle(fontSize: 12),
                              ),
                              Text(
                                _email == null ? '-' : maskEmail(_email!),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          SizedBox(height: 10,),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              InkWell(
                                onTap: () async {
                                  final newEmail = await Navigator.push<String>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChangeEmail(currentEmail: _email ?? ''),
                                    ),
                                  );

                                  if (newEmail != null && newEmail.trim().isNotEmpty) {
                                    setState(() {
                                      _email = newEmail.trim();
                                    });
                                  }
                                },
                                child: Text(
                                  'Change Email?',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF105698), // link blue
                                  ),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 10,)
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
