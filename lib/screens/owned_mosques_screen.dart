import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_provider.dart';
import '../models/mosque_model.dart';
import '../navigation/app_routes.dart';
import '../navigation/mosque_detail_route_args.dart';
import '../services/api_client.dart';
import '../services/mosque_service.dart';
import '../theme/app_colors.dart';
import 'mosque_admin_edit_screen.dart';

enum OwnedMosquesIntent {
  view,
  manage,
  events,
  broadcasts,
}

class OwnedMosquesRouteArgs {
  const OwnedMosquesRouteArgs({
    this.intent = OwnedMosquesIntent.view,
  });

  final OwnedMosquesIntent intent;
}

class OwnedMosquesScreen extends ConsumerStatefulWidget {
  const OwnedMosquesScreen({
    super.key,
    this.routeArgs = const OwnedMosquesRouteArgs(),
    this.mosqueService,
  });

  final OwnedMosquesRouteArgs routeArgs;
  final MosqueService? mosqueService;

  @override
  ConsumerState<OwnedMosquesScreen> createState() => _OwnedMosquesScreenState();
}

class _OwnedMosquesScreenState extends ConsumerState<OwnedMosquesScreen> {
  late final MosqueService _mosqueService;
  bool _isLoading = true;
  String? _errorMessage;
  List<MosqueModel> _ownedMosques = const <MosqueModel>[];

  @override
  void initState() {
    super.initState();
    _mosqueService = widget.mosqueService ?? MosqueService();
    Future<void>.microtask(_loadOwnedMosques);
  }

  Future<void> _loadOwnedMosques() async {
    final token = ref.read(authProvider).valueOrNull?.accessToken;
    if (token == null || token.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Log in with an admin account to manage mosques.';
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final mosques = await _mosqueService.getOwnedMosques(
        bearerToken: token,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _ownedMosques = mosques;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Unable to load your mosques right now.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openMosque(MosqueModel mosque) {
    switch (widget.routeArgs.intent) {
      case OwnedMosquesIntent.view:
        Navigator.of(context).pushNamed(
          AppRoutes.mosqueDetail,
          arguments: MosqueDetailRouteArgs.fromMosque(mosque),
        );
        break;
      case OwnedMosquesIntent.manage:
        Navigator.of(context).pushNamed(
          AppRoutes.adminEditMosque,
          arguments: MosqueAdminEditRouteArgs(mosque: mosque),
        );
        break;
      case OwnedMosquesIntent.events:
        Navigator.of(context).pushNamed(
          AppRoutes.adminEditMosque,
          arguments: MosqueAdminEditRouteArgs(
            mosque: mosque,
            entryPoint: MosqueAdminEditEntryPoint.events,
          ),
        );
        break;
      case OwnedMosquesIntent.broadcasts:
        Navigator.of(context).pushNamed(
          AppRoutes.adminEditMosque,
          arguments: MosqueAdminEditRouteArgs(
            mosque: mosque,
            entryPoint: MosqueAdminEditEntryPoint.broadcasts,
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final currentUser = authState.valueOrNull?.user;

    if (authState.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (currentUser == null || currentUser.role != 'admin') {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Log in with an admin account to open owned mosque tools.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
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
                    child: Column(
                      children: [
                        Text(
                          _screenTitle(widget.routeArgs.intent),
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _screenSubtitle(widget.routeArgs.intent),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadOwnedMosques,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  children: [
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 80),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_errorMessage != null)
                      _OwnedMosquesMessageCard(
                        title: 'Owned mosques unavailable',
                        message: _errorMessage!,
                        primaryLabel: 'Try Again',
                        onPrimary: _loadOwnedMosques,
                      )
                    else if (_ownedMosques.isEmpty)
                      _OwnedMosquesMessageCard(
                        title: 'No owned mosques yet',
                        message:
                            'Create a mosque first, then return here to manage events, broadcasts, and details.',
                        primaryLabel: 'Add Mosque',
                        onPrimary: () => Navigator.of(context)
                            .pushNamed(AppRoutes.adminAddMosque),
                      )
                    else
                      ..._ownedMosques.map(
                        (mosque) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _OwnedMosqueCard(
                            mosque: mosque,
                            buttonLabel: _primaryButtonLabel(
                              widget.routeArgs.intent,
                            ),
                            onPrimary: () => _openMosque(mosque),
                          ),
                        ),
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

String _screenTitle(OwnedMosquesIntent intent) {
  switch (intent) {
    case OwnedMosquesIntent.view:
      return 'My Mosques';
    case OwnedMosquesIntent.manage:
      return 'Manage Owned Mosques';
    case OwnedMosquesIntent.events:
      return 'Publish Events';
    case OwnedMosquesIntent.broadcasts:
      return 'Broadcast Messages';
  }
}

String _screenSubtitle(OwnedMosquesIntent intent) {
  switch (intent) {
    case OwnedMosquesIntent.view:
      return 'Mosques owned by your admin account.';
    case OwnedMosquesIntent.manage:
      return 'Choose a mosque to update its admin-managed content.';
    case OwnedMosquesIntent.events:
      return 'Choose an owned mosque before opening the events editor.';
    case OwnedMosquesIntent.broadcasts:
      return 'Choose an owned mosque before publishing broadcasts.';
  }
}

String _primaryButtonLabel(OwnedMosquesIntent intent) {
  switch (intent) {
    case OwnedMosquesIntent.view:
      return 'Open Page';
    case OwnedMosquesIntent.manage:
      return 'Manage';
    case OwnedMosquesIntent.events:
      return 'Open Events Editor';
    case OwnedMosquesIntent.broadcasts:
      return 'Open Broadcasts';
  }
}

class _OwnedMosquesMessageCard extends StatelessWidget {
  const _OwnedMosquesMessageCard({
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
    return Container(
      margin: const EdgeInsets.only(top: 64),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.mutedText),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onPrimary,
            child: Text(primaryLabel),
          ),
        ],
      ),
    );
  }
}

class _OwnedMosqueCard extends StatelessWidget {
  const _OwnedMosqueCard({
    required this.mosque,
    required this.buttonLabel,
    required this.onPrimary,
  });

  final MosqueModel mosque;
  final String buttonLabel;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mosque.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            [
              mosque.addressLine,
              if (mosque.city.trim().isNotEmpty) mosque.city,
              if (mosque.state.trim().isNotEmpty) mosque.state,
            ].where((value) => value.trim().isNotEmpty).join(', '),
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.mutedText,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (mosque.canEdit)
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
                    'Owned by you',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF304137),
                    ),
                  ),
                ),
              if (mosque.duhrTime.trim().isNotEmpty &&
                  mosque.duhrTime.trim() != '--')
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0EB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Dhuhr ${mosque.duhrTime}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPrimary,
              child: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}
