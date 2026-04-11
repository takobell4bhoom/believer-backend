import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_provider.dart';
import '../data/mosque_content_refresh_provider.dart';
import '../data/mosque_provider.dart';
import '../models/broadcast_message.dart';
import '../models/mosque_content.dart';
import '../models/mosque_model.dart';
import '../models/prayer_time_configuration_options.dart';
import '../models/prayer_timings.dart';
import '../services/api_client.dart';
import '../services/browser_image_picker.dart';
import '../services/mosque_service.dart';
import '../theme/app_colors.dart';
import '../widgets/mosque_admin_broadcast_editor.dart';
import '../widgets/mosque_admin_event_editor.dart';
import '../widgets/mosque_image_upload_field.dart';

enum MosqueAdminEditEntryPoint {
  overview,
  events,
  broadcasts,
}

class MosqueAdminEditRouteArgs {
  const MosqueAdminEditRouteArgs({
    required this.mosque,
    this.entryPoint = MosqueAdminEditEntryPoint.overview,
  });

  final MosqueModel mosque;
  final MosqueAdminEditEntryPoint entryPoint;
}

class MosqueAdminEditScreen extends ConsumerStatefulWidget {
  const MosqueAdminEditScreen({
    super.key,
    required this.args,
    this.mosqueService,
    this.imagePicker,
  });

  final MosqueAdminEditRouteArgs args;
  final MosqueService? mosqueService;
  final BrowserImagePicker? imagePicker;

  @override
  ConsumerState<MosqueAdminEditScreen> createState() =>
      _MosqueAdminEditScreenState();
}

