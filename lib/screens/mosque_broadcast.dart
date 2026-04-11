import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_error_mapper.dart';
import '../data/auth_provider.dart';
import '../models/broadcast_message.dart';
import '../navigation/app_startup.dart';
import '../services/mosque_service.dart';
import '../theme/app_colors.dart';
import '../widgets/common/async_states.dart';
import '../widgets/common/figma_section_heading.dart';

class MosqueBroadcast extends ConsumerStatefulWidget {
  const MosqueBroadcast({
    super.key,
    this.args = const MosqueBroadcastRouteArgs(mosqueId: 'mosque-1'),
    this.mosqueService,
  });

  final MosqueBroadcastRouteArgs args;
  final MosqueService? mosqueService;

  @override
  ConsumerState<MosqueBroadcast> createState() => _MosqueBroadcastState();
}

class MosqueBroadcastRouteArgs {
  const MosqueBroadcastRouteArgs({
    required this.mosqueId,
    this.mosqueName,
  });

  final String mosqueId;
  final String? mosqueName;
}

class _MosqueBroadcastState extends ConsumerState<MosqueBroadcast> {
  late final MosqueService _mosqueService;

  bool _isLoading = true;
  bool _redirectingToLogin = false;
  List<BroadcastMessage> _messages = const <BroadcastMessage>[];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _mosqueService = widget.mosqueService ?? MosqueService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadMessages();
    });
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (!mounted) return;
      final messages =
          await _mosqueService.getMosqueBroadcastMessages(widget.args.mosqueId);
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = ApiErrorMapper.toUserMessage(error);
        _isLoading = false;
      });
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
        backgroundColor: _BroadcastPalette.screen,
        body: LoadingState(label: 'Redirecting...'),
      );
    }

    if (authState.isLoading || _isLoading) {
      return const Scaffold(
        backgroundColor: _BroadcastPalette.screen,
        body: LoadingState(label: 'Loading mosque messages...'),
      );
    }

    final mosqueName = widget.args.mosqueName ?? 'Mosque Broadcast';
    return Scaffold(
      backgroundColor: _BroadcastPalette.screen,
      body: _BroadcastScaffold(
        mosqueName: mosqueName,
        child: _errorMessage != null
            ? _BroadcastStatePanel(
                child: ErrorState(
                  message: _errorMessage!,
                  onRetry: _loadMessages,
                ),
              )
            : _messages.isEmpty
                ? const _BroadcastStatePanel(
                    child: EmptyState(
                      title: 'No messages to show.',
                      subtitle: 'Broadcast updates will appear here.',
                    ),
                  )
                : _BroadcastMessagePanel(messages: _messages),
      ),
    );
  }
}

class _BroadcastScaffold extends StatelessWidget {
  const _BroadcastScaffold({
    required this.mosqueName,
    required this.child,
  });

  final String mosqueName;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BroadcastTopBar(mosqueName: mosqueName),
                const SizedBox(height: 11),
                const Divider(
                  thickness: 1,
                  height: 1,
                  color: _BroadcastPalette.headerDivider,
                ),
                const SizedBox(height: 15),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 320;
                    return FigmaSectionHeading(
                      title: 'BROADCAST MESSAGES',
                      showDivider: true,
                      style: TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 13,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        letterSpacing: isCompact ? 2.8 : 4.2,
                        color: AppColors.primaryText,
                      ),
                      dividerColor: _BroadcastPalette.headerDivider,
                      gap: isCompact ? 6 : 10,
                    );
                  },
                ),
                const SizedBox(height: 10),
                const Padding(
                  padding: EdgeInsets.only(right: 28),
                  child: Text(
                    'Messages shared over the past 60 days are listed here',
                    style: TextStyle(
                      fontFamily: 'Figtree',
                      fontSize: 14,
                      height: 1.2,
                      fontWeight: FontWeight.w400,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BroadcastTopBar extends StatelessWidget {
  const _BroadcastTopBar({required this.mosqueName});

  final String mosqueName;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              padding: EdgeInsets.zero,
              splashRadius: 18,
              constraints: const BoxConstraints.tightFor(width: 28, height: 28),
              icon: const Icon(
                Icons.arrow_back,
                size: 24,
                color: AppColors.primaryText,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              mosqueName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Figtree',
                fontSize: 17,
                height: 1.1,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BroadcastStatePanel extends StatelessWidget {
  const _BroadcastStatePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 260),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
        decoration: BoxDecoration(
          color: _BroadcastPalette.panel,
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      ),
    );
  }
}

class _BroadcastMessagePanel extends StatelessWidget {
  const _BroadcastMessagePanel({required this.messages});

  final List<BroadcastMessage> messages;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: _BroadcastPalette.panel,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: List.generate(messages.length, (index) {
            final message = messages[index];
            return Column(
              children: [
                _BroadcastEntry(message: message),
                if (index != messages.length - 1) ...[
                  const SizedBox(height: 16),
                  const Divider(
                    thickness: 1,
                    color: _BroadcastPalette.entryDivider,
                    height: 1,
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _BroadcastEntry extends StatelessWidget {
  const _BroadcastEntry({required this.message});

  final BroadcastMessage message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  message.title,
                  style: const TextStyle(
                    fontFamily: 'Figtree',
                    fontSize: 16,
                    height: 1.18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                  ),
                ),
              ),
            ),
            if (message.displayDate.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 78),
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    message.displayDate,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontFamily: 'Figtree',
                      fontSize: 14,
                      height: 1.1,
                      fontWeight: FontWeight.w500,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          message.description,
          style: const TextStyle(
            fontFamily: 'Figtree',
            fontSize: 14,
            height: 1.22,
            fontWeight: FontWeight.w300,
            color: AppColors.secondaryText,
          ),
        ),
      ],
    );
  }
}

class _BroadcastPalette {
  static const screen = Color(0xFFF6F7F4);
  static const headerDivider = Color(0xFFD7DBD8);
  static const panel = Color(0xFFDDE1DE);
  static const entryDivider = Color(0xFFB8BEBA);
}
