import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_provider.dart';
import '../navigation/app_routes.dart';
import '../navigation/app_startup.dart';
import '../services/account_settings_service.dart';
import '../theme/app_colors.dart';

class SettingsAboutScreen extends StatelessWidget {
  const SettingsAboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _SettingsSubpageScaffold(
      title: 'About',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _InfoCard(
            title: 'BelieversLens',
            body:
                'BelieversLens helps Muslim communities find nearby mosques, check prayer information, follow mosque updates, and manage mosque listings through one public app experience.',
          ),
          const SizedBox(height: 12),
          const _InfoCard(
            title: 'This release',
            body:
                'This public-readiness build keeps account access, mosque discovery, prayer settings, and mosque-admin content management focused on the features that are already backed by real app or backend behavior.',
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: 'Open source licenses',
            body:
                'You can review the third-party software licenses bundled with this build from the system license page.',
            action: FilledButton(
              onPressed: () {
                showLicensePage(
                  context: context,
                  applicationName: 'BelieversLens',
                );
              },
              child: const Text('View licenses'),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsPrivacyScreen extends StatelessWidget {
  const SettingsPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SettingsSubpageScaffold(
      title: 'Privacy',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoCard(
            title: 'What we store',
            body:
                'Your account profile, sign-in credentials, saved mosque bookmarks, reviews, notification preferences, and any mosque-admin content you publish are stored so the app can provide the features you use.',
          ),
          SizedBox(height: 12),
          _InfoCard(
            title: 'Location and prayer settings',
            body:
                'Saved location labels, coordinates, and prayer-setting preferences are used to improve nearby mosque discovery and prayer-time experiences. You can update those preferences from the app.',
          ),
          SizedBox(height: 12),
          _InfoCard(
            title: 'Account control',
            body:
                'You can change your profile name, rotate your password, log out, or deactivate your account directly from Profile & Settings. Deactivation disables future sign-in until support restores the account.',
          ),
        ],
      ),
    );
  }
}

class SettingsFaqScreen extends StatelessWidget {
  const SettingsFaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SettingsSubpageScaffold(
      title: 'FAQs',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FaqCard(
            question: 'How do I change my password?',
            answer:
                'Open Profile & Settings, choose Change Password, and enter your current password before saving a new one.',
          ),
          SizedBox(height: 12),
          _FaqCard(
            question: 'How do mosque admins manage a mosque?',
            answer:
                'Admins can use My Mosques, Add Mosque, Manage Owned Mosques, Publish Events, and Broadcast Messages from the admin section of Profile & Settings.',
          ),
          SizedBox(height: 12),
          _FaqCard(
            question: 'Can I delete my account myself?',
            answer:
                'Yes. The Delete Account flow in Profile & Settings deactivates your account, signs you out, and revokes refresh-token access for future sessions.',
          ),
          SizedBox(height: 12),
          _FaqCard(
            question: 'How do I suggest a missing mosque?',
            answer:
                'Use Suggest a Mosque in Profile & Settings to submit the mosque name and location details. The app only confirms success after the submission is saved.',
          ),
        ],
      ),
    );
  }
}

class SettingsRateUsScreen extends StatelessWidget {
  const SettingsRateUsScreen({
    super.key,
    this.accountSettingsService,
  });

  final AccountSettingsService? accountSettingsService;

  @override
  Widget build(BuildContext context) {
    return SettingsSupportScreen(
      accountSettingsService: accountSettingsService,
      title: 'Rate Us',
      introTitle: 'Share app feedback',
      signedOutIntro:
          'Tell the team what is working well, what feels rough, and what would make BelieversLens more useful for launch.',
      signedInIntro:
          'Feedback is submitted with your current account so the team can follow up on launch issues and product suggestions.',
      initialSubject: 'Product feedback',
      subjectHintText: 'What should we know about BelieversLens?',
      messageHintText:
          'Share what you liked, what felt confusing, and any improvement you want the team to consider.',
      successMessage: 'Thanks for sharing your feedback.',
      submitLabel: 'Send feedback',
    );
  }
}

