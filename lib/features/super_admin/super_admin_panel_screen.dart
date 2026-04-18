import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_provider.dart';
import '../../navigation/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../business_moderation/business_moderation_service.dart';
import '../mosque_moderation/mosque_moderation_service.dart';
import 'super_admin_models.dart';
import 'super_admin_service.dart';

class SuperAdminPanelScreen extends ConsumerStatefulWidget {
  const SuperAdminPanelScreen({
    super.key,
    this.service = const SuperAdminService(),
  });

  final SuperAdminService service;

  @override
  ConsumerState<SuperAdminPanelScreen> createState() =>
      _SuperAdminPanelScreenState();
}

class _SuperAdminPanelScreenState extends ConsumerState<SuperAdminPanelScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool _requestedInitialLoad = false;
  bool _isOverviewLoading = false;
  bool _isCustomerLoading = false;
  String? _overviewError;
  String? _customerError;

  List<MosqueModerationItem> _pendingMosques = const <MosqueModerationItem>[];
  List<BusinessModerationListing> _pendingBusinesses =
      const <BusinessModerationListing>[];
  SuperAdminCustomerPage _customerPage = const SuperAdminCustomerPage(
    items: <SuperAdminCustomer>[],
    page: 1,
    limit: 20,
    total: 0,
    totalPages: 0,
  );

  final Set<String> _actingMosqueIds = <String>{};
  final Set<String> _actingBusinessIds = <String>{};
  final Set<String> _actingCustomerIds = <String>{};
  final Set<String> _resettingCustomerIds = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait<void>([
      _loadOverview(),
      _loadCustomers(page: 1),
    ]);
  }

  Future<void> _loadOverview() async {
    final token = ref.read(authProvider).valueOrNull?.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }

    setState(() {
      _isOverviewLoading = true;
      _overviewError = null;
    });

    try {
      final results = await Future.wait<Object>([
        widget.service.fetchPendingMosques(bearerToken: token),
        widget.service.fetchPendingBusinesses(bearerToken: token),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _pendingMosques = results[0] as List<MosqueModerationItem>;
        _pendingBusinesses = results[1] as List<BusinessModerationListing>;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _overviewError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isOverviewLoading = false;
        });
      }
    }
  }

  Future<void> _loadCustomers({int page = 1}) async {
    final token = ref.read(authProvider).valueOrNull?.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }

    setState(() {
      _isCustomerLoading = true;
      _customerError = null;
    });

    try {
      final response = await widget.service.fetchCustomers(
        bearerToken: token,
        search: _searchController.text.trim(),
        page: page,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _customerPage = response;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _customerError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCustomerLoading = false;
        });
      }
    }
  }

  void _removeMosque(String mosqueId) {
    setState(() {
      _pendingMosques = _pendingMosques
          .where((item) => item.id != mosqueId)
          .toList(growable: false);
    });
  }

  void _removeBusiness(String listingId) {
    setState(() {
      _pendingBusinesses = _pendingBusinesses
          .where((item) => item.id != listingId)
          .toList(growable: false);
    });
  }

  void _updateCustomer(SuperAdminCustomer updated) {
    final nextItems = _customerPage.items
        .map((item) => item.id == updated.id ? updated : item)
        .toList(growable: false);

    setState(() {
      _customerPage = SuperAdminCustomerPage(
        items: nextItems,
        page: _customerPage.page,
        limit: _customerPage.limit,
        total: _customerPage.total,
        totalPages: _customerPage.totalPages,
      );
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<String?> _promptRejectionReason({
    required String title,
    required String hintText,
    required String actionLabel,
    required String fieldKey,
  }) {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final value = controller.text.trim();
            return AlertDialog(
              title: Text(title),
              content: TextField(
                key: ValueKey(fieldKey),
                controller: controller,
                maxLines: 4,
                autofocus: true,
                decoration: InputDecoration(hintText: hintText),
                onChanged: (_) => setDialogState(() {}),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: value.length < 3
                      ? null
                      : () => Navigator.of(dialogContext).pop(value),
                  child: Text(actionLabel),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(controller.dispose);
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    required String actionLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(actionLabel),
            ),
          ],
        );
      },
    );

    return confirmed == true;
  }

  Future<void> _approveMosque(MosqueModerationItem mosque) async {
    final token = ref.read(authProvider).valueOrNull?.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }

    setState(() {
      _actingMosqueIds.add(mosque.id);
    });

    try {
      await widget.service.approveMosque(
        mosqueId: mosque.id,
        bearerToken: token,
      );
      _removeMosque(mosque.id);
      _showMessage('Mosque approved and now live.');
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _actingMosqueIds.remove(mosque.id);
        });
      }
    }
  }

  Future<void> _rejectMosque(MosqueModerationItem mosque) async {
    final token = ref.read(authProvider).valueOrNull?.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }

    final rejectionReason = await _promptRejectionReason(
      title: 'Reject Mosque',
      hintText: 'Add a short reason for the submitter',
      actionLabel: 'Reject',
      fieldKey: 'super-admin-panel-mosque-rejection-reason',
    );

    if (!mounted || rejectionReason == null) {
      return;
    }

    setState(() {
      _actingMosqueIds.add(mosque.id);
    });

    try {
      await widget.service.rejectMosque(
        mosqueId: mosque.id,
        rejectionReason: rejectionReason,
        bearerToken: token,
      );
      _removeMosque(mosque.id);
      _showMessage('Mosque rejected.');
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _actingMosqueIds.remove(mosque.id);
        });
      }
    }
  }

  Future<void> _approveBusiness(BusinessModerationListing listing) async {
    final token = ref.read(authProvider).valueOrNull?.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }

    setState(() {
      _actingBusinessIds.add(listing.id);
    });

    try {
      await widget.service.approveBusiness(
        listingId: listing.id,
        bearerToken: token,
      );
      _removeBusiness(listing.id);
      _showMessage('Business listing approved.');
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _actingBusinessIds.remove(listing.id);
        });
      }
    }
  }

  Future<void> _rejectBusiness(BusinessModerationListing listing) async {
    final token = ref.read(authProvider).valueOrNull?.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }

    final rejectionReason = await _promptRejectionReason(
      title: 'Reject Business Listing',
      hintText: 'Add a short reason for the submitter',
      actionLabel: 'Reject',
      fieldKey: 'super-admin-panel-business-rejection-reason',
    );

    if (!mounted || rejectionReason == null) {
      return;
    }

    setState(() {
      _actingBusinessIds.add(listing.id);
    });

    try {
      await widget.service.rejectBusiness(
        listingId: listing.id,
        rejectionReason: rejectionReason,
        bearerToken: token,
      );
      _removeBusiness(listing.id);
      _showMessage('Business listing rejected.');
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _actingBusinessIds.remove(listing.id);
        });
      }
    }
  }

  Future<void> _deactivateCustomer(SuperAdminCustomer customer) async {
    final token = ref.read(authProvider).valueOrNull?.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }

    final confirmed = await _confirmAction(
      title: 'Deactivate account?',
      message:
          'This will disable sign-in for ${customer.fullName.isEmpty ? customer.email : customer.fullName}.',
      actionLabel: 'Deactivate',
    );
    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _actingCustomerIds.add(customer.id);
    });

    try {
      final updated = await widget.service.deactivateUser(
        userId: customer.id,
        bearerToken: token,
      );
      _updateCustomer(updated);
      _showMessage('Account deactivated.');
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _actingCustomerIds.remove(customer.id);
        });
      }
    }
  }

  Future<void> _reactivateCustomer(SuperAdminCustomer customer) async {
    final token = ref.read(authProvider).valueOrNull?.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }

    setState(() {
      _actingCustomerIds.add(customer.id);
    });

    try {
      final updated = await widget.service.reactivateUser(
        userId: customer.id,
        bearerToken: token,
      );
      _updateCustomer(updated);
      _showMessage('Account reactivated.');
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _actingCustomerIds.remove(customer.id);
        });
      }
    }
  }

  Future<void> _triggerPasswordReset(SuperAdminCustomer customer) async {
    final token = ref.read(authProvider).valueOrNull?.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }

    final confirmed = await _confirmAction(
      title: 'Send password reset email?',
      message:
          'This sends a secure password reset email to ${customer.email}. No password will be shown in the panel.',
      actionLabel: 'Send Email',
    );
    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _resettingCustomerIds.add(customer.id);
    });

    try {
      await widget.service.triggerPasswordReset(
        userId: customer.id,
        bearerToken: token,
      );
      _showMessage('Password reset email sent.');
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _resettingCustomerIds.remove(customer.id);
        });
      }
    }
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

    if (user == null) {
      return _AdminAccessState(
        title: 'Admin Panel',
        message:
            'Log in with a super admin account to manage moderation and customer accounts.',
        primaryLabel: 'Go to Login',
        onPrimary: () => Navigator.of(context).pushReplacementNamed(
          AppRoutes.login,
        ),
      );
    }

    if (user.role != 'super_admin') {
      return _AdminAccessState(
        title: 'Admin Panel',
        message:
            'Only super admins can open this panel. Your current account does not have access.',
        primaryLabel: 'Back to Settings',
        onPrimary: () => Navigator.of(context).pushReplacementNamed(
          AppRoutes.profileSettings,
        ),
      );
    }

    if (!_requestedInitialLoad) {
      _requestedInitialLoad = true;
      Future<void>.microtask(_loadAll);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3EF),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 980;
            final content = [
              _PanelCard(
                child: _ModerationSection(
                  title: 'Mosques',
                  subtitle: 'Pending mosque approvals and rejections',
                  count: _pendingMosques.length,
                  isLoading: _isOverviewLoading,
                  errorMessage: _overviewError,
                  emptyMessage: 'No mosque submissions are waiting for review.',
                  actionLabel: 'Open Mosque Moderation',
                  onAction: () => Navigator.of(context).pushNamed(
                    AppRoutes.mosqueModeration,
                  ),
                  children: _pendingMosques
                      .take(3)
                      .map(
                        (mosque) => _ModerationItemCard(
                          title: mosque.name,
                          subtitle: mosque.city.isEmpty
                              ? mosque.submitter.fullName
                              : '${mosque.city} • ${mosque.submitter.fullName}',
                          trailing: mosque.submittedAt == null
                              ? null
                              : 'Submitted ${_formatDate(mosque.submittedAt)}',
                          actionWidgets: [
                            OutlinedButton(
                              key: ValueKey(
                                'super-admin-panel-mosque-reject-${mosque.id}',
                              ),
                              onPressed: _actingMosqueIds.contains(mosque.id)
                                  ? null
                                  : () => _rejectMosque(mosque),
                              child: const Text('Reject'),
                            ),
                            FilledButton(
                              key: ValueKey(
                                'super-admin-panel-mosque-approve-${mosque.id}',
                              ),
                              onPressed: _actingMosqueIds.contains(mosque.id)
                                  ? null
                                  : () => _approveMosque(mosque),
                              child: const Text('Approve'),
                            ),
                          ],
                        ),
                      )
                      .toList(growable: false),
                  overflowLabel: _pendingMosques.length > 3
                      ? '${_pendingMosques.length - 3} more mosque submissions waiting'
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              _PanelCard(
                child: _ModerationSection(
                  title: 'Businesses',
                  subtitle: 'Pending business listing approvals and rejections',
                  count: _pendingBusinesses.length,
                  isLoading: _isOverviewLoading,
                  errorMessage: _overviewError,
                  emptyMessage: 'No business listings are waiting for review.',
                  actionLabel: 'Open Business Moderation',
                  onAction: () => Navigator.of(context).pushNamed(
                    AppRoutes.businessModeration,
                  ),
                  children: _pendingBusinesses
                      .take(3)
                      .map(
                        (listing) => _ModerationItemCard(
                          title: listing.businessName,
                          subtitle: listing.city.isEmpty
                              ? listing.submitter.fullName
                              : '${listing.city} • ${listing.submitter.fullName}',
                          trailing: listing.submittedAt == null
                              ? null
                              : 'Submitted ${_formatDate(listing.submittedAt)}',
                          actionWidgets: [
                            OutlinedButton(
                              key: ValueKey(
                                'super-admin-panel-business-reject-${listing.id}',
                              ),
                              onPressed: _actingBusinessIds.contains(listing.id)
                                  ? null
                                  : () => _rejectBusiness(listing),
                              child: const Text('Reject'),
                            ),
                            FilledButton(
                              key: ValueKey(
                                'super-admin-panel-business-approve-${listing.id}',
                              ),
                              onPressed: _actingBusinessIds.contains(listing.id)
                                  ? null
                                  : () => _approveBusiness(listing),
                              child: const Text('Approve'),
                            ),
                          ],
                        ),
                      )
                      .toList(growable: false),
                  overflowLabel: _pendingBusinesses.length > 3
                      ? '${_pendingBusinesses.length - 3} more business listings waiting'
                      : null,
                ),
              ),
            ];

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Header(
                        onBack: () => Navigator.of(context).maybePop(),
                        onRefresh: _loadAll,
                      ),
                      const SizedBox(height: 18),
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: Column(
                                children: content,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 6,
                              child: _PanelCard(
                                child: _CustomersSection(
                                  currentUserId: user.id,
                                  page: _customerPage,
                                  isLoading: _isCustomerLoading,
                                  errorMessage: _customerError,
                                  searchController: _searchController,
                                  onSearch: () => _loadCustomers(page: 1),
                                  onPreviousPage: _customerPage.page > 1
                                      ? () => _loadCustomers(
                                            page: _customerPage.page - 1,
                                          )
                                      : null,
                                  onNextPage: _customerPage.page <
                                          _customerPage.totalPages
                                      ? () => _loadCustomers(
                                            page: _customerPage.page + 1,
                                          )
                                      : null,
                                  isActingCustomerIds: _actingCustomerIds,
                                  resettingCustomerIds: _resettingCustomerIds,
                                  onDeactivate: _deactivateCustomer,
                                  onReactivate: _reactivateCustomer,
                                  onPasswordReset: _triggerPasswordReset,
                                ),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        ...content,
                        const SizedBox(height: 16),
                        _PanelCard(
                          child: _CustomersSection(
                            currentUserId: user.id,
                            page: _customerPage,
                            isLoading: _isCustomerLoading,
                            errorMessage: _customerError,
                            searchController: _searchController,
                            onSearch: () => _loadCustomers(page: 1),
                            onPreviousPage: _customerPage.page > 1
                                ? () => _loadCustomers(
                                      page: _customerPage.page - 1,
                                    )
                                : null,
                            onNextPage:
                                _customerPage.page < _customerPage.totalPages
                                    ? () => _loadCustomers(
                                          page: _customerPage.page + 1,
                                        )
                                    : null,
                            isActingCustomerIds: _actingCustomerIds,
                            resettingCustomerIds: _resettingCustomerIds,
                            onDeactivate: _deactivateCustomer,
                            onReactivate: _reactivateCustomer,
                            onPasswordReset: _triggerPasswordReset,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static String _formatDate(DateTime? value) {
    if (value == null) {
      return 'Unknown';
    }

    final local = value.toLocal();
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months[local.month - 1];
    return '$month ${local.day}, ${local.year}';
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onBack,
    required this.onRefresh,
  });

  final VoidCallback onBack;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Admin Panel',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryText,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Moderate mosques, review business listings, and handle customer account operations.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.secondaryText,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: () {
            onRefresh();
          },
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Refresh'),
        ),
      ],
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({
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
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.line),
      ),
      child: child,
    );
  }
}

