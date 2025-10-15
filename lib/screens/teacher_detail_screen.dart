import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:hive/hive.dart';
import '../models/teacher.dart';
import '../services/language_service.dart';
import '../services/cache_service.dart';

class TeacherDetailScreen extends StatefulWidget {
  final Teacher teacher;

  const TeacherDetailScreen({super.key, required this.teacher});

  @override
  TeacherDetailScreenState createState() => TeacherDetailScreenState();
}

class TeacherDetailScreenState extends State<TeacherDetailScreen> {
  bool _isLoading = true;
  String? _teacherUsername;
  String? _teacherPassword;
  bool _hasUserAccount = false;
  String? _currentUserRole; // Add current user role tracking
  bool? _isViewingOwnProfile; // Cache the profile check result
  Uint8List? _cachedImageBytes; // Add cached image bytes

  // Editable fields
  bool _isEditingBasicInfo = false;
  late TextEditingController _nameController;
  late TextEditingController _subjectController;
  late TextEditingController _addressController;
  late TextEditingController _experienceController;
  late TextEditingController _hourlyPayController;
  String _selectedGender = 'Male';

  // Current displayed values (for live updates) - with defaults to handle null values
  late String _currentName;
  late String _currentGender;
  late String _currentSubject;
  late String _currentAddress;
  late String _currentExperience;
  late String _currentHourlyPay;

  // Track if values have been locally modified
  bool _hasLocalChanges = false;

  // Static cache to persist data across widget rebuilds
  static Map<String, Map<String, String>> _teacherDataCache = {};
  @override
  void initState() {
    super.initState();
    _loadTeacherCredentials();
    _loadCurrentUserRole(); // Add this line
    _loadOwnProfileCheck(); // Add this line
    _loadTeacherImage(); // Add this line

    print('DEBUG: initState called with address: "${widget.teacher.address}"');

    // Check if we have cached data for this teacher
    final teacherId = widget.teacher.objectId;
    final cachedData = _teacherDataCache[teacherId];

    if (cachedData != null) {
      print('DEBUG: Found cached data for teacher $teacherId');
      // Use cached data (locally modified data)
      _currentName = cachedData['name'] ?? widget.teacher.fullName;
      _currentGender = cachedData['gender'] ?? widget.teacher.gender;
      _currentSubject = cachedData['subject'] ?? widget.teacher.subject;
      _currentAddress = cachedData['address'] ?? widget.teacher.address ?? '';
      _currentExperience = cachedData['experience'] ??
          widget.teacher.yearsOfExperience.toString();
      _currentHourlyPay =
          cachedData['hourlyPay'] ?? widget.teacher.hourlyRate.toString();
      _hasLocalChanges = true;
      print('DEBUG: Using cached address: "$_currentAddress"');
    } else {
      print('DEBUG: No cached data, using original teacher data');
      // Initialize with original teacher data
      _currentName = widget.teacher.fullName;
      _currentGender = widget.teacher.gender;
      _currentSubject = widget.teacher.subject;
      _currentAddress = widget.teacher.address ?? '';
      _currentExperience = widget.teacher.yearsOfExperience.toString();
      _currentHourlyPay = widget.teacher.hourlyRate.toString();
      _hasLocalChanges = false;
    }

    _nameController = TextEditingController(text: _currentName);
    _subjectController = TextEditingController(text: _currentSubject);
    _addressController = TextEditingController(text: _currentAddress);
    _experienceController = TextEditingController(text: _currentExperience);
    _hourlyPayController = TextEditingController(text: _currentHourlyPay);
    _selectedGender = _currentGender;

    print('DEBUG: _currentAddress initialized to: "$_currentAddress"');
  }