class SettingsSupportScreen extends ConsumerStatefulWidget {
  const SettingsSupportScreen({
    super.key,
    this.accountSettingsService,
    this.title = 'Support',
    this.introTitle = 'Contact support',
    this.signedOutIntro =
        'Send the team a short description of the issue, question, or product feedback and we will review it from the saved submission.',
    this.signedInIntro =
        'Messages are submitted under {email} so the team can follow up on your account support request or product feedback.',
    this.initialSubject,
    this.subjectHintText = 'What do you need help with?',
    this.messageHintText =
        'Share the issue, what you expected, and any important details.',
    this.successMessage = 'Support request sent.',
    this.submitLabel = 'Send message',
  });

  final AccountSettingsService? accountSettingsService;
  final String title;
  final String introTitle;
  final String signedOutIntro;
  final String signedInIntro;
  final String? initialSubject;
  final String subjectHintText;
  final String messageHintText;
  final String successMessage;
  final String submitLabel;

  @override
  ConsumerState<SettingsSupportScreen> createState() =>
      _SettingsSupportScreenState();
}

class _SettingsSupportScreenState extends ConsumerState<SettingsSupportScreen> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  late final AccountSettingsService _accountSettingsService;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _accountSettingsService =
        widget.accountSettingsService ?? AccountSettingsService();
    if (widget.initialSubject != null &&
        widget.initialSubject!.trim().isNotEmpty) {
      _subjectController.text = widget.initialSubject!.trim();
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();
    if (_isSubmitting) {
      return;
    }
    if (subject.length < 4 || message.length < 10) {
      _showMessage('Please add a short subject and a detailed message.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _accountSettingsService.submitSupportRequest(
        subject: subject,
        message: message,
      );
      if (!mounted) {
        return;
      }
      _subjectController.clear();
      _messageController.clear();
      if (widget.initialSubject != null &&
          widget.initialSubject!.trim().isNotEmpty) {
        _subjectController.text = widget.initialSubject!.trim();
      }
      _showMessage(widget.successMessage);
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authUserProvider);
    return _SettingsSubpageScaffold(
      title: widget.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoCard(
            title: widget.introTitle,
            body: user == null
                ? widget.signedOutIntro
                : widget.signedInIntro.replaceAll('{email}', user.email),
          ),
          const SizedBox(height: 12),
          _FormCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const ValueKey('settings-support-subject'),
                  controller: _subjectController,
                  decoration: InputDecoration(
                    labelText: 'Subject',
                    hintText: widget.subjectHintText,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('settings-support-message'),
                  controller: _messageController,
                  minLines: 5,
                  maxLines: 7,
                  decoration: InputDecoration(
                    labelText: 'Message',
                    hintText: widget.messageHintText,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  key: const ValueKey('settings-support-submit'),
                  onPressed: _isSubmitting ? null : _submit,
                  child: Text(
                    _isSubmitting ? 'Sending...' : widget.submitLabel,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsSuggestMosqueScreen extends ConsumerStatefulWidget {
  const SettingsSuggestMosqueScreen({
    super.key,
    this.accountSettingsService,
  });

  final AccountSettingsService? accountSettingsService;

  @override
  ConsumerState<SettingsSuggestMosqueScreen> createState() =>
      _SettingsSuggestMosqueScreenState();
}

class _SettingsSuggestMosqueScreenState
    extends ConsumerState<SettingsSuggestMosqueScreen> {
  final _mosqueNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  late final AccountSettingsService _accountSettingsService;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _accountSettingsService =
        widget.accountSettingsService ?? AccountSettingsService();
  }

  @override
  void dispose() {
    _mosqueNameController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final mosqueName = _mosqueNameController.text.trim();
    final city = _cityController.text.trim();
    final country = _countryController.text.trim();
    if (_isSubmitting) {
      return;
    }
    if (mosqueName.length < 2 || city.length < 2 || country.length < 2) {
      _showMessage('Please add the mosque name, city, and country.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _accountSettingsService.submitMosqueSuggestion(
        mosqueName: mosqueName,
        city: city,
        country: country,
        addressLine: _addressController.text,
        notes: _notesController.text,
      );
      if (!mounted) {
        return;
      }
      _mosqueNameController.clear();
      _cityController.clear();
      _countryController.clear();
      _addressController.clear();
      _notesController.clear();
      _showMessage('Mosque suggestion sent.');
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authUserProvider);
    return _SettingsSubpageScaffold(
      title: 'Suggest a Mosque',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoCard(
            title: 'Send a real suggestion',
            body: user == null
                ? 'Share the mosque details you want to add and we will review the saved submission.'
                : 'Suggestions are submitted with your current account so the team can review missing mosque coverage honestly.',
          ),
          const SizedBox(height: 12),
          _FormCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const ValueKey('settings-suggest-mosque-name'),
                  controller: _mosqueNameController,
                  decoration: const InputDecoration(
                    labelText: 'Mosque name',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('settings-suggest-city'),
                  controller: _cityController,
                  decoration: const InputDecoration(
                    labelText: 'City',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('settings-suggest-country'),
                  controller: _countryController,
                  decoration: const InputDecoration(
                    labelText: 'Country',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('settings-suggest-address'),
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address line (optional)',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('settings-suggest-notes'),
                  controller: _notesController,
                  minLines: 4,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    hintText:
                        'Add landmark details, contact context, or anything that helps the review.',
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  key: const ValueKey('settings-suggest-submit'),
                  onPressed: _isSubmitting ? null : _submit,
                  child: Text(
                    _isSubmitting ? 'Sending...' : 'Submit suggestion',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsDeleteAccountScreen extends StatefulWidget {
  const SettingsDeleteAccountScreen({
    super.key,
    this.accountSettingsService,
  });

  final AccountSettingsService? accountSettingsService;

  @override
  State<SettingsDeleteAccountScreen> createState() =>
      _SettingsDeleteAccountScreenState();
}

class _SettingsDeleteAccountScreenState
    extends State<SettingsDeleteAccountScreen> {
  final _confirmationController = TextEditingController();
  late final AccountSettingsService _accountSettingsService;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _accountSettingsService =
        widget.accountSettingsService ?? AccountSettingsService();
  }

  @override
  void dispose() {
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }
    if (_confirmationController.text.trim() != 'DEACTIVATE') {
      _showMessage('Type DEACTIVATE to confirm.');
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Deactivate account?'),
              content: const Text(
                'This will disable your account immediately and sign you out.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Deactivate'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _accountSettingsService.deactivateAccount(
        confirmation: _confirmationController.text,
      );
      if (!mounted) {
        return;
      }
      final route = await AppStartupPolicy().resolveUnauthenticatedRoute();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
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

  @override
  Widget build(BuildContext context) {
    return _SettingsSubpageScaffold(
      title: 'Delete Account',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _InfoCard(
            title: 'Launch-safe account removal',
            body:
                'This flow deactivates your account, revokes refresh-token access, and signs you out. The account stays disabled unless the team restores it later.',
          ),
          const SizedBox(height: 12),
          const _InfoCard(
            title: 'Before you continue',
            body:
                'You will lose normal access to your BelieversLens account, including saved activity, mosque-admin tools, and account-linked settings.',
          ),
          const SizedBox(height: 12),
          _FormCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Type DEACTIVATE to confirm.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryText,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('settings-delete-confirmation'),
                  controller: _confirmationController,
                  decoration: const InputDecoration(
                    labelText: 'Confirmation',
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  key: const ValueKey('settings-delete-submit'),
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD05A48),
                  ),
                  child: Text(
                    _isSubmitting ? 'Deactivating...' : 'Deactivate account',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSubpageScaffold extends StatelessWidget {
  const _SettingsSubpageScaffold({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3EF),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryText,
                          ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.body,
    this.action,
  });

  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFE7E8E2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppColors.primaryText,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}

class _FaqCard extends StatelessWidget {
  const _FaqCard({
    required this.question,
    required this.answer,
  });

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: question,
      body: answer,
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}
