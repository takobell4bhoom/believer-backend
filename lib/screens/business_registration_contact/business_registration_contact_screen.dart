import 'package:flutter/material.dart';

import 'business_registration_contact_model.dart';
import 'business_registration_contact_widgets.dart';

class BusinessRegistrationContactScreen extends StatefulWidget {
  const BusinessRegistrationContactScreen({
    super.key,
    required this.onSubmit,
    required this.onSaveDraft,
    this.onChanged,
    this.onBackPressed,
    this.initialValue = const BusinessRegistrationContactDraft(),
    this.isSubmitting = false,
    this.isSavingDraft = false,
    this.showSaveDraftAction = true,
    this.submitButtonLabel = 'Submit Listing',
  });

  final Future<void> Function(BusinessRegistrationContactDraft draft) onSubmit;
  final Future<void> Function(BusinessRegistrationContactDraft draft)
      onSaveDraft;
  final ValueChanged<BusinessRegistrationContactDraft>? onChanged;
  final VoidCallback? onBackPressed;
  final BusinessRegistrationContactDraft initialValue;
  final bool isSubmitting;
  final bool isSavingDraft;
  final bool showSaveDraftAction;
  final String submitButtonLabel;

  @override
  State<BusinessRegistrationContactScreen> createState() =>
      _BusinessRegistrationContactScreenState();
}