  @override
  void didUpdateWidget(TeacherDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    print('DEBUG: didUpdateWidget called');
    print('DEBUG: Old widget address: "${oldWidget.teacher.address}"');
    print('DEBUG: New widget address: "${widget.teacher.address}"');
    print('DEBUG: Current _currentAddress: "$_currentAddress"');

    // Don't reset if we have local changes that haven't been reflected in widget.teacher
    if (widget.teacher.address != oldWidget.teacher.address &&
        !_hasLocalChanges) {
      print('DEBUG: Widget teacher address changed, updating current values');
      _currentName = widget.teacher.fullName;
      _currentGender = widget.teacher.gender;
      _currentSubject = widget.teacher.subject;
      _currentAddress = widget.teacher.address ?? '';

      // Update controllers if not currently editing
      if (!_isEditingBasicInfo) {
        _nameController.text = _currentName;
        _subjectController.text = _currentSubject;
        _addressController.text = _currentAddress;
        _selectedGender = _currentGender;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _subjectController.dispose();
    _addressController.dispose();
    _experienceController.dispose();
    _hourlyPayController.dispose();
    super.dispose();
  }

  Future<void> _loadTeacherCredentials() async {
    final teacherId = widget.teacher.objectId;

    // Try to load from cache first
    final cachedCredentials =
        CacheService.getTeacherCredentials(teacherId: teacherId);
    if (cachedCredentials != null &&
        CacheService.isCacheFresh(cachedCredentials['lastUpdated'],
            maxAgeMinutes: 10)) {
      setState(() {
        _teacherUsername = cachedCredentials['username'];
        _teacherPassword = cachedCredentials['password'];
        _hasUserAccount = cachedCredentials['hasUserAccount'] ?? false;
        _isLoading = false;
      });
      print('DEBUG: Loaded teacher credentials from cache');

      // Still fetch fresh data in background
      _loadFreshCredentials();
      return;
    }

    // Load fresh data if no cache or cache is stale
    await _loadFreshCredentials();
  }

  Future<void> _loadFreshCredentials() async {
    try {
      final query = QueryBuilder<ParseObject>(ParseObject('Teacher'))
        ..whereEqualTo('objectId', widget.teacher.objectId);

      final response = await query.query();

      if (response.success &&
          response.results != null &&
          response.results!.isNotEmpty) {
        final teacherRecord = response.results!.first as ParseObject;

        final username = teacherRecord.get<String>('username');
        final password = teacherRecord.get<String>('plainPassword');
        final hasUserAccount =
            teacherRecord.get<bool>('hasUserAccount') ?? false;

        // Cache the credentials
        await CacheService.saveTeacherCredentials(
          teacherId: widget.teacher.objectId,
          username: username,
          password: password,
          hasUserAccount: hasUserAccount,
        );

        setState(() {
          _teacherUsername = username;
          _teacherPassword = password;
          _hasUserAccount = hasUserAccount;
          _isLoading = false;
        });

        print('DEBUG: Loaded and cached fresh teacher credentials');
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading teacher credentials: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCurrentUserRole() async {
    try {
      final user = await ParseUser.currentUser();
      final role = user?.get<String>('role');
      if (mounted) {
        setState(() {
          _currentUserRole = role;
        });
      }
    } catch (e) {
      print('Error loading current user role: $e');
    }
  }

  // Load and cache the profile check result
  Future<void> _loadOwnProfileCheck() async {
    try {
      final user = await ParseUser.currentUser();
      if (user == null) {
        _isViewingOwnProfile = false;
        return;
      }

      // Check if current user's username matches the teacher's username
      final currentUsername = user.username;
      final teacherUsername = widget.teacher.username ?? _teacherUsername;

      if (mounted) {
        setState(() {
          _isViewingOwnProfile = (currentUsername == teacherUsername);
        });
      }
    } catch (e) {
      print('Error checking if viewing own profile: $e');
      if (mounted) {
        setState(() {
          _isViewingOwnProfile = false;
        });
      }
    }
  }

  // Add method to load cached teacher image
  Future<void> _loadTeacherImage() async {
    try {
      final box = await Hive.openBox('teacherImages');
      final cached = box.get(widget.teacher.objectId);
      if (cached != null) {
        print('🖼️ Using cached image for teacher: ${widget.teacher.objectId}');
        if (mounted) {
          setState(() {
            _cachedImageBytes = Uint8List.fromList(List<int>.from(cached));
          });
        }
        return;
      }

      // If no cached image and photoUrl exists, try to load and cache it
      final photoUrl = widget.teacher.photoUrl;
      if (photoUrl != null &&
          photoUrl.isNotEmpty &&
          photoUrl.startsWith('http')) {
        try {
          print(
              '🌐 Loading fresh image for teacher: ${widget.teacher.objectId} from: ${photoUrl.substring(0, 50)}...');
          final response = await http.get(Uri.parse(photoUrl));
          if (response.statusCode == 200) {
            await box.put(widget.teacher.objectId, response.bodyBytes);
            print('✅ Cached new image for teacher: ${widget.teacher.objectId}');
            if (mounted) {
              setState(() {
                _cachedImageBytes = response.bodyBytes;
              });
            }
          } else {
            print('❌ Failed to load image: HTTP ${response.statusCode}');
          }
        } catch (e) {
          print(
              '❌ Error loading image for teacher ${widget.teacher.objectId}: $e');
        }
      } else {
        print(
            '❌ Invalid image URL for teacher ${widget.teacher.objectId}: $photoUrl');
      }
    } catch (e) {
      print('❌ Error loading teacher image: $e');
    }
  }

  // Getter for checking if user can edit credentials
  bool get _canEditCredentials {
    if (_currentUserRole != 'teacher') return true; // Admins can always edit
    return _isViewingOwnProfile ??
        false; // Teachers can edit only their own profile
  }

  Future<void> _refreshTeacherData() async {
    setState(() {
      _isLoading = true;
    });

    // Clear cache for this teacher
    await CacheService.clearTeacherDetail(teacherId: widget.teacher.objectId);

    // Clear static cache as well
    _teacherDataCache.remove(widget.teacher.objectId);

    // Clear the image cache for this teacher
    try {
      final box = await Hive.openBox('teacherImages');
      await box.delete(widget.teacher.objectId);
      print('🗑️ Cleared image cache for teacher: ${widget.teacher.objectId}');

      // Reset cached image bytes
      setState(() {
        _cachedImageBytes = null;
      });
    } catch (e) {
      print('❌ Error clearing image cache: $e');
    }

    // Reload data
    await Future.wait([
      _loadTeacherCredentials(),
      _loadCurrentUserRole(),
      _loadOwnProfileCheck(),
      _loadTeacherImage(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Consumer<LanguageService>(
      builder: (context, languageService, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text('${widget.teacher.fullName} ${l10n.teacherDetails}'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.blue),
                onPressed: _refreshTeacherData,
                tooltip: 'Refresh Data',
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _showDeleteConfirmationDialog(),
                tooltip: l10n.deleteTeacher,
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Teacher Photo Section
                      Center(
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: () {
                                _showPhotoPickerDialog();
                              },
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.blue[300]!,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: _cachedImageBytes != null
                                      ? Image.memory(
                                          _cachedImageBytes!,
                                          width: 120,
                                          height: 120,
                                          fit: BoxFit.cover,
                                        )
                                      : (widget.teacher.photoUrl != null &&
                                              widget
                                                  .teacher.photoUrl!.isNotEmpty)
                                          ? Image.network(
                                              widget.teacher.photoUrl!,
                                              width: 120,
                                              height: 120,
                                              fit: BoxFit.cover,
                                              loadingBuilder: (context, child,
                                                  loadingProgress) {
                                                if (loadingProgress == null) {
                                                  return child;
                                                }
                                                return Container(
                                                  width: 120,
                                                  height: 120,
                                                  decoration:
                                                      const BoxDecoration(
                                                    color: Colors.grey,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Center(
                                                    child:
                                                        CircularProgressIndicator(),
                                                  ),
                                                );
                                              },
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                print(
                                                    'Error loading image: $error');
                                                return _buildPhotoPlaceholder();
                                              },
                                            )
                                          : _buildPhotoPlaceholder(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _currentName,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue[200]!),
                              ),
                              child: Text(
                                _currentSubject.isEmpty
                                    ? 'Teacher'
                                    : '$_currentSubject Teacher',
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Update Photo Button
                            ElevatedButton.icon(
                              onPressed: () {
                                _showUpdatePhotoDialog();
                              },
                              icon: const Icon(Icons.camera_alt, size: 18),
                              label: Text(l10n.updatePhoto),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[600],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Basic Information Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    l10n.basicInformation,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall,
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      _isEditingBasicInfo
                                          ? Icons.close
                                          : Icons.edit,
                                      color: _isEditingBasicInfo
                                          ? Colors.red
                                          : Colors.blue,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        if (_isEditingBasicInfo) {
                                          // Cancel editing - reset values
                                          _nameController.text = _currentName;
                                          _subjectController.text =
                                              _currentSubject;
                                          _addressController.text =
                                              _currentAddress;
                                          _experienceController.text =
                                              _currentExperience;
                                          _hourlyPayController.text =
                                              _currentHourlyPay;
                                          _selectedGender = _currentGender;
                                        }
                                        _isEditingBasicInfo =
                                            !_isEditingBasicInfo;
                                      });
                                    },
                                    tooltip: _isEditingBasicInfo
                                        ? l10n.cancel
                                        : l10n.edit,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (_isEditingBasicInfo) ...[
                                // Editable mode
                                _buildEditableField(l10n.fullName,
                                    _nameController, Icons.person),
                                const SizedBox(height: 16),
                                _buildGenderDropdown(),
                                const SizedBox(height: 16),
                                _buildEditableField(l10n.subject,
                                    _subjectController, Icons.book),
                                const SizedBox(height: 16),
                                _buildEditableField(l10n.address,
                                    _addressController, Icons.location_on),
                                const SizedBox(height: 16),
                                _buildEditableField(l10n.yearsOfExperience,
                                    _experienceController, Icons.work),
                                const SizedBox(height: 16),
                                _buildEditableField(l10n.hourlyPay,
                                    _hourlyPayController, Icons.attach_money),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _saveBasicInformation,
                                        icon: const Icon(Icons.save),
                                        label: Text(l10n.saveChanges),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                // Read-only mode
                                Builder(
                                  builder: (context) {
                                    print(
                                        'DEBUG: Building read-only view with:');
                                    print('DEBUG: _currentName: $_currentName');
                                    print(
                                        'DEBUG: _currentGender: $_currentGender');
                                    print(
                                        'DEBUG: _currentSubject: $_currentSubject');
                                    print(
                                        'DEBUG: _currentAddress: "$_currentAddress"');
                                    print(
                                        'DEBUG: _currentAddress.isEmpty: ${_currentAddress.isEmpty}');
                                    return Column(
                                      children: [
                                        _buildDetailRow(
                                            l10n.fullName, _currentName),
                                        _buildDetailRow(
                                            l10n.gender, _currentGender),
                                        _buildDetailRow(
                                            l10n.subject,
                                            _currentSubject.isEmpty
                                                ? l10n.notSpecified
                                                : _currentSubject),
                                        _buildDetailRow(
                                            l10n.address,
                                            _currentAddress.isEmpty
                                                ? l10n.notSpecified
                                                : _currentAddress),
                                        _buildDetailRow(
                                            l10n.yearsOfExperience,
                                            _currentExperience.isEmpty
                                                ? '0'
                                                : '$_currentExperience ${l10n.years}'),
                                        _buildDetailRow(
                                            l10n.hourlyPay,
                                            _currentHourlyPay.isEmpty
                                                ? l10n.notSpecified
                                                : '\$${_currentHourlyPay}/${l10n.hr}'),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Login Credentials Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.loginCredentials,
                                style:
                                    Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 16),
                              if (_hasUserAccount) ...[
                                _buildDetailRow(l10n.username,
                                    _teacherUsername ?? l10n.notAvailable),
                                _buildDetailRow(l10n.password,
                                    _teacherPassword ?? l10n.notAvailable),
                                _buildDetailRow(
                                    l10n.accountStatus, l10n.active),
                                const SizedBox(height: 16),
                                // Credential Management Buttons for Existing Accounts (Allow for admins or teachers viewing their own profile)
                                if (_canEditCredentials) ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            _showChangePasswordDialog();
                                          },
                                          icon: const Icon(Icons.lock_reset),
                                          label: Text(l10n.changePassword),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orange,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            _showChangeUsernameDialog();
                                          },
                                          icon:
                                              const Icon(Icons.person_outline),
                                          label: Text(l10n.changeUsername),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        _showCopyCredentialsDialog();
                                      },
                                      icon: const Icon(Icons.copy),
                                      label: Text(l10n.copyCredentials),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                // Add warning and recreate account option (Allow for admins or teachers viewing their own profile)
                                if (_canEditCredentials) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.orange[200]!),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.warning,
                                                color: Colors.orange[600],
                                                size: 20),
                                            const SizedBox(width: 8),
                                            const Expanded(
                                              child: Text(
                                                'Due to Parse Server security, credential changes require account recreation.',
                                                style: TextStyle(fontSize: 12),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        ElevatedButton(
                                          onPressed: () {
                                            _showRecreateAccountDialog();
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red[400],
                                            foregroundColor: Colors.white,
                                          ),
                                          child: const Text(
                                              'Recreate Account with New Credentials'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ] else ...[
                                _buildDetailRow(
                                    l10n.username, l10n.noAccountCreated),
                                _buildDetailRow(
                                    l10n.password, l10n.noAccountCreated),
                                _buildDetailRow(
                                    l10n.accountStatus, l10n.inactive),
                                const SizedBox(height: 16),
                                // Set Credentials button (Allow for admins or teachers viewing their own profile)
                                if (_canEditCredentials) ...[
                                  ElevatedButton(
                                    onPressed: () {
                                      _showSetCredentialsDialog();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: Text(l10n.setCredentials),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ),

                      // Danger Zone Section
                      const SizedBox(height: 32),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.warning,
                              color: Colors.red,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.dangerZone,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.deleteTeacherWarning,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _showDeleteConfirmationDialog(),
                              icon: const Icon(Icons.delete),
                              label: Text(l10n.deleteTeacher),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPlaceholder() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.grey[400]!,
          width: 2,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_a_photo,
            size: 32,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 4),
          Text(
            'Tap to Add',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            'Photo',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField(
      String label, TextEditingController controller, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            prefixIcon: Icon(icon, color: Colors.blue),
            hintText: 'Enter $label',
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gender',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedGender,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person_outline, color: Colors.blue),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          items: ['Male', 'Female', 'Other'].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedGender = newValue!;
            });
          },
        ),
      ],
    );
  }

  Future<void> _saveBasicInformation() async {
    final l10n = AppLocalizations.of(context)!;

    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Text(l10n.savingChanges),
            ],
          ),
        ),
      );
    }

    try {
      // Validate required fields
      if (_nameController.text.trim().isEmpty) {
        throw Exception(l10n.fullNameRequired);
      }

      print('DEBUG: Starting to save teacher information...');
      print('DEBUG: Teacher ID: ${widget.teacher.objectId}');
      print('DEBUG: New Name: ${_nameController.text.trim()}');
      print('DEBUG: New Gender: $_selectedGender');
      print('DEBUG: New Subject: ${_subjectController.text.trim()}');
      print('DEBUG: New Address: ${_addressController.text.trim()}');

      // Update via HTTP API
      const appId = 'EIbuzFd5v46RVy8iqf3vupM40l4PEcuS773XLUc5';
      const clientKey = 'o35E0eNihkhwtlOtwBoIASmO2htYsbAeL1BpnUdE';

      final headers = {
        'X-Parse-Application-Id': appId,
        'X-Parse-Client-Key': clientKey,
        'Content-Type': 'application/json',
      };

      final requestBody = jsonEncode({
        'fullName': _nameController.text.trim(),
        'gender': _selectedGender,
        'subject': _subjectController.text.trim(),
        'address': _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        'yearsOfExperience':
            int.tryParse(_experienceController.text.trim()) ?? 0,
        'hourlyRate': double.tryParse(_hourlyPayController.text.trim()) ?? 0.0,
        'lastModified': {
          '__type': 'Date',
          'iso': DateTime.now().toIso8601String(),
        },
      });

      print('DEBUG: Request body: $requestBody');

      final response = await http.put(
        Uri.parse(
            'https://parseapi.back4app.com/classes/Teacher/${widget.teacher.objectId}'),
        headers: headers,
        body: requestBody,
      );

      print('DEBUG: Response status: ${response.statusCode}');
      print('DEBUG: Response body: ${response.body}');

      if (response.statusCode == 200) {
        print('DEBUG: ✅ Teacher information updated successfully');

        // Update local current values for display and cache them
        final teacherId = widget.teacher.objectId;
        setState(() {
          _currentName = _nameController.text.trim();
          _currentGender = _selectedGender;
          _currentSubject = _subjectController.text.trim();
          _currentAddress = _addressController.text.trim();
          _currentExperience = _experienceController.text.trim();
          _currentHourlyPay = _hourlyPayController.text.trim();
          _isEditingBasicInfo = false;
          _hasLocalChanges = true; // Mark that we have local changes

          // Cache the updated data to persist across widget rebuilds
          _teacherDataCache[teacherId] = {
            'name': _currentName,
            'gender': _currentGender,
            'subject': _currentSubject,
            'address': _currentAddress,
            'experience': _currentExperience,
            'hourlyPay': _currentHourlyPay,
          };

          print('DEBUG: Cached data for teacher $teacherId');
          print('DEBUG: Cached address: "$_currentAddress"');
        });

        // Also save to Hive cache
        await CacheService.saveTeacherDetail(
          teacherId: teacherId,
          teacherData: {
            'name': _currentName,
            'gender': _currentGender,
            'subject': _currentSubject,
            'address': _currentAddress,
            'experience': _currentExperience,
            'hourlyPay': _currentHourlyPay,
          },
          credentialsData: {
            'username': _teacherUsername,
            'password': _teacherPassword,
            'hasUserAccount': _hasUserAccount,
          },
        );

        print('DEBUG: Local state updated with new values');
        print('DEBUG: _currentName: $_currentName');
        print('DEBUG: _currentGender: $_currentGender');
        print('DEBUG: _currentSubject: $_currentSubject');
        print('DEBUG: _currentAddress: $_currentAddress');

        if (mounted) {
          Navigator.pop(context); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.teacherInfoUpdated),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        print('DEBUG: ❌ HTTP request failed');
        print('DEBUG: Status: ${response.statusCode}');
        print('DEBUG: Response: ${response.body}');
        throw Exception(
            'Failed to update teacher information. Status: ${response.statusCode}, Response: ${response.body}');
      }
    } catch (e) {
      print('DEBUG: ❌ Save failed with exception: $e');
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.failedToSaveChanges}: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // NEW: Session-Free Teacher Credential Creation using HTTP API
  Future<void> _createTeacherCredentialsViaHTTP(
      String username, String password) async {
    print('DEBUG: Creating teacher credentials via HTTP API (session-free)...');

    try {
      // Use direct HTTP calls to Parse REST API
      const appId = 'EIbuzFd5v46RVy8iqf3vupM40l4PEcuS773XLUc5';
      const clientKey = 'o35E0eNihkhwtlOtwBoIASmO2htYsbAeL1BpnUdE';

      final headers = {
        'X-Parse-Application-Id': appId,
        'X-Parse-Client-Key': clientKey,
        'Content-Type': 'application/json',
      };

      // Step 1: Create user via REST API (doesn't affect current session)
      final userResponse = await http.post(
        Uri.parse('https://parseapi.back4app.com/users'),
        headers: headers,
        body: jsonEncode({
          'username': username,
          'password': password,
          'email': '$username@school.edu',
          'role': 'teacher',
        }),
      );

      if (userResponse.statusCode == 201) {
        final userData = jsonDecode(userResponse.body);
        final userId = userData['objectId'];

        print('DEBUG: ✅ User created via HTTP: $userId');

        // Step 2: Update Teacher record via REST API
        final teacherResponse = await http.put(
          Uri.parse(
              'https://parseapi.back4app.com/classes/Teacher/${widget.teacher.objectId}'),
          headers: headers,
          body: jsonEncode({
            'userId': {
              '__type': 'Pointer',
              'className': '_User',
              'objectId': userId,
            },
            'username': username,
            'plainPassword': password,
            'hasUserAccount': true,
            'accountCreatedAt': {
              '__type': 'Date',
              'iso': DateTime.now().toIso8601String(),
            },
            'isAccountActive': true,
            'lastPasswordReset': {
              '__type': 'Date',
              'iso': DateTime.now().toIso8601String(),
            },
            'lastModified': {
              '__type': 'Date',
              'iso': DateTime.now().toIso8601String(),
            },
          }),
        );

        if (teacherResponse.statusCode == 200) {
          print('DEBUG: ✅ Teacher record updated successfully');
          print('DEBUG: ✅ Credentials set without session conflicts!');

          // Success! Refresh credentials display
          await _loadTeacherCredentials();

          if (mounted) {
            Navigator.pop(context); // Close loading dialog
            _showCredentialsSetSuccessDialog(username, password);
          }
        } else {
          throw Exception(
              'Failed to update teacher record: ${teacherResponse.body}');
        }
      } else {
        final errorData = jsonDecode(userResponse.body);
        String errorMessage = errorData['error'] ?? 'Failed to create user';

        if (errorMessage.contains('already taken') ||
            errorMessage.contains('already exists')) {
          errorMessage =
              'Username "$username" is already taken. Please choose a different username.';
        }

        throw Exception(errorMessage);
      }
    } catch (e) {
      print('DEBUG: ❌ HTTP creation failed: $e');
      rethrow;
    }
  }

  Future<void> _setManualCredentials(String username, String password) async {
    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Setting credentials...'),
            ],
          ),
        ),
      );
    }

    try {
      // Use the new HTTP-based approach (no session conflicts)
      await _createTeacherCredentialsViaHTTP(username, password);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to set credentials: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showCredentialsSetSuccessDialog(String username, String password) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[600]),
            const SizedBox(width: 8),
            const Text('Credentials Set Successfully'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Login credentials for ${widget.teacher.fullName}:'),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, size: 20, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text('Username: ',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(child: Text(username)),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: username));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Username copied to clipboard')),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.lock, size: 20, color: Colors.orange),
                      const SizedBox(width: 8),
                      const Text('Password: ',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(child: Text(password)),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: password));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Password copied to clipboard')),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Please share these credentials securely with the teacher.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              print(
                  'DEBUG: ✅ Credentials set successfully, admin remains logged in');
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showSetCredentialsDialog() {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    // Generate a suggested username based on teacher's name
    String generateSuggestedUsername() {
      final name = widget.teacher.fullName.toLowerCase();
      final words = name.split(' ');
      if (words.length >= 2) {
        final firstName = words[0];
        final lastName = words.last;
        final timestamp =
            DateTime.now().millisecondsSinceEpoch.toString().substring(8);
        return '${firstName.substring(0, firstName.length.clamp(0, 3))}${lastName.substring(0, lastName.length.clamp(0, 3))}$timestamp';
      } else {
        final timestamp =
            DateTime.now().millisecondsSinceEpoch.toString().substring(8);
        return '${name.replaceAll(' ', '').substring(0, name.length.clamp(0, 6))}$timestamp';
      }
    }

    // Set initial suggested username
    usernameController.text = generateSuggestedUsername();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.admin_panel_settings, color: Colors.blue[600]),
            const SizedBox(width: 8),
            const Text('Set Login Credentials'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Create login credentials for ${widget.teacher.fullName}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.person),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.blue),
                      onPressed: () {
                        usernameController.text = generateSuggestedUsername();
                      },
                      tooltip: 'Generate new suggestion',
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a username';
                    }
                    if (value.length < 3) {
                      return 'Username must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline,
                          color: Colors.blue[600], size: 16),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Tip: Click the refresh icon to generate a new username suggestion',
                          style: TextStyle(fontSize: 11, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon:
                          const Icon(Icons.auto_fix_high, color: Colors.green),
                      onPressed: () {
                        // Generate a simple but secure password
                        final timestamp = DateTime.now()
                            .millisecondsSinceEpoch
                            .toString()
                            .substring(8);
                        passwordController.text = 'Pass$timestamp';
                      },
                      tooltip: 'Generate password',
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 4) {
                      return 'Password must be at least 4 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber,
                          color: Colors.orange[600], size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'This will create a new user account for the teacher. If username exists, please try a different one.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                _setManualCredentials(
                  usernameController.text.trim(),
                  passwordController.text.trim(),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Set Credentials'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock_reset, color: Colors.orange[600]),
            const SizedBox(width: 8),
            const Text('Change Password'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Change password for ${widget.teacher.fullName}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a new password';
                    }
                    if (value.length < 4) {
                      return 'Password must be at least 4 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) {
                    if (value != passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.orange[600], size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'This will update the teacher\'s login password.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                _updatePassword(passwordController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Change Password'),
          ),
        ],
      ),
    );
  }

  void _showChangeUsernameDialog() {
    final usernameController = TextEditingController(text: _teacherUsername);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.person_outline, color: Colors.blue[600]),
            const SizedBox(width: 8),
            const Text('Change Username'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Change username for ${widget.teacher.fullName}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: 'New Username',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a username';
                    }
                    if (value.length < 3) {
                      return 'Username must be at least 3 characters';
                    }
                    if (value == _teacherUsername) {
                      return 'Please enter a different username';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.blue[600], size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'This will update the teacher\'s login username.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                _updateUsername(usernameController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Change Username'),
          ),
        ],
      ),
    );
  }

  void _showCopyCredentialsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.copy, color: Colors.green[600]),
            const SizedBox(width: 8),
            const Text('Copy Credentials'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current login credentials for ${widget.teacher.fullName}:'),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, size: 20, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text('Username: ',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(child: Text(_teacherUsername ?? 'N/A')),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: _teacherUsername ?? ''));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Username copied to clipboard')),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.lock, size: 20, color: Colors.orange),
                      const SizedBox(width: 8),
                      const Text('Password: ',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(child: Text(_teacherPassword ?? 'N/A')),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: _teacherPassword ?? ''));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Password copied to clipboard')),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final credentials =
                                'Username: ${_teacherUsername ?? 'N/A'}\nPassword: ${_teacherPassword ?? 'N/A'}';
                            Clipboard.setData(ClipboardData(text: credentials));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Both credentials copied to clipboard')),
                            );
                          },
                          icon: const Icon(Icons.copy_all, size: 18),
                          label: const Text('Copy Both'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _updatePassword(String newPassword) async {
    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Updating password...'),
            ],
          ),
        ),
      );
    }

    try {
      // Get teacher's userId first
      final query = QueryBuilder<ParseObject>(ParseObject('Teacher'))
        ..whereEqualTo('objectId', widget.teacher.objectId);
      final response = await query.query();

      if (response.success && response.results!.isNotEmpty) {
        final teacher = response.results!.first;
        final userId = teacher.get<ParseObject>('userId')?.objectId;

        if (userId == null) {
          throw Exception('Teacher has no associated user account');
        }

        // Update password via HTTP API (session-free)
        const appId = 'EIbuzFd5v46RVy8iqf3vupM40l4PEcuS773XLUc5';
        const clientKey = 'o35E0eNihkhwtlOtwBoIASmO2htYsbAeL1BpnUdE';

        final headers = {
          'X-Parse-Application-Id': appId,
          'X-Parse-Client-Key': clientKey,
          'Content-Type': 'application/json',
        };

        print('DEBUG: 🔄 Updating both User and Teacher tables');

        // Step 1: Update User account password
        final userResponse = await http.put(
          Uri.parse('https://parseapi.back4app.com/users/$userId'),
          headers: headers,
          body: jsonEncode({
            'password': newPassword,
          }),
        );

        if (userResponse.statusCode == 200) {
          print('DEBUG: ✅ User password updated successfully');

          // Step 2: Update Teacher record with new password
          final teacherResponse = await http.put(
            Uri.parse(
                'https://parseapi.back4app.com/classes/Teacher/${widget.teacher.objectId}'),
            headers: headers,
            body: jsonEncode({
              'plainPassword': newPassword,
              'lastPasswordReset': {
                '__type': 'Date',
                'iso': DateTime.now().toIso8601String(),
              },
              'lastModified': {
                '__type': 'Date',
                'iso': DateTime.now().toIso8601String(),
              },
            }),
          );

          if (teacherResponse.statusCode == 200) {
            print('DEBUG: ✅ Teacher password updated successfully');
            print('DEBUG: ✅ Both User and Teacher records updated');

            // Update local state
            setState(() {
              _teacherPassword = newPassword;
            });

            // Update cache
            await CacheService.saveTeacherCredentials(
              teacherId: widget.teacher.objectId,
              username: _teacherUsername,
              password: newPassword,
              hasUserAccount: _hasUserAccount,
            );

            if (mounted) {
              Navigator.pop(context); // Close loading dialog
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Password updated successfully! Teacher can now login with new password.'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 4),
                ),
              );
            }
          } else {
            throw Exception(
                'Failed to update teacher record: ${teacherResponse.body}');
          }
        } else {
          // Handle ACL error gracefully
          final errorData = jsonDecode(userResponse.body);
          final errorMessage = errorData['error'] ?? userResponse.body;

          print(
              'DEBUG: ❌ User update failed due to ACL restrictions: $errorMessage');

          // If it's an ACL/permission error, update only Teacher record and show info
          if (errorMessage.toString().contains('Cannot modify user') ||
              errorMessage.toString().contains('ACL') ||
              userResponse.statusCode == 403) {
            print(
                'DEBUG: 🔄 ACL restriction detected, updating Teacher record only');

            // Update Teacher record with new password
            final teacherResponse = await http.put(
              Uri.parse(
                  'https://parseapi.back4app.com/classes/Teacher/${widget.teacher.objectId}'),
              headers: headers,
              body: jsonEncode({
                'plainPassword': newPassword,
                'lastPasswordReset': {
                  '__type': 'Date',
                  'iso': DateTime.now().toIso8601String(),
                },
                'lastModified': {
                  '__type': 'Date',
                  'iso': DateTime.now().toIso8601String(),
                },
              }),
            );

            if (teacherResponse.statusCode == 200) {
              print('DEBUG: ✅ Teacher password updated in Teacher record');

              // Update local state
              setState(() {
                _teacherPassword = newPassword;
              });

              if (mounted) {
                Navigator.pop(context); // Close loading dialog
                _showACLRestrictionDialog('password', newPassword);
              }
            } else {
              throw Exception(
                  'Failed to update teacher record: ${teacherResponse.body}');
            }
          } else {
            throw Exception('Failed to update user password: $errorMessage');
          }
        }
      } else {
        throw Exception('Teacher not found');
      }
    } catch (e) {
      print('DEBUG: ❌ Password update failed: $e');
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update password: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _updateUsername(String newUsername) async {
    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Updating username...'),
            ],
          ),
        ),
      );
    }

    try {
      // Get teacher's userId first
      final query = QueryBuilder<ParseObject>(ParseObject('Teacher'))
        ..whereEqualTo('objectId', widget.teacher.objectId);
      final response = await query.query();

      if (response.success && response.results!.isNotEmpty) {
        final teacher = response.results!.first;
        final userId = teacher.get<ParseObject>('userId')?.objectId;

        if (userId == null) {
          throw Exception('Teacher has no associated user account');
        }

        // Update username via HTTP API (session-free)
        const appId = 'EIbuzFd5v46RVy8iqf3vupM40l4PEcuS773XLUc5';
        const clientKey = 'o35E0eNihkhwtlOtwBoIASmO2htYsbAeL1BpnUdE';

        final headers = {
          'X-Parse-Application-Id': appId,
          'X-Parse-Client-Key': clientKey,
          'Content-Type': 'application/json',
        };

        print('DEBUG: 🔄 Updating both User and Teacher tables');

        // Step 1: Update User account username
        final userResponse = await http.put(
          Uri.parse('https://parseapi.back4app.com/users/$userId'),
          headers: headers,
          body: jsonEncode({
            'username': newUsername,
          }),
        );

        if (userResponse.statusCode == 200) {
          print('DEBUG: ✅ User username updated successfully');

          // Step 2: Update Teacher record with new username
          final teacherResponse = await http.put(
            Uri.parse(
                'https://parseapi.back4app.com/classes/Teacher/${widget.teacher.objectId}'),
            headers: headers,
            body: jsonEncode({
              'username': newUsername,
              'lastModified': {
                '__type': 'Date',
                'iso': DateTime.now().toIso8601String(),
              },
            }),
          );

          if (teacherResponse.statusCode == 200) {
            print('DEBUG: ✅ Teacher username updated successfully');
            print('DEBUG: ✅ Both User and Teacher records updated');

            // Update local state
            setState(() {
              _teacherUsername = newUsername;
            });

            // Update cache
            await CacheService.saveTeacherCredentials(
              teacherId: widget.teacher.objectId,
              username: newUsername,
              password: _teacherPassword,
              hasUserAccount: _hasUserAccount,
            );

            if (mounted) {
              Navigator.pop(context); // Close loading dialog
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Username updated successfully! Teacher can now login with new username.'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 4),
                ),
              );
            }
          } else {
            throw Exception(
                'Failed to update teacher record: ${teacherResponse.body}');
          }
        } else {
          // Handle ACL error gracefully
          final errorData = jsonDecode(userResponse.body);
          final errorMessage = errorData['error'] ?? userResponse.body;

          print(
              'DEBUG: ❌ User update failed due to ACL restrictions: $errorMessage');

          // If it's an ACL/permission error, update only Teacher record and show info
          if (errorMessage.toString().contains('Cannot modify user') ||
              errorMessage.toString().contains('ACL') ||
              userResponse.statusCode == 403) {
            print(
                'DEBUG: 🔄 ACL restriction detected, updating Teacher record only');

            // Update Teacher record with new username
            final teacherResponse = await http.put(
              Uri.parse(
                  'https://parseapi.back4app.com/classes/Teacher/${widget.teacher.objectId}'),
              headers: headers,
              body: jsonEncode({
                'username': newUsername,
                'lastModified': {
                  '__type': 'Date',
                  'iso': DateTime.now().toIso8601String(),
                },
              }),
            );

            if (teacherResponse.statusCode == 200) {
              print('DEBUG: ✅ Teacher username updated in Teacher record');

              // Update local state
              setState(() {
                _teacherUsername = newUsername;
              });

              if (mounted) {
                Navigator.pop(context); // Close loading dialog
                _showACLRestrictionDialog('username', newUsername);
              }
            } else {
              throw Exception(
                  'Failed to update teacher record: ${teacherResponse.body}');
            }
          } else {
            throw Exception('Failed to update user username: $errorMessage');
          }
        }
      } else {
        throw Exception('Teacher not found');
      }
    } catch (e) {
      print('DEBUG: ❌ Username update failed: $e');
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update username: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showRecreateAccountDialog() {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.refresh, color: Colors.red[600]),
            const SizedBox(width: 8),
            const Text('Recreate Account'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red[600], size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'This will DELETE the existing account and create a new one.',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Create new account for ${widget.teacher.fullName}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: 'New Username',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a username';
                    }
                    if (value.length < 3) {
                      return 'Username must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 4) {
                      return 'Password must be at least 4 characters';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                _recreateTeacherAccount(
                  usernameController.text.trim(),
                  passwordController.text.trim(),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Recreate Account'),
          ),
        ],
      ),
    );
  }

  Future<void> _recreateTeacherAccount(
      String newUsername, String newPassword) async {
    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Recreating account...'),
            ],
          ),
        ),
      );
    }

    try {
      // Get current teacher data
      final query = QueryBuilder<ParseObject>(ParseObject('Teacher'))
        ..whereEqualTo('objectId', widget.teacher.objectId);
      final response = await query.query();

      if (response.success && response.results!.isNotEmpty) {
        final teacher = response.results!.first;
        final oldUserId = teacher.get<ParseObject>('userId')?.objectId;

        // Step 1: Delete old user account if exists
        if (oldUserId != null) {
          try {
            const appId = 'EIbuzFd5v46RVy8iqf3vupM40l4PEcuS773XLUc5';
            const clientKey = 'o35E0eNihkhwtlOtwBoIASmO2htYsbAeL1BpnUdE';

            final headers = {
              'X-Parse-Application-Id': appId,
              'X-Parse-Client-Key': clientKey,
              'Content-Type': 'application/json',
            };

            await http.delete(
              Uri.parse('https://parseapi.back4app.com/users/$oldUserId'),
              headers: headers,
            );
            print('DEBUG: 🗑️ Old user account deleted');
          } catch (e) {
            print('DEBUG: ⚠️ Could not delete old user account: $e');
          }
        }

        // Step 2: Create new user account using our session-free approach
        await _createTeacherCredentialsViaHTTP(newUsername, newPassword);

        if (mounted) {
          Navigator.pop(context); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Account recreated successfully! Teacher can now login with new credentials.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 5),
            ),
          );
        }
      } else {
        throw Exception('Teacher not found');
      }
    } catch (e) {
      print('DEBUG: ❌ Account recreation failed: $e');
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to recreate account: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showUpdatePhotoDialog() {
    final urlController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.camera_alt, color: Colors.blue[600]),
            const SizedBox(width: 8),
            const Text('Update Teacher Photo'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Update photo for ${widget.teacher.fullName}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: 'Photo URL',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link),
                    hintText: 'https://example.com/photo.jpg',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a photo URL';
                    }
                    final uri = Uri.tryParse(value);
                    if (uri == null || !uri.hasAbsolutePath) {
                      return 'Please enter a valid URL';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.blue[600], size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Enter a direct link to the teacher\'s photo. The photo should be publicly accessible.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                _updateTeacherPhoto(urlController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Update Photo'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateTeacherPhoto(String photoUrl) async {
    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Updating photo...'),
            ],
          ),
        ),
      );
    }

    try {
      // Update photo via HTTP API
      const appId = 'EIbuzFd5v46RVy8iqf3vupM40l4PEcuS773XLUc5';
      const clientKey = 'o35E0eNihkhwtlOtwBoIASmO2htYsbAeL1BpnUdE';

      final headers = {
        'X-Parse-Application-Id': appId,
        'X-Parse-Client-Key': clientKey,
        'Content-Type': 'application/json',
      };

      // Update Teacher record with new photo
      final response = await http.put(
        Uri.parse(
            'https://parseapi.back4app.com/classes/Teacher/${widget.teacher.objectId}'),
        headers: headers,
        body: jsonEncode({
          'photo': photoUrl,
          'lastModified': {
            '__type': 'Date',
            'iso': DateTime.now().toIso8601String(),
          },
        }),
      );

      if (response.statusCode == 200) {
        print('DEBUG: ✅ Photo updated successfully');

        // Clear the image cache for this teacher to force fresh load
        try {
          final box = await Hive.openBox('teacherImages');
          await box.delete(widget.teacher.objectId);
          print(
              '🗑️ Cleared image cache for teacher after photo update: ${widget.teacher.objectId}');

          // Reset cached image bytes and reload the image
          setState(() {
            _cachedImageBytes = null;
          });

          // Reload the image with new URL
          await _loadTeacherImage();
        } catch (e) {
          print('❌ Error clearing image cache after photo update: $e');
        }

        if (mounted) {
          Navigator.pop(context); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo updated successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        throw Exception('Failed to update photo: ${response.body}');
      }
    } catch (e) {
      print('DEBUG: ❌ Photo update failed: $e');
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update photo: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showPhotoPickerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.camera_alt, color: Colors.blue[600]),
            const SizedBox(width: 8),
            const Text('Update Teacher Photo'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choose how to update photo for ${widget.teacher.fullName}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _pickImageFromCamera();
                  },
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _pickImageFromGallery();
                  },
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showUpdatePhotoDialog(); // Fall back to URL method
              },
              icon: const Icon(Icons.link),
              label: const Text('Enter URL Instead'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImageFromCamera() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        await _uploadImageFile(File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to take photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        await _uploadImageFile(File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to select photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadImageFile(File imageFile) async {
    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Uploading photo...'),
            ],
          ),
        ),
      );
    }

    try {
      // Create a ParseFile from the image
      final parseFile = ParseFile(imageFile);

      // Upload the file to Parse Server
      final response = await parseFile.save();

      if (response.success) {
        final photoUrl = parseFile.url;
        print('DEBUG: ✅ Image uploaded successfully: $photoUrl');

        // Update the teacher record with the new photo URL
        await _updateTeacherPhotoUrl(photoUrl!);
      } else {
        throw Exception('Failed to upload image: ${response.error?.message}');
      }
    } catch (e) {
      print('DEBUG: ❌ Image upload failed: $e');
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload photo: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _updateTeacherPhotoUrl(String photoUrl) async {
    try {
      // Update via HTTP API
      const appId = 'EIbuzFd5v46RVy8iqf3vupM40l4PEcuS773XLUc5';
      const clientKey = 'o35E0eNihkhwtlOtwBoIASmO2htYsbAeL1BpnUdE';

      final headers = {
        'X-Parse-Application-Id': appId,
        'X-Parse-Client-Key': clientKey,
        'Content-Type': 'application/json',
      };

      // Update Teacher record with new photo
      final response = await http.put(
        Uri.parse(
            'https://parseapi.back4app.com/classes/Teacher/${widget.teacher.objectId}'),
        headers: headers,
        body: jsonEncode({
          'photo': photoUrl,
          'lastModified': {
            '__type': 'Date',
            'iso': DateTime.now().toIso8601String(),
          },
        }),
      );

      if (response.statusCode == 200) {
        print('DEBUG: ✅ Teacher photo URL updated successfully');

        // Clear the image cache for this teacher to force fresh load
        try {
          final box = await Hive.openBox('teacherImages');
          await box.delete(widget.teacher.objectId);
          print(
              '🗑️ Cleared image cache for teacher after URL photo update: ${widget.teacher.objectId}');

          // Reset cached image bytes and reload the image
          setState(() {
            _cachedImageBytes = null;
          });

          // Reload the image with new URL
          await _loadTeacherImage();
        } catch (e) {
          print('❌ Error clearing image cache after URL photo update: $e');
        }

        if (mounted) {
          Navigator.pop(context); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo updated successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        throw Exception('Failed to update teacher photo: ${response.body}');
      }
    } catch (e) {
      print('DEBUG: ❌ Teacher photo update failed: $e');
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update photo: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _showDeleteConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete Teacher'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Are you sure you want to delete "${widget.teacher.fullName}"?'),
              const SizedBox(height: 12),
              const Text(
                'This action will permanently remove:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Teacher profile and information'),
              const Text('• Login credentials'),
              const Text('• Schedule assignments'),
              const Text('• All associated data'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'This action cannot be undone!',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteTeacher();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteTeacher() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Dialog(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Deleting teacher...'),
              ],
            ),
          ),
        );
      },
    );

    try {
      // 1. Delete from _User table if has user account
      if (_hasUserAccount && _teacherUsername != null) {
        print('DEBUG: Deleting user account: $_teacherUsername');
        try {
          const appId = 'EIbuzFd5v46RVy8iqf3vupM40l4PEcuS773XLUc5';
          const clientKey = 'uqiOPXHXvzSoBZVlOH0rNHGZvL2aKFhKcUqeKQb9';

          final headers = {
            'X-Parse-Application-Id': appId,
            'X-Parse-Client-Key': clientKey,
            'Content-Type': 'application/json',
          };

          await http.delete(
            Uri.parse('https://parseapi.back4app.com/users/$_teacherUsername'),
            headers: headers,
          );
          print('DEBUG: ✅ User account deleted successfully');
        } catch (e) {
          print('DEBUG: ❌ Failed to delete user account: $e');
        }
      }

      // 2. Delete all schedule assignments for this teacher
      print(
          'DEBUG: Deleting schedule assignments for teacher: ${widget.teacher.objectId}');
      final teacherPointer = ParseObject('Teacher')
        ..objectId = widget.teacher.objectId;
      final scheduleQuery = QueryBuilder<ParseObject>(ParseObject('Schedule'))
        ..whereEqualTo('teacher', teacherPointer);

      final scheduleResponse = await scheduleQuery.query();
      if (scheduleResponse.success && scheduleResponse.results != null) {
        for (var schedule in scheduleResponse.results!) {
          await schedule.delete();
        }
        print('DEBUG: ✅ Schedule assignments deleted successfully');
      }

      // 3. Delete from Teacher table
      print('DEBUG: Deleting teacher record: ${widget.teacher.objectId}');
      final teacherQuery = QueryBuilder<ParseObject>(ParseObject('Teacher'))
        ..whereEqualTo('objectId', widget.teacher.objectId);

      final teacherResponse = await teacherQuery.query();
      if (teacherResponse.success &&
          teacherResponse.results != null &&
          teacherResponse.results!.isNotEmpty) {
        final teacherRecord = teacherResponse.results!.first;
        final deleteResponse = await teacherRecord.delete();

        if (deleteResponse.success) {
          print('DEBUG: ✅ Teacher deleted successfully');

          // Close loading dialog
          if (mounted) {
            Navigator.pop(context);

            // Show success message and navigate back
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Teacher deleted successfully'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );

            // Navigate back to teacher list
            Navigator.pop(context);
          }
        } else {
          throw Exception(
              'Failed to delete teacher: ${deleteResponse.error?.message}');
        }
      } else {
        throw Exception('Teacher record not found');
      }
    } catch (e) {
      print('DEBUG: ❌ Teacher deletion failed: $e');

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete teacher: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showACLRestrictionDialog(String type, String newValue) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange[600]),
            const SizedBox(width: 8),
            const Text('Partial Update Complete'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The $type has been updated in the Teacher record but could not be updated in the User account due to Parse Server security restrictions.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.orange[600], size: 20),
                      const SizedBox(width: 8),
                      const Text('What this means:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('• The new $type is saved: $newValue'),
                  const Text('• Teacher cannot login with new credentials yet'),
                  const Text(
                      '• Account recreation is required for login access'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline,
                          color: Colors.blue[600], size: 20),
                      const SizedBox(width: 8),
                      const Text('Solution:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                      'Use "Recreate Account with New Credentials" button below to create a working login account.'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showRecreateAccountDialog();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Recreate Account Now'),
          ),
        ],
      ),
    );
  }
}
