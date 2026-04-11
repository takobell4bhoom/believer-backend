import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_error_mapper.dart';
import '../data/auth_provider.dart';
import '../models/notification_setting.dart';
import '../navigation/app_startup.dart';
import '../services/api_client.dart';
import '../services/mosque_notification_settings_service.dart';
import '../services/mosque_service.dart';
import '../theme/app_colors.dart';
import '../widgets/common/figma_switch.dart';

class MosqueNotificationSettings extends ConsumerStatefulWidget {
  const MosqueNotificationSettings({
    super.key,
    this.mosqueId = 'mosque-1',
    this.mosqueName = 'Islamic Center of South Florida',
    this.settingsService,
    this.mosqueService,
  });

  final String mosqueId;
  final String mosqueName;
  final MosqueNotificationSettingsService? settingsService;
  final MosqueService? mosqueService;

  @override
  ConsumerState<MosqueNotificationSettings> createState() =>
      _MosqueNotificationSettingsState();
}

class MosqueNotificationSettingsRouteArgs {
  const MosqueNotificationSettingsRouteArgs({
    required this.mosqueId,
    required this.mosqueName,
  });

  final String mosqueId;
  final String mosqueName;
}

class _MosqueNotificationSettingsState
    extends ConsumerState<MosqueNotificationSettings> {
  static const _defaultSettings = <NotificationSetting>[
    NotificationSetting(
      title: 'Broadcast Messages',
      description:
          'Show important community announcements from this mosque in your in-app updates feed.',
      isEnabled: false,
    ),
    NotificationSetting(
      title: 'Events & Class Updates',
      description:
          'Show new events, classes, and halaqas from this mosque in your in-app updates feed.',
      isEnabled: false,
    ),
  ];

  late final MosqueNotificationSettingsService _settingsService;
  late final MosqueService _mosqueService;

  List<NotificationSetting>? _settings;
  bool _hasRequestedInitialLoad = false;
  bool _isSaving = false;
  bool _redirectingToLogin = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _settingsService =
        widget.settingsService ?? MosqueNotificationSettingsService();
    _mosqueService = widget.mosqueService ?? MosqueService();
  }

  Future<void> _loadSettings() async {
    final auth = ref.read(authProvider).valueOrNull;
    final token = auth?.accessToken;
    if (token == null || token.isEmpty) {
      _redirectToLogin();
      return;
    }

    setState(() {
      _errorMessage = null;
    });

    try {
      final persisted = await _mosqueService.getNotificationSettings(
        mosqueId: widget.mosqueId,
        bearerToken: token,
      );
      final merged = _mergeSettingsWithDefaults(persisted);
      await _settingsService.save(
        mosqueId: widget.mosqueId,
        settings: merged,
      );

      if (!mounted) return;
      setState(() {
        _settings = merged;
        _errorMessage = null;
      });
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        _redirectToLogin();
        return;
      }

      final cached = await _settingsService.load(
        mosqueId: widget.mosqueId,
        defaults: _defaultSettings,
      );

      if (!mounted) return;
      setState(() {
        _settings = cached;
        _errorMessage = ApiErrorMapper.toUserMessage(error);
      });
    }
  }

  List<NotificationSetting> _mergeSettingsWithDefaults(
    List<NotificationSetting> persisted,
  ) {
    final persistedByTitle = <String, NotificationSetting>{
      for (final setting in persisted)
        _normalizeSettingTitle(setting.title): setting,
    };

    final merged = _defaultSettings.map((defaultSetting) {
      final persistedSetting =
          persistedByTitle[_normalizeSettingTitle(defaultSetting.title)];
      if (persistedSetting == null) {
        return defaultSetting;
      }

      return defaultSetting.copyWith(
        description: persistedSetting.description.trim().isEmpty
            ? defaultSetting.description
            : persistedSetting.description,
        isEnabled: persistedSetting.isEnabled,
      );
    }).toList(growable: true);

    return merged;
  }

  String _normalizeSettingTitle(String title) {
    return title.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<void> _updateSetting(int index, bool value) async {
    final current = _settings;
    if (current == null || _isSaving) return;

    final auth = ref.read(authProvider).valueOrNull;
    final token = auth?.accessToken;
    if (token == null || token.isEmpty) {
      _redirectToLogin();
      return;
    }

    final previous = current[index];
    final next = List<NotificationSetting>.from(current);
    next[index] = previous.copyWith(isEnabled: value);

    setState(() {
      _settings = next;
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await _settingsService.save(
        mosqueId: widget.mosqueId,
        settings: next,
      );

      await _mosqueService.updateNotificationSettings(
        mosqueId: widget.mosqueId,
        settings: next,
        bearerToken: token,
      );
    } catch (error) {
      if (!mounted) return;

      final reverted = List<NotificationSetting>.from(next);
      reverted[index] = previous;
      await _settingsService.save(
        mosqueId: widget.mosqueId,
        settings: reverted,
      );

      if (error is ApiException && error.statusCode == 401) {
        _redirectToLogin();
      }

      setState(() {
        _settings = reverted;
        _errorMessage = ApiErrorMapper.toUserMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _redirectToLogin() {
    if (_redirectingToLogin || !mounted) return;
    _redirectingToLogin = true;
    scheduleUnauthenticatedRedirect(context);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    if (authState.hasValue && authState.valueOrNull == null) {
      _redirectToLogin();
      return const Scaffold(
        backgroundColor: Color(0xFFF6F7F4),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!authState.isLoading &&
        authState.valueOrNull != null &&
        _settings == null &&
        !_hasRequestedInitialLoad) {
      _hasRequestedInitialLoad = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadSettings();
        }
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F4),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 32,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(
                              Icons.arrow_back,
                              color: AppColors.primaryText,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        _buildBody(authState.isLoading),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(bool authLoading) {
    final settings = _settings;

    if (authLoading || settings == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.notification_add_outlined,
            size: 48,
            color: AppColors.accentSoft,
          ),
          const SizedBox(height: 16),
          Text(
            widget.mosqueName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Choose which in-app updates from this mosque you want to follow.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w300,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 14),
          if (_errorMessage != null) ...[
            _InlineErrorCard(
              message: _errorMessage!,
              onRetry: _loadSettings,
            ),
            const SizedBox(height: 12),
          ],
          ...List<Widget>.generate(settings.length, (index) {
            final item = settings[index];
            return Padding(
              padding: EdgeInsets.only(
                  bottom: index == settings.length - 1 ? 0 : 10),
              child: _MosqueNotificationCard(
                key: Key('mosque-notification-card-$index'),
                title: item.title,
                description: item.description,
                isEnabled: item.isEnabled,
                enabled: !_isSaving,
                onChanged: (value) => _updateSetting(index, value),
                toggleKey: Key('mosque-notification-toggle-$index'),
              ),
            );
          }),
          const SizedBox(height: 14),
          const Text.rich(
            TextSpan(
              text: 'See all your followed mosques under ',
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w300,
                color: AppColors.primaryText,
              ),
              children: [
                TextSpan(
                  text: 'My Mosques',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentSoft,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.accentSoft,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          if (_isSaving) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}

class _MosqueNotificationCard extends StatelessWidget {
  const _MosqueNotificationCard({
    super.key,
    required this.title,
    required this.description,
    required this.isEnabled,
    required this.enabled,
    required this.onChanged,
    required this.toggleKey,
  });

  final String title;
  final String description;
  final bool isEnabled;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final Key toggleKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFDDE1DF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
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
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.3,
                    fontWeight: FontWeight.w300,
                    color: AppColors.primaryText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FigmaSwitch(
            key: toggleKey,
            value: isEnabled,
            enabled: enabled,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _InlineErrorCard extends StatelessWidget {
  const _InlineErrorCard({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(
              color: AppColors.error,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ),
        ],
      ),
    );
  }
}