class _ModerationSection extends StatelessWidget {
  const _ModerationSection({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.isLoading,
    required this.errorMessage,
    required this.emptyMessage,
    required this.actionLabel,
    required this.onAction,
    required this.children,
    required this.overflowLabel,
  });

  final String title;
  final String subtitle;
  final int count;
  final bool isLoading;
  final String? errorMessage;
  final String emptyMessage;
  final String actionLabel;
  final VoidCallback onAction;
  final List<Widget> children;
  final String? overflowLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryText,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.secondaryText,
                        ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                '$count pending',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (isLoading)
          const Center(child: CircularProgressIndicator())
        else if (errorMessage != null)
          Text(
            errorMessage!,
            style: const TextStyle(color: AppColors.error),
          )
        else if (children.isEmpty)
          Text(
            emptyMessage,
            style: const TextStyle(color: AppColors.mutedText),
          )
        else ...[
          ...children,
          if (overflowLabel != null) ...[
            const SizedBox(height: 12),
            Text(
              overflowLabel!,
              style: const TextStyle(color: AppColors.mutedText),
            ),
          ],
        ],
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: onAction,
          child: Text(actionLabel),
        ),
      ],
    );
  }
}

class _ModerationItemCard extends StatelessWidget {
  const _ModerationItemCard({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.actionWidgets,
  });

