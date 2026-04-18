import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/browser_image_picker.dart';
import '../../theme/app_colors.dart';
import 'business_registration_basic_models.dart';
import 'business_registration_basic_taxonomy.dart';
import 'business_registration_basic_widgets.dart';

typedef BusinessRegistrationBasicSubmit = FutureOr<void> Function(
    BusinessRegistrationBasicDraft draft);
typedef BusinessRegistrationLogoPicker = Future<BusinessRegistrationLogoAsset?>
    Function();
typedef BusinessRegistrationLogoRemoved = FutureOr<void> Function(
    BusinessRegistrationLogoAsset removedLogo);

class BusinessRegistrationBasicScreen extends StatefulWidget {
  const BusinessRegistrationBasicScreen({
    super.key,
    this.initialDraft = const BusinessRegistrationBasicDraft(),
    this.onBack,
    required this.onNext,
    required this.onSaveDraftAndClose,
    this.onLogoRequested,
    this.onLogoRemoved,
    this.showSaveDraftAction = true,
    this.nextButtonLabel = 'Next',
  });

  final BusinessRegistrationBasicDraft initialDraft;
  final VoidCallback? onBack;
  final BusinessRegistrationBasicSubmit onNext;
  final BusinessRegistrationBasicSubmit onSaveDraftAndClose;
  final BusinessRegistrationLogoPicker? onLogoRequested;
  final BusinessRegistrationLogoRemoved? onLogoRemoved;
  final bool showSaveDraftAction;
  final String nextButtonLabel;

  @override
  State<BusinessRegistrationBasicScreen> createState() =>
      _BusinessRegistrationBasicScreenState();
}

