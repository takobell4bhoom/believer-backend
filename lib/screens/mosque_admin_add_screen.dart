import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_provider.dart';
import '../data/mosque_provider.dart';
import '../models/mosque_model.dart';
import '../models/prayer_time_configuration_options.dart';
import '../navigation/mosque_detail_route_args.dart';
import '../navigation/app_routes.dart';
import '../services/api_client.dart';
import '../services/browser_image_picker.dart';
import '../services/location_preferences_service.dart';
import '../services/mosque_service.dart';
import '../theme/app_colors.dart';
import '../widgets/mosque_image_upload_field.dart';
import 'mosque_admin_edit_screen.dart';

class MosqueAdminAddScreen extends ConsumerStatefulWidget {
  const MosqueAdminAddScreen({
    super.key,
    this.mosqueService,
    this.imagePicker,
    this.locationPreferencesService,
  });

  final MosqueService? mosqueService;
  final BrowserImagePicker? imagePicker;
  final LocationPreferencesService? locationPreferencesService;

  @override
  ConsumerState<MosqueAdminAddScreen> createState() =>
      _MosqueAdminAddScreenState();
}

class _MosqueAdminAddScreenState extends ConsumerState<MosqueAdminAddScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _contactNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController(text: 'Bengaluru');
  final _stateCtrl = TextEditingController(text: 'Karnataka');
  final _countryCtrl = TextEditingController(text: 'India');
  final _zipCtrl = TextEditingController();
  final _locationSearchCtrl = TextEditingController();
  final _latitudeCtrl = TextEditingController(text: '12.9716');
  final _longitudeCtrl = TextEditingController(text: '77.5946');
  final Map<String, TextEditingController> _offsetCtrls = {
    for (final prayer in prayerOffsetOrder)
      prayer: TextEditingController(text: '0'),
  };

  late final MosqueService _mosqueService;
  late final BrowserImagePicker _imagePicker;
  late final LocationPreferencesService _locationPreferencesService;

  String _sect = 'Sunni';
  int _calculationMethod = 3;
  String _school = 'standard';
  bool _prayerTimingsEnabled = true;
  bool _womenArea = true;
  bool _parking = true;
  bool _wudu = true;
  bool _wheelchair = false;
  bool _kidsArea = false;
  bool _ramadanIftar = false;

  bool _isSubmitting = false;
  bool _isUploadingImage = false;
  MosqueImageUploadFile? _pendingImageUpload;
  String? _imageUploadErrorText;
  MosqueModel? _createdMosque;
  List<String> _uploadedImageUrls = <String>[];
  Timer? _locationSearchDebounce;
  List<LocationSuggestion> _locationSuggestions =
      const <LocationSuggestion>[];
  LocationSuggestion? _selectedLocationSuggestion;
  String? _locationSearchFeedback;
  bool _locationSearchFeedbackIsError = false;
  bool _isSearchingLocation = false;
  bool _hasGoogleAutoFilledCoordinates = false;
  bool _hasManualCoordinateOverride = false;
  bool _isApplyingGoogleCoordinates = false;
  String? _coordinateStatusText;
  bool _coordinateStatusIsManualOverride = false;

  @override
  void initState() {
    super.initState();
    _mosqueService = widget.mosqueService ?? MosqueService();
    _imagePicker = widget.imagePicker ?? createBrowserImagePicker();
    _locationPreferencesService =
        widget.locationPreferencesService ?? LocationPreferencesService();
    _latitudeCtrl.addListener(_handleCoordinateEdited);
    _longitudeCtrl.addListener(_handleCoordinateEdited);
  }

  @override
  void dispose() {
    _locationSearchDebounce?.cancel();
    _nameCtrl.dispose();
    _contactNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _websiteCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _countryCtrl.dispose();
    _zipCtrl.dispose();
    _locationSearchCtrl.dispose();
    _latitudeCtrl.dispose();
    _longitudeCtrl.dispose();
    for (final controller in _offsetCtrls.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<String> _selectedFacilities() {
    return <String>[
      if (_womenArea) 'women_area',
      if (_parking) 'parking',
      if (_wudu) 'wudu',
      if (_wheelchair) 'wheelchair',
      if (_kidsArea) 'kids_area',
      if (_ramadanIftar) 'ramadan_iftar',
    ];
  }

  Map<String, dynamic> _prayerTimeConfigPayload() {
    return <String, dynamic>{
      'enabled': _prayerTimingsEnabled,
      'calculationMethod': _calculationMethod,
      'school': _school,
      'adjustments': <String, int>{
        for (final prayer in prayerOffsetOrder)
          prayer: int.tryParse(_offsetCtrls[prayer]!.text.trim()) ?? 0,
      },
    };
  }

  String get _primaryImageUrl =>
      _uploadedImageUrls.isNotEmpty ? _uploadedImageUrls.first : '';

  bool get _hasReachedImageLimit =>
      _uploadedImageUrls.length >= MosqueService.maxMosqueImages;

  String get _coordinateHelperText {
    if (_hasManualCoordinateOverride) {
      return 'Manual value will be saved.';
    }
    if (_hasGoogleAutoFilledCoordinates) {
      return 'Auto-filled from Google Maps. You can edit this.';
    }
    return 'Enter manually or use Google Maps search above.';
  }

  void _handleCoordinateEdited() {
    if (_isApplyingGoogleCoordinates ||
        !_hasGoogleAutoFilledCoordinates ||
        _hasManualCoordinateOverride) {
      return;
    }

    setState(() {
      _hasManualCoordinateOverride = true;
      _coordinateStatusIsManualOverride = true;
      _coordinateStatusText =
          'Coordinates were auto-filled from Google Maps and then edited manually. Your visible values will be saved.';
    });
  }

  Future<void> _searchLocationSuggestions(String rawValue) async {
    final query = rawValue.trim();
    _locationSearchDebounce?.cancel();

    if (_selectedLocationSuggestion != null &&
        _selectedLocationSuggestion!.label.toLowerCase() != query.toLowerCase()) {
      setState(() => _selectedLocationSuggestion = null);
    }

    if (query.length < 2) {
      setState(() {
        _locationSuggestions = const <LocationSuggestion>[];
        _isSearchingLocation = false;
        _locationSearchFeedback = query.isEmpty
            ? 'Search Google Maps for a mosque or place to auto-fill coordinates.'
            : 'Enter at least 2 characters to search.';
        _locationSearchFeedbackIsError = false;
      });
      return;
    }

    setState(() {
      _isSearchingLocation = true;
      _locationSearchFeedback = null;
      _locationSearchFeedbackIsError = false;
    });

    _locationSearchDebounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final results =
            await _locationPreferencesService.searchLocations(query);
        if (!mounted || _locationSearchCtrl.text.trim() != query) {
          return;
        }

        setState(() {
          _locationSuggestions = results;
          _isSearchingLocation = false;
          _locationSearchFeedback = results.isEmpty
              ? 'No Google Maps matches yet. You can still enter coordinates manually.'
              : null;
          _locationSearchFeedbackIsError = false;
        });
      } catch (_) {
        if (!mounted || _locationSearchCtrl.text.trim() != query) {
          return;
        }

        setState(() {
          _locationSuggestions = const <LocationSuggestion>[];
          _isSearchingLocation = false;
          _locationSearchFeedback =
              'Google Maps search is unavailable right now. You can still enter coordinates manually.';
          _locationSearchFeedbackIsError = true;
        });
      }
    });
  }

  void _selectLocationSuggestion(LocationSuggestion suggestion) {
    _isApplyingGoogleCoordinates = true;
    _latitudeCtrl.text = suggestion.latitude.toStringAsFixed(6);
    _longitudeCtrl.text = suggestion.longitude.toStringAsFixed(6);
    _isApplyingGoogleCoordinates = false;

    if (_addressCtrl.text.trim().isEmpty) {
      _addressCtrl.text = suggestion.label;
    }

    setState(() {
      _selectedLocationSuggestion = suggestion;
      _locationSuggestions = const <LocationSuggestion>[];
      _locationSearchCtrl.value = TextEditingValue(
        text: suggestion.label,
        selection: TextSelection.collapsed(offset: suggestion.label.length),
      );
      _locationSearchFeedback = null;
      _locationSearchFeedbackIsError = false;
      _hasGoogleAutoFilledCoordinates = true;
      _hasManualCoordinateOverride = false;
      _coordinateStatusIsManualOverride = false;
      _coordinateStatusText =
          'Coordinates auto-filled from Google Maps. You can edit latitude and longitude before saving.';
    });
  }

  Future<void> _pickImage() async {
    try {
      if (_hasReachedImageLimit) {
        _showMessage('You can upload up to 10 mosque images for now.');
        return;
      }

      final pickedImage = await _imagePicker.pickImage();
      if (pickedImage == null) {
        _showMessage(
          'Image picking is available on the browser upload flow in this MVP.',
        );
        return;
      }

      if (!isSupportedMosqueImageFile(pickedImage)) {
        setState(() {
          _imageUploadErrorText = 'Upload a JPG, PNG, or WebP image.';
          _pendingImageUpload = null;
        });
        return;
      }

      setState(() {
        _pendingImageUpload = MosqueImageUploadFile(
          fileName: pickedImage.fileName,
          bytes: pickedImage.bytes,
          contentType: pickedImage.contentType,
        );
        _imageUploadErrorText = null;
      });
    } catch (_) {
      _showMessage('Unable to read the selected image.');
    }
  }

  Future<void> _uploadSelectedImage() async {
    final pendingUpload = _pendingImageUpload;
    if (_isUploadingImage || pendingUpload == null) {
      return;
    }

    final session = ref.read(authProvider).valueOrNull;
    final token = session?.accessToken;
    if (token == null || token.isEmpty) {
      _showMessage('Please log in with an admin account first.');
      return;
    }

    setState(() {
      _isUploadingImage = true;
      _imageUploadErrorText = null;
    });

    try {
      final uploadedImage = await _mosqueService.uploadMosqueImage(
        file: pendingUpload,
        bearerToken: token,
      );
      if (!mounted) return;

      setState(() {
        _uploadedImageUrls = {
          ..._uploadedImageUrls,
          uploadedImage.imageUrl,
        }.take(MosqueService.maxMosqueImages).toList(growable: false);
        _pendingImageUpload = null;
      });
      _showMessage('Image uploaded and ready to use.');
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _imageUploadErrorText = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _imageUploadErrorText = 'Unable to upload the selected image.';
      });
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  void _clearSelectedImage() {
    if (_isUploadingImage) {
      return;
    }

    setState(() {
      _pendingImageUpload = null;
      _imageUploadErrorText = null;
    });
  }

  void _removeUploadedImageAt(int index) {
    if (_isUploadingImage || index < 0 || index >= _uploadedImageUrls.length) {
      return;
    }

    setState(() {
      final nextImages = [..._uploadedImageUrls]..removeAt(index);
      _uploadedImageUrls = nextImages;
    });
  }

  void _makePrimaryImageAt(int index) {
    if (index <= 0 || index >= _uploadedImageUrls.length) {
      return;
    }

    setState(() {
      final nextImages = [..._uploadedImageUrls];
      final selected = nextImages.removeAt(index);
      nextImages.insert(0, selected);
      _uploadedImageUrls = nextImages;
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_pendingImageUpload != null) {
      _showMessage('Upload the selected image before saving the mosque.');
      return;
    }

    final session = ref.read(authProvider).valueOrNull;
    final token = session?.accessToken;
    if (token == null || token.isEmpty) {
      _showMessage('Please log in with an admin account first.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final created = await _mosqueService.createMosque(
        bearerToken: token,
        payload: {
          'name': _nameCtrl.text.trim(),
          'addressLine': _addressCtrl.text.trim(),
          'city': _cityCtrl.text.trim(),
          'state': _stateCtrl.text.trim(),
          'country': _countryCtrl.text.trim(),
          'postalCode': _zipCtrl.text.trim(),
          'latitude': double.parse(_latitudeCtrl.text.trim()),
          'longitude': double.parse(_longitudeCtrl.text.trim()),
          'contactName': _contactNameCtrl.text.trim(),
          'contactPhone': _phoneCtrl.text.trim(),
          'contactEmail': _emailCtrl.text.trim(),
          'websiteUrl': _websiteCtrl.text.trim(),
          'imageUrl': _primaryImageUrl,
          'imageUrls': _uploadedImageUrls,
          'sect': _sect,
          'prayerTimeConfig': _prayerTimeConfigPayload(),
          'facilities': _selectedFacilities(),
        },
      );

      ref.read(mosqueProvider.notifier).addMosque(created);
      if (!mounted) return;

      setState(() => _createdMosque = created);
      _showMessage('Mosque created successfully.');
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Unable to create mosque right now.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _openCreatedMosque(MosqueModel mosque) {
    Navigator.of(context).pushNamed(
      AppRoutes.mosqueDetail,
      arguments: MosqueDetailRouteArgs.fromMosque(mosque),
    );
  }

  void _openManageMosque(MosqueModel mosque) {
    Navigator.of(context).pushNamed(
      AppRoutes.adminEditMosque,
      arguments: MosqueAdminEditRouteArgs(mosque: mosque),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final session = authState.valueOrNull;
    final currentUser = session?.user;

    if (authState.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (currentUser == null) {
      return _AccessScaffold(
        title: 'Admin Add Mosque',
        message: 'Log in with an admin account to create a mosque.',
        primaryLabel: 'Go to Login',
        onPrimary: () => Navigator.of(context).pushReplacementNamed(
          AppRoutes.login,
        ),
      );
    }

    if (currentUser.role != 'admin') {
      return _AccessScaffold(
        title: 'Admin Add Mosque',
        message:
            'This MVP write flow is restricted to persisted admin accounts.',
        primaryLabel: 'Back Home',
        onPrimary: () => Navigator.of(context).pushReplacementNamed(
          AppRoutes.home,
        ),
      );
    }

    final previewMosques =
        ref.watch(mosqueProvider).valueOrNull ?? const <MosqueModel>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TopBar(
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Add Mosque',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Create the mosque first, including live prayer-time configuration and image uploads. Events and broadcasts now move into owned-mosque management after creation.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.mutedText,
                  ),
                ),
                const SizedBox(height: 14),
                _CardSection(
                  title: 'Basic Information',
                  child: Column(
                    children: [
                      _InputField(
                        label: 'Mosque Name',
                        controller: _nameCtrl,
                        validator: _required,
                      ),
                      const SizedBox(height: 10),
                      _InputField(
                        label: 'Primary Contact',
                        controller: _contactNameCtrl,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _DropdownField<String>(
                              label: 'Sect',
                              value: _sect,
                              items: const <String>[
                                'Sunni',
                                'Shia',
                                'Mixed',
                                'Community',
                              ],
                              onChanged: (value) =>
                                  setState(() => _sect = value ?? _sect),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _InputField(
                              label: 'Phone',
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _InputField(
                              label: 'Email',
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              validator: _optionalEmail,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _InputField(
                              label: 'Website',
                              controller: _websiteCtrl,
                              keyboardType: TextInputType.url,
                              validator: _optionalUrl,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      MosqueImageUploadField(
                        imageUrls: _uploadedImageUrls,
                        pendingImageBytes: _pendingImageUpload?.bytes,
                        pendingFileName: _pendingImageUpload?.fileName,
                        errorText: _imageUploadErrorText,
                        isUploading: _isUploadingImage,
                        onPickImage: _pickImage,
                        onUploadImage: _uploadSelectedImage,
                        onClearSelection: _clearSelectedImage,
                        onRemoveImage: _removeUploadedImageAt,
                        onMakePrimary: _makePrimaryImageAt,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _CardSection(
                  title: 'Location',
                  child: Column(
                    children: [
                      _LocationSearchField(
                        key: const ValueKey('admin-add-location-search'),
                        controller: _locationSearchCtrl,
                        onChanged: _searchLocationSuggestions,
                      ),
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Search Google Maps for a mosque or place to auto-fill coordinates. You can still review the address fields and edit latitude/longitude manually.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.mutedText,
                          ),
                        ),
                      ),
                      if (_isSearchingLocation ||
                          _locationSuggestions.isNotEmpty ||
                          _locationSearchFeedback != null) ...[
                        const SizedBox(height: 10),
                        _LocationSuggestionPanel(
                          isSearching: _isSearchingLocation,
                          suggestions: _locationSuggestions,
                          feedback: _locationSearchFeedback,
                          feedbackIsError: _locationSearchFeedbackIsError,
                          selectedSuggestion: _selectedLocationSuggestion,
                          onSelectSuggestion: _selectLocationSuggestion,
                        ),
                      ],
                      if (_coordinateStatusText != null) ...[
                        const SizedBox(height: 10),
                        _CoordinateStatusCard(
                          message: _coordinateStatusText!,
                          manualOverride: _coordinateStatusIsManualOverride,
                        ),
                      ],
                      const SizedBox(height: 10),
                      _InputField(
                        label: 'Address',
                        controller: _addressCtrl,
                        validator: _required,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _InputField(
                              label: 'City',
                              controller: _cityCtrl,
                              validator: _required,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _InputField(
                              label: 'State',
                              controller: _stateCtrl,
                              validator: _required,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _InputField(
                              label: 'Country',
                              controller: _countryCtrl,
                              validator: _required,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _InputField(
                              label: 'Postal Code',
                              controller: _zipCtrl,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _InputField(
                              label: 'Latitude',
                              controller: _latitudeCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                signed: true,
                                decimal: true,
                              ),
                              validator: _latitudeValidator,
                              helperText: _coordinateHelperText,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _InputField(
                              label: 'Longitude',
                              controller: _longitudeCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                signed: true,
                                decimal: true,
                              ),
                              validator: _longitudeValidator,
                              helperText: _coordinateHelperText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _CardSection(
                  title: 'Prayer Configuration and Facilities',
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _DropdownField<int>(
                              label: 'Calculation Method',
                              value: _calculationMethod,
                              items: prayerTimeMethodOptions
                                  .map((option) => option.id)
                                  .toList(growable: false),
                              labelBuilder: (value) {
                                final option = prayerTimeMethodOptions
                                    .where((item) => item.id == value)
                                    .first;
                                return option.label;
                              },
                              onChanged: (value) => setState(
                                () => _calculationMethod =
                                    value ?? _calculationMethod,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _DropdownField<String>(
                              label: 'School / Madhab',
                              value: _school,
                              items: prayerSchoolOptions,
                              labelBuilder: prayerSchoolLabel,
                              onChanged: (value) => setState(
                                () => _school = value ?? _school,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Prayer timings enabled',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryText,
                          ),
                        ),
                        subtitle: const Text(
                          'Disable only if this mosque should hide live prayer timings for now.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.mutedText,
                          ),
                        ),
                        value: _prayerTimingsEnabled,
                        onChanged: (value) => setState(
                          () => _prayerTimingsEnabled = value,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Minute offsets',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Use small +/- minute tuning only when the mosque intentionally differs from the selected method.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.mutedText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: prayerOffsetOrder
                            .map(
                              (prayer) => SizedBox(
                                width: 140,
                                child: _InputField(
                                  label: '${prayerOffsetLabel(prayer)} Offset',
                                  controller: _offsetCtrls[prayer]!,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    signed: true,
                                  ),
                                  validator: _minuteOffsetValidator,
                                  helperText: 'Minutes',
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _ToggleChip(
                              text: 'Women Prayer Area',
                              value: _womenArea,
                              onTap: () =>
                                  setState(() => _womenArea = !_womenArea),
                            ),
                            _ToggleChip(
                              text: 'Parking',
                              value: _parking,
                              onTap: () => setState(() => _parking = !_parking),
                            ),
                            _ToggleChip(
                              text: 'Wudu',
                              value: _wudu,
                              onTap: () => setState(() => _wudu = !_wudu),
                            ),
                            _ToggleChip(
                              text: 'Wheelchair',
                              value: _wheelchair,
                              onTap: () => setState(
                                () => _wheelchair = !_wheelchair,
                              ),
                            ),
                            _ToggleChip(
                              text: 'Kids Area',
                              value: _kidsArea,
                              onTap: () =>
                                  setState(() => _kidsArea = !_kidsArea),
                            ),
                            _ToggleChip(
                              text: 'Ramadan Iftar',
                              value: _ramadanIftar,
                              onTap: () => setState(
                                () => _ramadanIftar = !_ramadanIftar,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_createdMosque != null) ...[
                  const SizedBox(height: 12),
                  _SuccessCard(
                    mosque: _createdMosque!,
                    onOpenMosque: () => _openCreatedMosque(_createdMosque!),
                    onManageMosque: () => _openManageMosque(_createdMosque!),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const ValueKey('admin-add-mosque-submit'),
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      _isSubmitting ? 'Creating...' : 'Create Mosque',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context)
                        .pushNamed(AppRoutes.mosquesAndEvents),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      side: const BorderSide(color: AppColors.accent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Open Mosque Discovery',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const _SectionTitle(title: 'DISCOVERY PREVIEW'),
                const SizedBox(height: 10),
                Column(
                  children: previewMosques
                      .take(5)
                      .map(
                        (mosque) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _MosqueListCard(item: mosque),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Required';
    return null;
  }

  String? _optionalEmail(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(text)) {
      return 'Enter a valid email';
    }
    return null;
  }

  String? _optionalUrl(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'Enter a valid URL';
    }
    return null;
  }

  String? _latitudeValidator(String? value) {
    final text = (value ?? '').trim();
    final parsed = double.tryParse(text);
    if (parsed == null) return 'Enter latitude';
    if (parsed < -90 || parsed > 90) {
      return 'Latitude must be between -90 and 90';
    }
    return null;
  }

  String? _longitudeValidator(String? value) {
    final text = (value ?? '').trim();
    final parsed = double.tryParse(text);
    if (parsed == null) return 'Enter longitude';
    if (parsed < -180 || parsed > 180) {
      return 'Longitude must be between -180 and 180';
    }
    return null;
  }

  String? _minuteOffsetValidator(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return null;
    }

    final parsed = int.tryParse(text);
    if (parsed == null) {
      return 'Use whole minutes';
    }
    if (parsed < -59 || parsed > 59) {
      return 'Use -59 to 59';
    }
    return null;
  }
}

class _AccessScaffold extends StatelessWidget {
  const _AccessScaffold({
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
  });

  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.mutedText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onPrimary,
                      child: Text(primaryLabel),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.iconPrimary,
          ),
        ),
        Expanded(
          child: Text(
            'Mosque Admin',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryText,
                ),
          ),
        ),
      ],
    );
  }
}

class _CardSection extends StatelessWidget {
  const _CardSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _LocationSearchField extends StatelessWidget {
  const _LocationSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: key,
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: const TextStyle(
        fontSize: 14,
        color: AppColors.primaryText,
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Search mosque or place on Google Maps',
        hintStyle: const TextStyle(
          fontSize: 13,
          color: AppColors.mutedText,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.iconSecondary,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.2),
        ),
      ),
    );
  }
}

class _LocationSuggestionPanel extends StatelessWidget {
  const _LocationSuggestionPanel({
    required this.isSearching,
    required this.suggestions,
    required this.feedback,
    required this.feedbackIsError,
    required this.selectedSuggestion,
    required this.onSelectSuggestion,
  });

  final bool isSearching;
  final List<LocationSuggestion> suggestions;
  final String? feedback;
  final bool feedbackIsError;
  final LocationSuggestion? selectedSuggestion;
  final ValueChanged<LocationSuggestion> onSelectSuggestion;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          if (isSearching)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Searching Google Maps...',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (suggestions.isNotEmpty)
            for (var index = 0; index < suggestions.length; index++) ...[
              _LocationSuggestionTile(
                key: ValueKey('admin-add-location-option-$index'),
                suggestion: suggestions[index],
                selected: selectedSuggestion?.label.toLowerCase() ==
                    suggestions[index].label.toLowerCase(),
                onTap: () => onSelectSuggestion(suggestions[index]),
              ),
              if (index != suggestions.length - 1)
                const Divider(height: 1, color: AppColors.line),
            ]
          else if (feedback != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  feedback!,
                  style: TextStyle(
                    fontSize: 13,
                    color: feedbackIsError
                        ? const Color(0xFF8C4C3A)
                        : AppColors.mutedText,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LocationSuggestionTile extends StatelessWidget {
  const _LocationSuggestionTile({
    super.key,
    required this.suggestion,
    required this.selected,
    required this.onTap,
  });

  final LocationSuggestion suggestion;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = suggestion.primaryText ?? suggestion.label;
    final subtitle =
        suggestion.secondaryText ?? 'Use this result to auto-fill coordinates.';

    return Material(
      color: selected ? AppColors.surfaceMuted : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              const Icon(
                Icons.place_outlined,
                color: AppColors.iconSecondary,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoordinateStatusCard extends StatelessWidget {
  const _CoordinateStatusCard({
    required this.message,
    required this.manualOverride,
  });

  final String message;
  final bool manualOverride;

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        manualOverride ? const Color(0xFFF4F1E8) : const Color(0xFFF1F6F0);
    final borderColor =
        manualOverride ? const Color(0xFFE2D8BE) : const Color(0xFFD5E5D3);
    final icon =
        manualOverride ? Icons.edit_location_alt_outlined : Icons.check_circle;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.secondaryText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.validator,
    this.helperText,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: AppColors.primaryText),
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13),
        helperText: helperText,
        helperStyle: const TextStyle(fontSize: 11),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.line),
        ),
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.labelBuilder,
  });

  final String label;
  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final String Function(T value)? labelBuilder;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      onChanged: onChanged,
      isExpanded: true,
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.line),
        ),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(
                labelBuilder?.call(item) ?? '$item',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.text,
    required this.value,
    required this.onTap,
  });

  final String text;
  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: value ? AppColors.surfaceMuted : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.lineStrong),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: value ? FontWeight.w700 : FontWeight.w500,
            color: AppColors.primaryText,
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
              color: AppColors.primaryText,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider(color: AppColors.line)),
      ],
    );
  }
}

class _SuccessCard extends StatelessWidget {
  const _SuccessCard({
    required this.mosque,
    required this.onOpenMosque,
    required this.onManageMosque,
  });

  final MosqueModel mosque;
  final VoidCallback onOpenMosque;
  final VoidCallback onManageMosque;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Created Successfully',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${mosque.name} is now persisted. Use the owned-mosque management flow for events, broadcasts, and future edits.',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.mutedText,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onOpenMosque,
                  child: const Text('Open Mosque'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onManageMosque,
                  child: const Text('Manage Mosque'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MosqueListCard extends StatelessWidget {
  const _MosqueListCard({required this.item});

  final MosqueModel item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                  ),
                ),
              ),
              const Icon(Icons.verified_outlined,
                  color: AppColors.iconSecondary, size: 16),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${item.city} · ${item.distanceMiles.toStringAsFixed(1)} mi · Dhuhr at ${item.duhrTime}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            [
              item.sect,
              if (item.womenPrayerArea) 'Women Prayer Area',
              if (item.parking) 'Parking',
              if (item.wudu) 'Wudu',
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}