  final String title;
  final String subtitle;
  final String? trailing;
  final List<Widget> actionWidgets;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryText,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.secondaryText,
                ),
          ),
          if (trailing != null) ...[
            const SizedBox(height: 4),
            Text(
              trailing!,
              style: const TextStyle(color: AppColors.mutedText),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: actionWidgets,
          ),
        ],
      ),
    );
  }
}

class _CustomersSection extends StatelessWidget {
  const _CustomersSection({
    required this.currentUserId,
    required this.page,
    required this.isLoading,
    required this.errorMessage,
    required this.searchController,
    required this.onSearch,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.isActingCustomerIds,
    required this.resettingCustomerIds,
    required this.onDeactivate,
    required this.onReactivate,
    required this.onPasswordReset,
  });

  final String currentUserId;
  final SuperAdminCustomerPage page;
  final bool isLoading;
  final String? errorMessage;
  final TextEditingController searchController;
  final VoidCallback onSearch;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final Set<String> isActingCustomerIds;
  final Set<String> resettingCustomerIds;
  final ValueChanged<SuperAdminCustomer> onDeactivate;
  final ValueChanged<SuperAdminCustomer> onReactivate;
  final ValueChanged<SuperAdminCustomer> onPasswordReset;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Customers',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primaryText,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Search accounts and apply safe account actions.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.secondaryText,
              ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('super-admin-panel-customer-search'),
                controller: searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search by name or email',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                ),
                onSubmitted: (_) => onSearch(),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: onSearch,
              child: const Text('Search'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          page.total == 0
              ? 'No matching accounts found.'
              : 'Showing ${page.items.length} of ${page.total} accounts',
          style: const TextStyle(color: AppColors.mutedText),
        ),
        const SizedBox(height: 14),
        if (isLoading)
          const Center(child: CircularProgressIndicator())
        else if (errorMessage != null)
          Text(
            errorMessage!,
            style: const TextStyle(color: AppColors.error),
          )
        else if (page.items.isEmpty)
          const Text(
            'No customer accounts match the current search.',
            style: TextStyle(color: AppColors.mutedText),
          )
        else
          ...page.items.map(
            (customer) => _CustomerTile(
              customer: customer,
              isProtected: customer.role == 'super_admin' ||
                  customer.id == currentUserId,
              isActing: isActingCustomerIds.contains(customer.id),
              isResetting: resettingCustomerIds.contains(customer.id),
              onDeactivate: () => onDeactivate(customer),
              onReactivate: () => onReactivate(customer),
              onPasswordReset: () => onPasswordReset(customer),
            ),
          ),
        if (page.totalPages > 1) ...[
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton(
                onPressed: onPreviousPage,
                child: const Text('Previous'),
              ),
              Text(
                'Page ${page.page} of ${page.totalPages}',
                style: const TextStyle(color: AppColors.secondaryText),
              ),
              OutlinedButton(
                onPressed: onNextPage,
                child: const Text('Next'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({
    required this.customer,
    required this.isProtected,
    required this.isActing,
    required this.isResetting,
    required this.onDeactivate,
    required this.onReactivate,
    required this.onPasswordReset,
  });

  final SuperAdminCustomer customer;
  final bool isProtected;
  final bool isActing;
  final bool isResetting;
  final VoidCallback onDeactivate;
  final VoidCallback onReactivate;
  final VoidCallback onPasswordReset;

  @override
  Widget build(BuildContext context) {
    final fullName = customer.fullName.trim().isEmpty
        ? 'Unnamed account'
        : customer.fullName;

    return Container(
      key: ValueKey('super-admin-panel-customer-${customer.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryText,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      customer.email,
                      style: const TextStyle(color: AppColors.secondaryText),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Role: ${_roleLabel(customer.role)}',
                      style: const TextStyle(color: AppColors.mutedText),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Created: ${_SuperAdminPanelScreenState._formatDate(customer.createdAt)}',
                      style: const TextStyle(color: AppColors.mutedText),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: customer.isActive
                      ? const Color(0xFFDCEBDD)
                      : AppColors.line,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  customer.isActive ? 'Active' : 'Disabled',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isProtected)
            const Text(
              'Protected account',
              style: TextStyle(
                color: AppColors.mutedText,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (customer.isActive)
                  OutlinedButton(
                    key: ValueKey(
                      'super-admin-panel-deactivate-${customer.id}',
                    ),
                    onPressed: isActing ? null : onDeactivate,
                    child: const Text('Deactivate'),
                  )
                else
                  OutlinedButton(
                    key: ValueKey(
                      'super-admin-panel-reactivate-${customer.id}',
                    ),
                    onPressed: isActing ? null : onReactivate,
                    child: const Text('Reactivate'),
                  ),
                FilledButton(
                  key: ValueKey(
                    'super-admin-panel-password-reset-${customer.id}',
                  ),
                  onPressed: isResetting || !customer.isActive
                      ? null
                      : onPasswordReset,
                  child: const Text('Send reset email'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  static String _roleLabel(String role) {
    switch (role) {
      case 'super_admin':
        return 'Super Admin';
      case 'admin':
        return 'Admin';
      default:
        return 'Community';
    }
  }
}

class _AdminAccessState extends StatelessWidget {
  const _AdminAccessState({
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
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primaryText,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(title),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.secondaryText,
                      ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: onPrimary,
                  child: Text(primaryLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