class _MosqueAdminEditScreenState extends ConsumerState<MosqueAdminEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _overviewSectionKey = GlobalKey();
  final _eventsSectionKey = GlobalKey();
  final _broadcastSectionKey = GlobalKey();

  final _nameCtrl = TextEditingController();
  final _contactNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  final _latitudeCtrl = TextEditingController();
  final _longitudeCtrl = TextEditingController();
  final _aboutTitleCtrl = TextEditingController();
  final _aboutBodyCtrl = TextEditingController();
  final _broadcastTitleCtrl = TextEditingController();
  final _broadcastMessageCtrl = TextEditingController();
  final Map<String, TextEditingController> _offsetCtrls = {
    for (final prayer in prayerOffsetOrder)
      prayer: TextEditingController(text: '0'),
  };

  late final MosqueService _mosqueService;
  late final BrowserImagePicker _imagePicker;
  List<MosqueAdminEventDraft> _eventDrafts = <MosqueAdminEventDraft>[];
  late final List<_ProgramDraftControllers> _classDrafts;
  late final List<_ConnectDraftControllers> _connectDrafts;

  String _sect = 'Community';
  int _calculationMethod = 3;
  String _school = 'standard';
  bool _prayerTimingsEnabled = true;
  bool _womenArea = false;
  bool _parking = false;
  bool _wudu = false;
  bool _wheelchair = false;
  bool _kidsArea = false;
  bool _ramadanIftar = false;

  bool _isHydrating = true;
  bool _isSubmitting = false;
  bool _isUploadingImage = false;
  MosqueImageUploadFile? _pendingImageUpload;
  String? _imageUploadErrorText;
  MosqueAdminUpdateResult? _latestResult;
  List<String> _uploadedImageUrls = <String>[];
  List<BroadcastMessage> _publishedBroadcasts = <BroadcastMessage>[];
  bool _isPublishingBroadcast = false;
  final Set<String> _removingBroadcastIds = <String>{};

  @override
  void initState() {
    super.initState();
    _mosqueService = widget.mosqueService ?? MosqueService();
    _imagePicker = widget.imagePicker ?? createBrowserImagePicker();
    _classDrafts = List<_ProgramDraftControllers>.generate(
        3, (_) => _ProgramDraftControllers());
    _connectDrafts = List<_ConnectDraftControllers>.generate(
        4, (_) => _ConnectDraftControllers());
    _populateBasics(widget.args.mosque);
    _hydrateContent();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEntryPoint());
  }

  @override
  void dispose() {
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
    _latitudeCtrl.dispose();
    _longitudeCtrl.dispose();
    _aboutTitleCtrl.dispose();
    _aboutBodyCtrl.dispose();
    _broadcastTitleCtrl.dispose();
    _broadcastMessageCtrl.dispose();
    _scrollController.dispose();
    for (final controller in _offsetCtrls.values) {
      controller.dispose();
    }
    _disposeEventDrafts();
    for (final draft in _classDrafts) {
      draft.dispose();
    }
    for (final draft in _connectDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  void _populateBasics(MosqueModel mosque) {
    _nameCtrl.text = mosque.name;
    _contactNameCtrl.text = mosque.contactName;
    _phoneCtrl.text = mosque.contactPhone;
    _emailCtrl.text = mosque.contactEmail;
    _websiteCtrl.text = mosque.websiteUrl;
    _addressCtrl.text = mosque.addressLine;
    _cityCtrl.text = mosque.city;
    _stateCtrl.text = mosque.state;
    _countryCtrl.text = mosque.country;
    _zipCtrl.text = mosque.postalCode;
    _uploadedImageUrls = mosque.imageUrls.isNotEmpty
        ? [...mosque.imageUrls]
        : <String>[
            if (mosque.imageUrl.trim().isNotEmpty) mosque.imageUrl.trim(),
          ];
    _latitudeCtrl.text = mosque.latitude.toStringAsFixed(4);
    _longitudeCtrl.text = mosque.longitude.toStringAsFixed(4);
    _sect = mosque.sect.trim().isEmpty ? 'Community' : mosque.sect;

    final facilities = mosque.facilities.toSet();
    _womenArea = facilities.contains('women_area');
    _parking = facilities.contains('parking');
    _wudu = facilities.contains('wudu');
    _wheelchair = facilities.contains('wheelchair');
    _kidsArea = facilities.contains('kids_area');
    _ramadanIftar = facilities.contains('ramadan_iftar');
  }

  Future<void> _pickImage() async {
    try {
      if (_uploadedImageUrls.length >= MosqueService.maxMosqueImages) {
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

  Future<void> _hydrateContent() async {
    try {
      final results = await Future.wait<dynamic>([
        _mosqueService.getMosqueContent(widget.args.mosque.id),
        _mosqueService.getMosqueBroadcastMessages(widget.args.mosque.id),
        _mosqueService.getPrayerTimings(
          mosqueId: widget.args.mosque.id,
          date: _todayIsoDate(),
        ),
      ]);
      if (!mounted) return;
      _populateContent(results[0] as MosqueContent);
      _publishedBroadcasts =
          List<BroadcastMessage>.from(results[1] as List<BroadcastMessage>);
      _populatePrayerConfiguration(results[2] as PrayerTimings);
    } catch (_) {
      // Keep editing available even if content hydration fails.
    } finally {
      if (mounted) {
        setState(() => _isHydrating = false);
      }
    }
  }

  void _populatePrayerConfiguration(PrayerTimings prayerTimings) {
    final configuration = prayerTimings.configuration;
    if (configuration == null) {
      return;
    }

    _calculationMethod = configuration.calculationMethodId;
    _school = configuration.school;
    _prayerTimingsEnabled = configuration.enabled;
    for (final prayer in prayerOffsetOrder) {
      _offsetCtrls[prayer]!.text =
          (configuration.adjustments[prayer] ?? 0).toString();
    }
  }

  void _populateContent(MosqueContent content) {
    _aboutTitleCtrl.text = content.about?.title ?? '';
    _aboutBodyCtrl.text = content.about?.body ?? '';
    final editableLinks = content.connect
        .where((link) => !_isDerivedContactLink(link))
        .toList(growable: false);

    _replaceEventDrafts(content.events);

    for (var i = 0; i < _classDrafts.length; i += 1) {
      final item = i < content.classes.length ? content.classes[i] : null;
      _classDrafts[i].title.text = item?.title ?? '';
      _classDrafts[i].schedule.text = item?.schedule ?? '';
      _classDrafts[i].posterLabel.text = item?.posterLabel ?? '';
    }

    for (var i = 0; i < _connectDrafts.length; i += 1) {
      final item = i < editableLinks.length ? editableLinks[i] : null;
      _connectDrafts[i].type.text = item?.type ?? '';
      _connectDrafts[i].label.text = item?.label ?? '';
      _connectDrafts[i].value.text = item?.value ?? '';
    }
  }

  bool _isDerivedContactLink(MosqueConnectLink link) {
    final type = link.type.trim().toLowerCase();
    final value = link.value.trim();
    if (value.isEmpty) {
      return false;
    }

    if (type == 'phone' && value == _phoneCtrl.text.trim()) {
      return true;
    }
    if (type == 'email' && value == _emailCtrl.text.trim()) {
      return true;
    }
    if (type == 'website' && value == _websiteCtrl.text.trim()) {
      return true;
    }

    return false;
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

  List<Map<String, dynamic>> _programPayload(
    List<_ProgramDraftControllers> drafts,
  ) {
    return drafts
        .map((draft) {
          final title = draft.title.text.trim();
          if (title.isEmpty) {
            return null;
          }

          return <String, dynamic>{
            'title': title,
            'schedule': draft.schedule.text.trim(),
            'posterLabel': draft.posterLabel.text.trim(),
          };
        })
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  void _disposeEventDrafts() {
    for (final draft in _eventDrafts) {
      draft.dispose();
    }
    _eventDrafts = <MosqueAdminEventDraft>[];
  }

  void _replaceEventDrafts(List<MosqueProgramItem> events) {
    _disposeEventDrafts();
    _eventDrafts = events
        .map(MosqueAdminEventDraft.fromProgramItem)
        .toList(growable: true);
  }

  void _addEventDraft() {
    if (_eventDrafts.length >= 12) {
      _showMessage('You can publish up to 12 mosque events for now.');
      return;
    }

    setState(() {
      _eventDrafts = [..._eventDrafts, MosqueAdminEventDraft.empty()];
    });
  }

  void _moveEventDraftUp(int index) {
    if (index <= 0 || index >= _eventDrafts.length) {
      return;
    }

    setState(() {
      final nextDrafts = [..._eventDrafts];
      final selected = nextDrafts.removeAt(index);
      nextDrafts.insert(index - 1, selected);
      _eventDrafts = nextDrafts;
    });
  }

  void _moveEventDraftDown(int index) {
    if (index < 0 || index >= _eventDrafts.length - 1) {
      return;
    }

    setState(() {
      final nextDrafts = [..._eventDrafts];
      final selected = nextDrafts.removeAt(index);
      nextDrafts.insert(index + 1, selected);
      _eventDrafts = nextDrafts;
    });
  }

  void _removeEventDraftAt(int index) {
    if (index < 0 || index >= _eventDrafts.length) {
      return;
    }

    final removed = _eventDrafts[index];
    setState(() {
      final nextDrafts = [..._eventDrafts]..removeAt(index);
      _eventDrafts = nextDrafts;
    });
    removed.dispose();
  }

  List<Map<String, dynamic>> _eventPayload() {
    return _eventDrafts
        .map((draft) => draft.toPayload())
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _connectPayload() {
    return _connectDrafts
        .map((draft) {
          final value = draft.value.text.trim();
          if (value.isEmpty) {
            return null;
          }

          return <String, dynamic>{
            'type': draft.type.text.trim().isEmpty
                ? 'other'
                : draft.type.text.trim(),
            'label': draft.label.text.trim(),
            'value': value,
          };
        })
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Future<void> _publishBroadcast() async {
    if (_isPublishingBroadcast) {
      return;
    }

    final title = _broadcastTitleCtrl.text.trim();
    final description = _broadcastMessageCtrl.text.trim();
    if (title.isEmpty) {
      _showMessage('Add a broadcast title before publishing.');
      return;
    }
    if (description.isEmpty) {
      _showMessage('Add the broadcast message before publishing.');
      return;
    }

    final token = ref.read(authProvider).valueOrNull?.accessToken;
    if (token == null || token.isEmpty) {
      _showMessage('Please log in with an admin account first.');
      return;
    }

    setState(() => _isPublishingBroadcast = true);

    try {
      final broadcast = await _mosqueService.publishMosqueBroadcast(
        mosqueId: widget.args.mosque.id,
        title: title,
        description: description,
        bearerToken: token,
      );
      if (!mounted) return;

      setState(() {
        _publishedBroadcasts = [
          broadcast,
          ..._publishedBroadcasts.where((item) => item.id != broadcast.id),
        ];
        _broadcastTitleCtrl.clear();
        _broadcastMessageCtrl.clear();
      });
      ref.read(mosqueContentRefreshTickProvider.notifier).state += 1;
      _showMessage('Broadcast published.');
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Unable to publish the broadcast right now.');
    } finally {
      if (mounted) {
        setState(() => _isPublishingBroadcast = false);
      }
    }
  }

  Future<void> _removeBroadcast(String broadcastId) async {
    if (_removingBroadcastIds.contains(broadcastId)) {
      return;
    }

    final token = ref.read(authProvider).valueOrNull?.accessToken;
    if (token == null || token.isEmpty) {
      _showMessage('Please log in with an admin account first.');
      return;
    }

    setState(() => _removingBroadcastIds.add(broadcastId));

    try {
      await _mosqueService.deleteMosqueBroadcast(
        mosqueId: widget.args.mosque.id,
        broadcastId: broadcastId,
        bearerToken: token,
      );
      if (!mounted) return;

      setState(() {
        _publishedBroadcasts = _publishedBroadcasts
            .where((item) => item.id != broadcastId)
            .toList(growable: false);
      });
      ref.read(mosqueContentRefreshTickProvider.notifier).state += 1;
      _showMessage('Broadcast removed.');
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Unable to remove the broadcast right now.');
    } finally {
      if (mounted) {
        setState(() => _removingBroadcastIds.remove(broadcastId));
      }
    }
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

  String _todayIsoDate() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
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
      final result = await _mosqueService.updateMosque(
        mosqueId: widget.args.mosque.id,
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
          'imageUrl':
              _uploadedImageUrls.isNotEmpty ? _uploadedImageUrls.first : '',
          'imageUrls': _uploadedImageUrls,
          'sect': _sect,
          'prayerTimeConfig': _prayerTimeConfigPayload(),
          'facilities': _selectedFacilities(),
          'content': {
            'about': {
              'title': _aboutTitleCtrl.text.trim(),
              'body': _aboutBodyCtrl.text.trim(),
            },
            'events': _eventPayload(),
            'classes': _programPayload(_classDrafts),
            'connect': _connectPayload(),
          },
        },
      );

      ref.read(mosqueProvider.notifier).upsertMosque(result.mosque);
      ref.read(mosqueContentRefreshTickProvider.notifier).state += 1;
      if (!mounted) return;

      setState(() => _latestResult = result);
      _showMessage('Mosque content updated.');
      Navigator.of(context).pop(result);
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Unable to update mosque right now.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _scrollToEntryPoint() {
    final targetContext = switch (widget.args.entryPoint) {
      MosqueAdminEditEntryPoint.overview => _overviewSectionKey.currentContext,
      MosqueAdminEditEntryPoint.events => _eventsSectionKey.currentContext,
      MosqueAdminEditEntryPoint.broadcasts =>
        _broadcastSectionKey.currentContext,
    };

    if (targetContext == null) {
      return;
    }

    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 250),
      alignment: 0.08,
      curve: Curves.easeOut,
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
    final parsed = double.tryParse((value ?? '').trim());
    if (parsed == null) return 'Enter latitude';
    if (parsed < -90 || parsed > 90) {
      return 'Latitude must be between -90 and 90';
    }
    return null;
  }

  String? _longitudeValidator(String? value) {
    final parsed = double.tryParse((value ?? '').trim());
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
      return const _AccessScaffold(
        title: 'Admin Edit Mosque',
        message: 'Log in with an admin account to edit mosque content.',
      );
    }

    if (currentUser.role != 'admin') {
      return const _AccessScaffold(
        title: 'Admin Edit Mosque',
        message:
            'This edit workflow is restricted to persisted admin accounts.',
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Edit Mosque',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryText,
                                ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.args.mosque.name,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'This MVP updates live mosque details, publishable broadcasts and mosque events, backend-owned prayer-time configuration, and the persisted classes/connect/about content already used by the app experience.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.mutedText,
                  ),
                ),
                if (_isHydrating) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(minHeight: 3),
                ],
                const SizedBox(height: 14),
                _CardSection(
                  key: _overviewSectionKey,
                  title: 'Basic Information',
                  child: Column(
                    children: [
                      _InputField(
                        fieldKey: const ValueKey('admin-edit-name'),
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
                              items: const [
                                'Sunni',
                                'Shia',
                                'Mixed',
                                'Community'
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
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _CardSection(
                  title: 'Prayer and Facilities',
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
                          'Turn this off only when the mosque should temporarily hide live timings.',
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
                          'Use small +/- minute tuning when the local mosque follows a slightly adjusted iqamah rhythm.',
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
                              onTap: () =>
                                  setState(() => _wheelchair = !_wheelchair),
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
                const SizedBox(height: 12),
                _CardSection(
                  title: 'About Block',
                  child: Column(
                    children: [
                      _InputField(
                        fieldKey: const ValueKey('admin-edit-about-title'),
                        label: 'About Title',
                        controller: _aboutTitleCtrl,
                      ),
                      const SizedBox(height: 10),
                      _InputField(
                        fieldKey: const ValueKey('admin-edit-about-body'),
                        label: 'About Body',
                        controller: _aboutBodyCtrl,
                        minLines: 4,
                        maxLines: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _CardSection(
                  key: _eventsSectionKey,
                  title: 'Published Events',
                  child: MosqueAdminEventEditor(
                    drafts: _eventDrafts,
                    onAddEvent: _addEventDraft,
                    onMoveUp: _moveEventDraftUp,
                    onMoveDown: _moveEventDraftDown,
                    onRemove: _removeEventDraftAt,
                  ),
                ),
                const SizedBox(height: 12),
                _CardSection(
                  key: _broadcastSectionKey,
                  title: 'Broadcast Messages',
                  child: MosqueAdminBroadcastEditor(
                    titleController: _broadcastTitleCtrl,
                    messageController: _broadcastMessageCtrl,
                    publishedMessages: _publishedBroadcasts,
                    isPublishing: _isPublishingBroadcast,
                    removingBroadcastIds: _removingBroadcastIds,
                    onPublish: _publishBroadcast,
                    onRemove: _removeBroadcast,
                  ),
                ),
                const SizedBox(height: 12),
                _CardSection(
                  title: 'Classes and Halaqas',
                  child: _ProgramListEditor(
                    drafts: _classDrafts,
                    itemLabel: 'Class',
                    keyPrefix: 'class',
                  ),
                ),
                const SizedBox(height: 12),
                _CardSection(
                  title: 'Connect Links',
                  child: _ConnectListEditor(
                    drafts: _connectDrafts,
                  ),
                ),
                if (_latestResult != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Text(
                      '${_latestResult!.mosque.name} has been updated and the live mosque page can now re-read the saved content.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const ValueKey('admin-edit-mosque-submit'),
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
                      _isSubmitting ? 'Saving...' : 'Save Mosque Updates',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgramDraftControllers {
  _ProgramDraftControllers()
      : title = TextEditingController(),
        schedule = TextEditingController(),
        posterLabel = TextEditingController();

  final TextEditingController title;
  final TextEditingController schedule;
  final TextEditingController posterLabel;

  void dispose() {
    title.dispose();
    schedule.dispose();
    posterLabel.dispose();
  }
}

class _ConnectDraftControllers {
  _ConnectDraftControllers()
      : type = TextEditingController(),
        label = TextEditingController(),
        value = TextEditingController();

  final TextEditingController type;
  final TextEditingController label;
  final TextEditingController value;

  void dispose() {
    type.dispose();
    label.dispose();
    value.dispose();
  }
}

class _ProgramListEditor extends StatelessWidget {
  const _ProgramListEditor({
    required this.drafts,
    required this.itemLabel,
    required this.keyPrefix,
  });

  final List<_ProgramDraftControllers> drafts;
  final String itemLabel;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Only the first visible cards are editable in this MVP.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.mutedText,
            ),
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < drafts.length; i += 1) ...[
          _MiniSectionLabel(label: '$itemLabel ${i + 1}'),
          const SizedBox(height: 8),
          _InputField(
            fieldKey: ValueKey('$keyPrefix-title-$i'),
            label: '$itemLabel Title',
            controller: drafts[i].title,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _InputField(
                  fieldKey: ValueKey('$keyPrefix-schedule-$i'),
                  label: 'Schedule',
                  controller: drafts[i].schedule,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InputField(
                  fieldKey: ValueKey('$keyPrefix-poster-$i'),
                  label: 'Poster Label',
                  controller: drafts[i].posterLabel,
                ),
              ),
            ],
          ),
          if (i != drafts.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ConnectListEditor extends StatelessWidget {
  const _ConnectListEditor({
    required this.drafts,
  });

  final List<_ConnectDraftControllers> drafts;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Include only links the current mosque page should expose.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.mutedText,
            ),
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < drafts.length; i += 1) ...[
          _MiniSectionLabel(label: 'Link ${i + 1}'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _InputField(
                  label: 'Type',
                  controller: drafts[i].type,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InputField(
                  label: 'Label',
                  controller: drafts[i].label,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _InputField(
            label: 'Value',
            controller: drafts[i].value,
          ),
          if (i != drafts.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _AccessScaffold extends StatelessWidget {
  const _AccessScaffold({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardSection extends StatelessWidget {
  const _CardSection({
    super.key,
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

class _MiniSectionLabel extends StatelessWidget {
  const _MiniSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.secondaryText,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    this.fieldKey,
    required this.label,
    required this.controller,
    this.keyboardType,
    this.validator,
    this.helperText,
    this.minLines,
    this.maxLines = 1,
  });

  final Key? fieldKey;
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final String? helperText;
  final int? minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      minLines: minLines,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14, color: AppColors.primaryText),
      decoration: InputDecoration(
        isDense: maxLines == 1,
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