class _BusinessRegistrationBasicScreenState
    extends State<BusinessRegistrationBasicScreen> {
  final _businessNameController = TextEditingController();
  final _taglineController = TextEditingController();
  final _descriptionController = TextEditingController();

  late final BrowserImagePicker _browserImagePicker;

  BusinessRegistrationLogoAsset? _logo;
  BusinessRegistrationSelectedType? _selectedType;
  String? _expandedGroupId;
  bool _showSelector = false;
  bool _isPickingLogo = false;
  bool _isNextPending = false;
  bool _isSavePending = false;

  @override
  void initState() {
    super.initState();
    _browserImagePicker = createBrowserImagePicker();

    final draft = widget.initialDraft;
    _businessNameController.text = draft.businessName;
    _taglineController.text = draft.tagline;
    _descriptionController.text = draft.description;
    _logo = draft.logo;
    _selectedType = draft.selectedType;

    _businessNameController.addListener(_handleFieldChanged);
    _taglineController.addListener(_handleFieldChanged);
    _descriptionController.addListener(_handleFieldChanged);
  }

  @override
  void dispose() {
    _businessNameController.removeListener(_handleFieldChanged);
    _taglineController.removeListener(_handleFieldChanged);
    _descriptionController.removeListener(_handleFieldChanged);
    _businessNameController.dispose();
    _taglineController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  BusinessRegistrationBasicDraft get _draft => BusinessRegistrationBasicDraft(
        businessName: _businessNameController.text,
        logo: _logo,
        selectedType: _selectedType,
        tagline: _taglineController.text,
        description: _descriptionController.text,
      );

  bool get _canContinue =>
      _draft.isComplete && !_isNextPending && !_isSavePending;

  void _handleFieldChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleBack() {
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }
    Navigator.of(context).maybePop();
  }

  void _toggleSelector() {
    FocusScope.of(context).unfocus();
    setState(() {
      _showSelector = !_showSelector;
      if (_showSelector && _selectedType != null) {
        _expandedGroupId = _selectedType!.groupId;
      }
    });
  }

  void _toggleGroup(String groupId) {
    setState(() {
      _expandedGroupId = _expandedGroupId == groupId ? null : groupId;
    });
  }

  void _selectType(
    BusinessRegistrationTaxonomyGroup group,
    BusinessRegistrationTaxonomyItem item,
  ) {
    setState(() {
      _selectedType = BusinessRegistrationSelectedType(
        groupId: group.id,
        groupLabel: group.label,
        itemId: item.id,
        itemLabel: item.label,
      );
      _expandedGroupId = group.id;
      _showSelector = false;
    });
  }

  Future<void> _handleLogoTap() async {
    if (_isPickingLogo) {
      return;
    }

    setState(() => _isPickingLogo = true);

    try {
      final pickedLogo =
          await (widget.onLogoRequested?.call() ?? _pickLogoFromBrowser());
      if (!mounted || pickedLogo == null) {
        return;
      }

      setState(() => _logo = pickedLogo);
    } finally {
      if (mounted) {
        setState(() => _isPickingLogo = false);
      }
    }
  }

  Future<BusinessRegistrationLogoAsset?> _pickLogoFromBrowser() async {
    final pickedImage = await _browserImagePicker.pickImage();
    if (pickedImage == null) {
      _showMessage(
        'Logo picking is currently available through the browser upload flow.',
      );
      return null;
    }

    if (!isSupportedMosqueImageFile(pickedImage)) {
      _showMessage('Upload a JPG, PNG, or WebP logo.');
      return null;
    }

    if (pickedImage.bytes.length > 2 * 1024 * 1024) {
      _showMessage('Please choose a logo under 2MB.');
      return null;
    }

    return BusinessRegistrationLogoAsset(
      fileName: pickedImage.fileName,
      bytes: pickedImage.bytes,
      contentType: pickedImage.contentType,
    );
  }

  Future<void> _handleRemoveLogo() async {
    final currentLogo = _logo;
    if (currentLogo == null) {
      return;
    }

    setState(() => _logo = null);
    await widget.onLogoRemoved?.call(currentLogo);
  }

  Future<void> _handleNext() async {
    if (!_canContinue || _isNextPending) {
      return;
    }

    setState(() => _isNextPending = true);
    try {
      await widget.onNext(_draft);
    } finally {
      if (mounted) {
        setState(() => _isNextPending = false);
      }
    }
  }

  Future<void> _handleSaveDraftAndClose() async {
    if (_isSavePending || !_draft.isDirty) {
      return;
    }

    setState(() => _isSavePending = true);
    try {
      await widget.onSaveDraftAndClose(_draft);
    } finally {
      if (mounted) {
        setState(() => _isSavePending = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        Color.lerp(AppColors.background, AppColors.surface, 0.56)!;
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final bool isKeyboardVisible = keyboardInset > 0;
    final bool showSaveDraft = widget.showSaveDraftAction && _draft.isDirty;
    final double footerReservedSpace =
        switch ((showSaveDraft, isKeyboardVisible)) {
      (_, true) => 88,
      (true, false) => 146,
      (false, false) => 112,
    };

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: keyboardInset),
              child: Column(
                children: [
                  BusinessRegistrationBasicHeader(onBack: _handleBack),
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        20,
                        14,
                        20,
                        footerReservedSpace + 20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const BusinessRegistrationSectionLabel(
                            text: 'Business Name',
                            required: true,
                          ),
                          const SizedBox(height: 8),
                          BusinessRegistrationTextField(
                            controller: _businessNameController,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 14),
                          const BusinessRegistrationSectionLabel(
                            text: 'Logo',
                            required: true,
                          ),
                          const SizedBox(height: 8),
                          BusinessRegistrationLogoUploadCard(
                            logo: _logo,
                            isLoading: _isPickingLogo,
                            onTap: _handleLogoTap,
                            onRemove: _handleRemoveLogo,
                          ),
                          const SizedBox(height: 14),
                          const BusinessRegistrationSectionLabel(
                            text: 'Business/Service Type',
                            required: true,
                          ),
                          const SizedBox(height: 8),
                          BusinessRegistrationTaxonomySelector(
                            groups: businessRegistrationBasicTaxonomy,
                            isExpanded: _showSelector,
                            expandedGroupId: _expandedGroupId,
                            selectedType: _selectedType,
                            onToggleExpanded: _toggleSelector,
                            onToggleGroup: _toggleGroup,
                            onSelectItem: _selectType,
                          ),
                          const SizedBox(height: 14),
                          const BusinessRegistrationSectionLabel(
                            text: 'Tagline',
                            required: true,
                          ),
                          const SizedBox(height: 8),
                          BusinessRegistrationTextField(
                            controller: _taglineController,
                            minLines: 4,
                            maxLines: 4,
                            textInputAction: TextInputAction.newline,
                          ),
                          const SizedBox(height: 14),
                          const BusinessRegistrationSectionLabel(
                            text: 'Describe your business in a few words',
                            required: true,
                          ),
                          const SizedBox(height: 8),
                          BusinessRegistrationTextField(
                            controller: _descriptionController,
                            minLines: 10,
                            maxLines: 10,
                            textInputAction: TextInputAction.newline,
                          ),
                        ],
                      ),
                    ),
                  ),
                  BusinessRegistrationFooter(
                    canContinue: _canContinue,
                    showSaveDraft: showSaveDraft,
                    isKeyboardVisible: isKeyboardVisible,
                    nextButtonLabel: widget.nextButtonLabel,
                    onNext: _handleNext,
                    onSaveDraftAndClose: _handleSaveDraftAndClose,
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