class _BusinessRegistrationContactScreenState
    extends State<BusinessRegistrationContactScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _businessEmailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _whatsappController;
  late final TextEditingController _instagramController;
  late final TextEditingController _facebookController;
  late final TextEditingController _websiteController;
  late final TextEditingController _addressController;
  late final TextEditingController _zipCodeController;
  late final TextEditingController _cityController;

  TimeOfDay? _openingTime;
  TimeOfDay? _closingTime;
  bool _onlineOnly = false;
  bool _showHoursError = false;
  bool _isSyncingDraftFromWidget = false;

  List<TextEditingController> get _controllers => [
        _businessEmailController,
        _phoneController,
        _whatsappController,
        _instagramController,
        _facebookController,
        _websiteController,
        _addressController,
        _zipCodeController,
        _cityController,
      ];

  @override
  void initState() {
    super.initState();
    _businessEmailController = TextEditingController();
    _phoneController = TextEditingController();
    _whatsappController = TextEditingController();
    _instagramController = TextEditingController();
    _facebookController = TextEditingController();
    _websiteController = TextEditingController();
    _addressController = TextEditingController();
    _zipCodeController = TextEditingController();
    _cityController = TextEditingController();

    _loadDraft(widget.initialValue);
    for (final controller in _controllers) {
      controller.addListener(_handleDraftChanged);
    }
  }

  @override
  void didUpdateWidget(covariant BusinessRegistrationContactScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_matchesCurrentDraft(widget.initialValue)) {
      return;
    }
    if (oldWidget.initialValue != widget.initialValue) {
      setState(() => _loadDraft(widget.initialValue));
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller
        ..removeListener(_handleDraftChanged)
        ..dispose();
    }
    super.dispose();
  }

  void _loadDraft(BusinessRegistrationContactDraft draft) {
    _isSyncingDraftFromWidget = true;
    try {
      _businessEmailController.text = draft.businessEmail;
      _phoneController.text = draft.phone;
      _whatsappController.text = draft.whatsapp;
      _instagramController.text = draft.instagramUrl;
      _facebookController.text = draft.facebookUrl;
      _websiteController.text = draft.websiteUrl;
      _addressController.text = draft.address;
      _zipCodeController.text = draft.zipCode;
      _cityController.text = draft.city;
      _openingTime = draft.openingTime;
      _closingTime = draft.closingTime;
      _onlineOnly = draft.onlineOnly;
      _showHoursError = false;
    } finally {
      _isSyncingDraftFromWidget = false;
    }
  }

  void _handleDraftChanged() {
    if (!mounted || _isSyncingDraftFromWidget) return;
    setState(() {
      if (_showHoursError && _draft.hasOperatingHours) {
        _showHoursError = false;
      }
    });
    widget.onChanged?.call(_draft);
  }

  bool _matchesCurrentDraft(BusinessRegistrationContactDraft draft) {
    final current = _draft;
    return current.businessEmail == draft.businessEmail &&
        current.phone == draft.phone &&
        current.whatsapp == draft.whatsapp &&
        current.openingTime == draft.openingTime &&
        current.closingTime == draft.closingTime &&
        current.instagramUrl == draft.instagramUrl &&
        current.facebookUrl == draft.facebookUrl &&
        current.websiteUrl == draft.websiteUrl &&
        current.address == draft.address &&
        current.zipCode == draft.zipCode &&
        current.city == draft.city &&
        current.onlineOnly == draft.onlineOnly;
  }

  BusinessRegistrationContactDraft get _draft =>
      BusinessRegistrationContactDraft(
        businessEmail: _businessEmailController.text,
        phone: _phoneController.text,
        whatsapp: _whatsappController.text,
        openingTime: _openingTime,
        closingTime: _closingTime,
        instagramUrl: _instagramController.text,
        facebookUrl: _facebookController.text,
        websiteUrl: _websiteController.text,
        address: _addressController.text,
        zipCode: _zipCodeController.text,
        city: _cityController.text,
        onlineOnly: _onlineOnly,
      );

  String? _validateBusinessEmail(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'Business email is required.';
    if (!BusinessRegistrationContactDraft.isValidEmail(input)) {
      return 'Enter a valid business email.';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'Phone number is required.';
    if (!BusinessRegistrationContactDraft.isValidPhone(input)) {
      return 'Enter a valid phone number.';
    }
    return null;
  }

  String? _validateWhatsapp(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return null;
    if (!BusinessRegistrationContactDraft.isValidPhone(input)) {
      return 'Enter a valid WhatsApp number.';
    }
    return null;
  }

  String? _validateAddress(String? value) {
    if (_onlineOnly) return null;
    if ((value?.trim() ?? '').isEmpty) {
      return 'Business address is required.';
    }
    return null;
  }

  String? _validateZipCode(String? value) {
    if (_onlineOnly) return null;
    if ((value?.trim() ?? '').isEmpty) {
      return 'Zip code is required.';
    }
    return null;
  }

  String? _validateCity(String? value) {
    if (_onlineOnly) return null;
    if ((value?.trim() ?? '').isEmpty) {
      return 'City is required.';
    }
    return null;
  }

  Future<void> _pickOpeningTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _openingTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _openingTime = selected;
      _showHoursError = false;
    });
    widget.onChanged?.call(_draft);
  }

  Future<void> _pickClosingTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _closingTime ?? const TimeOfDay(hour: 17, minute: 0),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _closingTime = selected;
      _showHoursError = false;
    });
    widget.onChanged?.call(_draft);
  }

  Future<void> _handleSubmitPressed() async {
    FocusScope.of(context).unfocus();
    final bool formValid = _formKey.currentState?.validate() ?? false;
    final bool hasHours = _draft.hasOperatingHours;
    setState(() => _showHoursError = !hasHours);
    if (!formValid || !hasHours || !_draft.isSubmitReady) {
      return;
    }
    await widget.onSubmit(_draft);
  }

  Future<void> _handleSaveDraftPressed() async {
    FocusScope.of(context).unfocus();
    await widget.onSaveDraft(_draft);
  }

  String? _formattedTime(TimeOfDay? value) {
    if (value == null) return null;
    return MaterialLocalizations.of(context).formatTimeOfDay(value);
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return BusinessRegistrationContactScaffold(
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: viewInsets + 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BusinessRegistrationHeader(
                onBackPressed: widget.onBackPressed ??
                    () => Navigator.of(context).maybePop(),
              ),
              const BusinessRegistrationProgressIndicator(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const BusinessRegistrationFieldLabel(
                      text: 'Business Email',
                      required: true,
                    ),
                    const SizedBox(height: 10),
                    BusinessRegistrationTextField(
                      controller: _businessEmailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: _validateBusinessEmail,
                    ),
                    const SizedBox(height: 16),
                    const BusinessRegistrationFieldLabel(
                      text: 'Phone No',
                      required: true,
                    ),
                    const SizedBox(height: 10),
                    BusinessRegistrationTextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      validator: _validatePhone,
                    ),
                    const SizedBox(height: 16),
                    const BusinessRegistrationFieldLabel(text: 'WhatsApp'),
                    const SizedBox(height: 10),
                    BusinessRegistrationTextField(
                      controller: _whatsappController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      validator: _validateWhatsapp,
                    ),
                    const SizedBox(height: 16),
                    const BusinessRegistrationFieldLabel(
                      text: 'Operating Hours',
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: BusinessRegistrationTimeField(
                            label: 'Start time',
                            value: _formattedTime(_openingTime),
                            onTap: _pickOpeningTime,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: BusinessRegistrationTimeField(
                            label: 'End time',
                            value: _formattedTime(_closingTime),
                            onTap: _pickClosingTime,
                          ),
                        ),
                      ],
                    ),
                    if (_showHoursError) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Select both start and end time.',
                        style: TextStyle(
                          fontFamily: 'Figtree',
                          fontSize: 11.5,
                          color: Color(0xFFC27265),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const BusinessRegistrationFieldLabel(text: 'Links'),
                    const SizedBox(height: 10),
                    BusinessRegistrationLinkField(
                      controller: _instagramController,
                      icon: Icons.camera_alt_rounded,
                      hintText: 'Instagram link',
                    ),
                    const SizedBox(height: 10),
                    BusinessRegistrationLinkField(
                      controller: _facebookController,
                      icon: Icons.facebook_rounded,
                      hintText: 'Facebook page link',
                    ),
                    const SizedBox(height: 10),
                    BusinessRegistrationLinkField(
                      controller: _websiteController,
                      icon: Icons.public_rounded,
                      hintText: 'Website link',
                    ),
                    const SizedBox(height: 16),
                    const BusinessRegistrationFieldLabel(
                      text: 'Business Address',
                    ),
                    const SizedBox(height: 10),
                    BusinessRegistrationTextField(
                      controller: _addressController,
                      keyboardType: TextInputType.streetAddress,
                      textInputAction: TextInputAction.newline,
                      minLines: 2,
                      maxLines: 3,
                      validator: _validateAddress,
                    ),
                    const SizedBox(height: 16),
                    const BusinessRegistrationFieldLabel(text: 'Zip Code'),
                    const SizedBox(height: 10),
                    BusinessRegistrationTextField(
                      controller: _zipCodeController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      validator: _validateZipCode,
                    ),
                    const SizedBox(height: 16),
                    const BusinessRegistrationFieldLabel(text: 'City'),
                    const SizedBox(height: 10),
                    BusinessRegistrationTextField(
                      controller: _cityController,
                      textInputAction: TextInputAction.done,
                      validator: _validateCity,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _onlineOnly,
                          onChanged: (value) {
                            setState(() => _onlineOnly = value ?? false);
                            widget.onChanged?.call(_draft);
                            _formKey.currentState?.validate();
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          side: const BorderSide(
                            color: Color(0xFF4E665C),
                            width: 1.6,
                          ),
                          activeColor: const Color(0xFF4E665C),
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 4),
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'This business operates online and is not tied to a specific location.',
                              style: TextStyle(
                                fontFamily: 'Figtree',
                                fontSize: 15,
                                height: 1.2,
                                color: Color(0xFF5A6761),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    BusinessRegistrationSubmitSection(
                      submitEnabled: draft.isSubmitReady,
                      isSubmitting: widget.isSubmitting,
                      isSavingDraft: widget.isSavingDraft,
                      showSaveDraftAction: widget.showSaveDraftAction,
                      submitButtonLabel: widget.submitButtonLabel,
                      onSubmitPressed: _handleSubmitPressed,
                      onSaveDraftPressed: _handleSaveDraftPressed,
                    ),
                    const SizedBox(height: 40),
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
