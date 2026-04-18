import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_provider.dart';
import '../core/api_error_mapper.dart';
import '../features/business_registration/business_registration_models.dart';
import '../navigation/app_routes.dart';
import '../navigation/app_startup.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'owned_mosques_screen.dart';

class ProfileSettingsScreen extends ConsumerStatefulWidget {
  const ProfileSettingsScreen({
    super.key,
    this.authService,
  });

  final AuthService? authService;

  @override
  ConsumerState<ProfileSettingsScreen> createState() =>
      _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen> {
  late final AuthService _authService;
  bool _isSavingProfile = false;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openEditProfile(AuthUser user) async {
    final controller = TextEditingController(text: user.fullName);
    try {
      final nextName = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Edit Profile'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Full name',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(controller.text.trim()),
                child: const Text('Save'),
              ),
            ],
          );
        },
      );

      if (!mounted || nextName == null || nextName.trim().isEmpty) {
        return;
      }

      setState(() => _isSavingProfile = true);
      await _authService.updateProfile(fullName: nextName.trim());
      if (!mounted) {
        return;
      }
      _showMessage('Profile updated.');
    } on ApiException catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Unable to update your profile right now.');
      }
    } finally {
      controller.dispose();
      if (mounted) {
        setState(() => _isSavingProfile = false);
      }
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (!mounted) {
      return;
    }
    final route = await AppStartupPolicy().resolveUnauthenticatedRoute();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil(
      route,
      (_) => false,
    );
  }

  void _openOwnedMosques(OwnedMosquesIntent intent) {
    Navigator.of(context).pushNamed(
      AppRoutes.ownedMosques,
      arguments: OwnedMosquesRouteArgs(intent: intent),
    );
  }

  Future<void> _openChangePasswordDialog() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return _ChangePasswordDialog(authService: _authService);
      },
    );

    if (!mounted || changed != true) {
      return;
    }

    _showMessage('Password updated.');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final session = authState.valueOrNull;
    final user = session?.user;

    if (authState.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

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
                      'Profile & Settings',
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
                child: user == null
                    ? _GuestSettingsCard(
                        onLogin: () => Navigator.of(context)
                            .pushReplacementNamed(AppRoutes.login),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SummaryCard(
                            key: const ValueKey('profile-settings-summary'),
                            user: user,
                            isSavingProfile: _isSavingProfile,
                            onEditProfile: () => _openEditProfile(user),
                            onChangePassword: _openChangePasswordDialog,
                          ),
                          const SizedBox(height: 12),
                          _SettingsCard(
                            children: [
                              _ActionRow(
                                title: 'Mosque Updates',
                                subtitle:
                                    'Manage followed mosques and in-app updates from the Notifications tab.',
                                onTap: () => Navigator.of(context).pushNamed(
                                  AppRoutes.notifications,
                                ),
                              ),
                              _ActionRow(
                                title: 'Register as a Business',
                                subtitle:
                                    'Start or resume your business listing draft.',
                                onTap: () => Navigator.of(context).pushNamed(
                                  AppRoutes.businessRegistrationIntro,
                                  arguments:
                                      const BusinessRegistrationFlowRouteArgs(
                                    exitRouteName: AppRoutes.profileSettings,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (user.role == 'admin') ...[
                            const SizedBox(height: 16),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                'Admin',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF304137),
                                    ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _SettingsCard(
                              key: const ValueKey(
                                'profile-settings-admin-section',
                              ),
                              children: [
                                const _ActionRow(
                                  title: 'Profile & Settings',
                                  subtitle: 'You are here',
                                  enabled: false,
                                ),
                                _ActionRow(
                                  title: 'My Mosques',
                                  onTap: () => _openOwnedMosques(
                                      OwnedMosquesIntent.view),
                                ),
                                _ActionRow(
                                  title: 'Add Mosque',
                                  onTap: () => Navigator.of(context)
                                      .pushNamed(AppRoutes.adminAddMosque),
                                ),
                                _ActionRow(
                                  title: 'Manage Owned Mosques',
                                  onTap: () => _openOwnedMosques(
                                    OwnedMosquesIntent.manage,
                                  ),
                                ),
                                _ActionRow(
                                  title: 'Publish Events',
                                  onTap: () => _openOwnedMosques(
                                    OwnedMosquesIntent.events,
                                  ),
                                ),
                                _ActionRow(
                                  title: 'Broadcast Messages',
                                  onTap: () => _openOwnedMosques(
                                    OwnedMosquesIntent.broadcasts,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (user.role == 'super_admin') ...[
                            const SizedBox(height: 16),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                'Super Admin',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF304137),
                                    ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _SettingsCard(
                              key: const ValueKey(
                                'profile-settings-super-admin-section',
                              ),
                              children: [
                                _ActionRow(
                                  key: const ValueKey(
                                    'profile-settings-super-admin-panel',
                                  ),
                                  title: 'Admin Panel',
                                  subtitle:
                                      'Open the unified moderation and customer account panel.',
                                  onTap: () => Navigator.of(context)
                                      .pushNamed(AppRoutes.superAdminPanel),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),
                          _SettingsCard(
                            children: [
                              _ActionRow(
                                title: 'About',
                                onTap: () => Navigator.of(context)
                                    .pushNamed(AppRoutes.settingsAbout),
                              ),
                              _ActionRow(
                                title: 'Privacy',
                                onTap: () => Navigator.of(context)
                                    .pushNamed(AppRoutes.settingsPrivacy),
                              ),
                              _ActionRow(
                                title: 'Rate Us',
                                subtitle:
                                    'Share product feedback with the BelieversLens team.',
                                onTap: () => Navigator.of(context)
                                    .pushNamed(AppRoutes.settingsRateUs),
                              ),
                              _ActionRow(
                                title: 'Suggest a Mosque',
                                onTap: () => Navigator.of(context).pushNamed(
                                  AppRoutes.settingsSuggestMosque,
                                ),
                              ),
                              _ActionRow(
                                title: 'FAQs',
                                onTap: () => Navigator.of(context)
                                    .pushNamed(AppRoutes.settingsFaq),
                              ),
                              _ActionRow(
                                title: 'Support',
                                subtitle: 'Get help or share product feedback.',
                                onTap: () => Navigator.of(context)
                                    .pushNamed(AppRoutes.settingsSupport),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _SettingsCard(
                            children: [
                              _ActionRow(
                                title: 'Delete Account',
                                titleColor: AppColors.primaryText,
                                onTap: () => Navigator.of(context).pushNamed(
                                  AppRoutes.settingsDeleteAccount,
                                ),
                              ),
                              _ActionRow(
                                key: const ValueKey(
                                  'profile-settings-logout',
                                ),
                                title: 'Log Out',
                                titleColor: const Color(0xFFD05A48),
                                onTap: _logout,
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestSettingsCard extends StatelessWidget {
  const _GuestSettingsCard({
    required this.onLogin,
  });

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sign in to manage your account, mosque updates, and saved activity.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.primaryText,
                ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onLogin,
              child: const Text('Log In or Sign Up'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    super.key,
    required this.user,
    required this.isSavingProfile,
    required this.onEditProfile,
    required this.onChangePassword,
  });

  final AuthUser user;
  final bool isSavingProfile;
  final VoidCallback onEditProfile;
  final VoidCallback onChangePassword;

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.mutedText,
                      ),
                    ),
                    if (user.role == 'admin') ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE1EADB),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Mosque Admin',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF304137),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                key: const ValueKey('profile-settings-edit-profile'),
                onPressed: isSavingProfile ? null : onEditProfile,
                icon: isSavingProfile
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.edit_outlined),
              ),
            ],
          ),
        ),
        _ActionRow(
          title: 'Edit Profile',
          onTap: isSavingProfile ? null : onEditProfile,
        ),
        _ActionRow(
          key: const ValueKey('profile-settings-change-password'),
          title: 'Change Password',
          subtitle: 'Current password required',
          onTap: onChangePassword,
        ),
      ],
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({
    required this.authService,
  });

  final AuthService authService;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSubmitting = false;
  String? _currentPasswordErrorText;
  String? _newPasswordErrorText;
  String? _confirmPasswordErrorText;
  String? _errorText;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    final currentPasswordError = ApiErrorMapper.validatePassword(
      _currentPasswordController.text,
    );
    final newPasswordError = ApiErrorMapper.validatePassword(
      _newPasswordController.text,
    );
    final confirmPasswordError = ApiErrorMapper.validatePasswordConfirmation(
      _newPasswordController.text,
      _confirmPasswordController.text,
    );
    final passwordReuseError =
        _currentPasswordController.text == _newPasswordController.text
            ? 'Choose a new password that is different from your current one.'
            : null;

    setState(() {
      _currentPasswordErrorText = currentPasswordError;
      _newPasswordErrorText = newPasswordError ?? passwordReuseError;
      _confirmPasswordErrorText = confirmPasswordError;
      _errorText = null;
    });

    if (currentPasswordError != null ||
        newPasswordError != null ||
        confirmPasswordError != null ||
        passwordReuseError != null) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await widget.authService.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (error.errorCode == 'INVALID_CURRENT_PASSWORD') {
          _currentPasswordErrorText = ApiErrorMapper.toUserMessage(error);
          _errorText = null;
        } else if (error.errorCode == 'PASSWORD_REUSE_NOT_ALLOWED') {
          _newPasswordErrorText = ApiErrorMapper.toUserMessage(error);
          _errorText = null;
        } else {
          _errorText = ApiErrorMapper.toUserMessage(error);
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = ApiErrorMapper.toUserMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change Password'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('change-password-current'),
              controller: _currentPasswordController,
              obscureText: true,
              onChanged: (_) => setState(() {
                _currentPasswordErrorText = null;
                _errorText = null;
              }),
              decoration: InputDecoration(
                labelText: 'Current password',
                errorText: _currentPasswordErrorText,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('change-password-new'),
              controller: _newPasswordController,
              obscureText: true,
              onChanged: (_) => setState(() {
                _newPasswordErrorText = null;
                _confirmPasswordErrorText = null;
                _errorText = null;
              }),
              decoration: InputDecoration(
                labelText: 'New password',
                errorText: _newPasswordErrorText,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('change-password-confirm'),
              controller: _confirmPasswordController,
              obscureText: true,
              onChanged: (_) => setState(() {
                _confirmPasswordErrorText = null;
                _errorText = null;
              }),
              decoration: InputDecoration(
                labelText: 'Confirm new password',
                errorText: _confirmPasswordErrorText,
              ),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorText!,
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: Text(_isSubmitting ? 'Saving...' : 'Update Password'),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE7E8E2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(children: children),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    super.key,
    required this.title,
    this.subtitle,
    this.onTap,
    this.enabled = true,
    this.titleColor,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool enabled;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final rowColor =
        enabled ? (titleColor ?? AppColors.primaryText) : AppColors.mutedText;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: rowColor,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.mutedText,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: enabled ? AppColors.mutedText : Colors.transparent,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              height: 1,
              color: const Color(0xFFCBCFC6),
            ),
          ],
        ),
      ),
    );
  }
}
