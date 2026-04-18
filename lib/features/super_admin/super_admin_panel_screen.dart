import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_provider.dart';
import '../../navigation/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/common/async_states.dart';
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
  final GlobalKey _customerSectionKey = GlobalKey();

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

  Future<void> _scrollToCustomers() async {
    final currentContext = _customerSectionKey.currentContext;
    if (currentContext == null) {
      return;
    }

    await Scrollable.ensureVisible(
      currentContext,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
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

    final customerSummaryLabel = _isCustomerLoading && _customerPage.total == 0
        ? 'Loading...'
        : _customerPage.total == 0
            ? 'No accounts'
            : '${_customerPage.total}';
    final customerSummarySubtitle = _searchController.text.trim().isEmpty
        ? 'Customer directory'
        : 'Search results';
    final summaryCards = <Widget>[
      _SummaryStatCard(
        key: const ValueKey('super-admin-summary-mosques'),
        title: 'Pending mosques',
        value: _isOverviewLoading && _pendingMosques.isEmpty
            ? 'Loading...'
            : _overviewError != null
                ? 'Unavailable'
                : '${_pendingMosques.length}',
        subtitle: _overviewError != null
            ? 'Queue status could not be loaded.'
            : _pendingMosques.isEmpty
                ? 'No mosque submissions need review.'
                : _queuePreviewLabel(
                    primaryLabel: _pendingMosques.first.name,
                    remainingCount: _pendingMosques.length - 1,
                  ),
        actionLabel: 'Review',
        onAction: () => Navigator.of(context).pushNamed(
          AppRoutes.mosqueModeration,
        ),
      ),
      _SummaryStatCard(
        key: const ValueKey('super-admin-summary-businesses'),
        title: 'Pending business listings',
        value: _isOverviewLoading && _pendingBusinesses.isEmpty
            ? 'Loading...'
            : _overviewError != null
                ? 'Unavailable'
                : '${_pendingBusinesses.length}',
        subtitle: _overviewError != null
            ? 'Queue status could not be loaded.'
            : _pendingBusinesses.isEmpty
                ? 'No business listings need review.'
                : _queuePreviewLabel(
                    primaryLabel: _pendingBusinesses.first.businessName,
                    remainingCount: _pendingBusinesses.length - 1,
                  ),
        actionLabel: 'Open Queue',
        onAction: () => Navigator.of(context).pushNamed(
          AppRoutes.businessModeration,
        ),
      ),
      _SummaryStatCard(
        key: const ValueKey('super-admin-summary-customers'),
        title: 'Customers',
        value: customerSummaryLabel,
        subtitle: customerSummarySubtitle,
        actionLabel: 'Manage Users',
        onAction: _scrollToCustomers,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3EF),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 980;
            final moderationCards = <Widget>[
              _PanelCard(
                child: _ModerationSection(
                  title: 'Mosque Queue',
                  subtitle:
                      'Review recent mosque submissions or jump into the full queue.',
                  count: _pendingMosques.length,
                  isLoading: _isOverviewLoading,
                  errorMessage: _overviewError,
                  emptyMessage: 'No mosque submissions are waiting for review.',
                  actionLabel: 'Open Mosque Moderation',
                  onAction: () => Navigator.of(context).pushNamed(
                    AppRoutes.mosqueModeration,
                  ),
                  onRetry: _loadOverview,
                  overflowLabel: _pendingMosques.length > 3
                      ? '${_pendingMosques.length - 3} more mosque submissions waiting'
                      : null,
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
                ),
              ),
              const SizedBox(height: 16),
              _PanelCard(
                child: _ModerationSection(
                  title: 'Business Queue',
                  subtitle:
                      'Keep business approvals in the same operational flow as mosque moderation.',
                  count: _pendingBusinesses.length,
                  isLoading: _isOverviewLoading,
                  errorMessage: _overviewError,
                  emptyMessage: 'No business listings are waiting for review.',
                  actionLabel: 'Open Business Moderation',
                  onAction: () => Navigator.of(context).pushNamed(
                    AppRoutes.businessModeration,
                  ),
                  onRetry: _loadOverview,
                  overflowLabel: _pendingBusinesses.length > 3
                      ? '${_pendingBusinesses.length - 3} more business listings waiting'
                      : null,
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
                      _DashboardHeader(
                        onBack: () => Navigator.of(context).maybePop(),
                        onRefresh: _loadAll,
                      ),
                      const SizedBox(height: 18),
                      _ResponsiveCardGrid(children: summaryCards),
                      const SizedBox(height: 18),
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _SectionHeading(
                                    title: 'Moderation Queues',
                                    subtitle:
                                        'Live previews stay lightweight here so the dedicated moderation screens remain the source of truth.',
                                  ),
                                  const SizedBox(height: 12),
                                  ...moderationCards,
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 6,
                              child: _PanelCard(
                                child: _CustomersSection(
                                  key: _customerSectionKey,
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
                                  onRetry: () => _loadCustomers(
                                    page: _customerPage.page == 0
                                        ? 1
                                        : _customerPage.page,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        const _SectionHeading(
                          title: 'Moderation Queues',
                          subtitle:
                              'Preview the current workload here, then open the full moderation screens when you need more detail.',
                        ),
                        const SizedBox(height: 12),
                        ...moderationCards,
                        const SizedBox(height: 16),
                        _PanelCard(
                          child: _CustomersSection(
                            key: _customerSectionKey,
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
                            onRetry: () => _loadCustomers(
                              page: _customerPage.page == 0
                                  ? 1
                                  : _customerPage.page,
                            ),
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

  static String _queuePreviewLabel({
    required String primaryLabel,
    required int remainingCount,
  }) {
    if (primaryLabel.trim().isEmpty) {
      return remainingCount > 0 ? '$remainingCount more waiting' : 'Ready';
    }

    if (remainingCount <= 0) {
      return primaryLabel;
    }

    return '$primaryLabel +$remainingCount more';
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.onBack,
    required this.onRefresh,
  });

  final VoidCallback onBack;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 560;
          final refreshButton = isCompact
              ? SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      onRefresh();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Refresh Workspace'),
                  ),
                )
              : OutlinedButton.icon(
                  onPressed: () {
                    onRefresh();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh Workspace'),
                );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 6),
                    const Expanded(child: _HeaderCopy()),
                  ],
                ),
                const SizedBox(height: 12),
                refreshButton,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 6),
              const Expanded(child: _HeaderCopy()),
              const SizedBox(width: 12),
              refreshButton,
            ],
          );
        },
      ),
    );
  }
}

class _HeaderCopy extends StatelessWidget {
  const _HeaderCopy();

  @override
  Widget build(BuildContext context) {
    return Column(
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
          'A unified super-admin workspace for moderation queues and customer account operations.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.secondaryText,
              ),
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

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
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
    );
  }
}

class _ResponsiveCardGrid extends StatelessWidget {
  const _ResponsiveCardGrid({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final columnCount = maxWidth >= 900
            ? 3
            : maxWidth >= 620
                ? 2
                : 1;
        const spacing = 12.0;
        final itemWidth =
            (maxWidth - (spacing * (columnCount - 1))) / columnCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map((child) => SizedBox(width: itemWidth, child: child))
              .toList(growable: false),
        );
      },
    );
  }
}

class _SummaryStatCard extends StatelessWidget {
  const _SummaryStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String value;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
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
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryText,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.secondaryText,
                ),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: onAction,
            child: Text(actionLabel),
          ),
        ],
      ),
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
    required this.onRetry,
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
  final VoidCallback onRetry;
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
            const SizedBox(width: 12),
            _InfoPill(label: '$count pending'),
          ],
        ),
        const SizedBox(height: 16),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: LoadingState(label: 'Loading queue...'),
          )
        else if (errorMessage != null)
          ErrorState(
            message: errorMessage!,
            onRetry: onRetry,
          )
        else if (children.isEmpty)
          EmptyState(
            title: emptyMessage,
            subtitle: 'The queue is clear for now.',
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
    super.key,
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
    required this.onRetry,
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
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 520;
        final searchField = TextField(
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
        );
        final searchButton = isCompact
            ? SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onSearch,
                  child: const Text('Search'),
                ),
              )
            : FilledButton(
                onPressed: onSearch,
                child: const Text('Search'),
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Customer Management',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Search accounts, confirm status at a glance, and apply safe customer actions without leaving the workspace.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.secondaryText,
                  ),
            ),
            const SizedBox(height: 16),
            if (isCompact) ...[
              searchField,
              const SizedBox(height: 10),
              searchButton,
            ] else
              Row(
                children: [
                  Expanded(child: searchField),
                  const SizedBox(width: 10),
                  searchButton,
                ],
              ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _InfoPill(
                  label: page.total == 0
                      ? 'No accounts'
                      : '${page.total} total accounts',
                ),
                _InfoPill(
                  label: page.items.isEmpty
                      ? 'No visible results'
                      : 'Showing ${page.items.length} results',
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: LoadingState(label: 'Loading customers...'),
              )
            else if (errorMessage != null)
              ErrorState(
                message: errorMessage!,
                onRetry: onRetry,
              )
            else if (page.items.isEmpty)
              const EmptyState(
                title: 'No customer accounts found',
                subtitle:
                    'Try a different name or email to continue managing customer records.',
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
              _CustomerPagination(
                page: page.page,
                totalPages: page.totalPages,
                onPreviousPage: onPreviousPage,
                onNextPage: onNextPage,
              ),
            ],
          ],
        );
      },
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
    final statusLabel = customer.isActive ? 'Active' : 'Disabled';
    final statusColor =
        customer.isActive ? const Color(0xFFDCEBDD) : const Color(0xFFF0E2DF);

    return Container(
      key: ValueKey('super-admin-panel-customer-${customer.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: customer.isActive ? AppColors.line : const Color(0xFFE2C9C3),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 520;
          final metadata = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(label: statusLabel, backgroundColor: statusColor),
              _InfoPill(label: _roleLabel(customer.role)),
              _InfoPill(
                label:
                    'Created ${_SuperAdminPanelScreenState._formatDate(customer.createdAt)}',
              ),
            ],
          );
          final actionButtons = <Widget>[
            if (customer.isActive)
              _CustomerActionButton(
                child: OutlinedButton(
                  key: ValueKey(
                    'super-admin-panel-deactivate-${customer.id}',
                  ),
                  onPressed: isActing ? null : onDeactivate,
                  child: Text(isActing ? 'Updating...' : 'Deactivate'),
                ),
              )
            else
              _CustomerActionButton(
                child: OutlinedButton(
                  key: ValueKey(
                    'super-admin-panel-reactivate-${customer.id}',
                  ),
                  onPressed: isActing ? null : onReactivate,
                  child: Text(isActing ? 'Updating...' : 'Reactivate'),
                ),
              ),
            _CustomerActionButton(
              child: FilledButton(
                key: ValueKey(
                  'super-admin-panel-password-reset-${customer.id}',
                ),
                onPressed:
                    isResetting || !customer.isActive ? null : onPasswordReset,
                child: Text(isResetting ? 'Sending...' : 'Send reset email'),
              ),
            ),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isCompact) ...[
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
                const SizedBox(height: 10),
                metadata,
              ] else ...[
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
                const SizedBox(height: 10),
                metadata,
              ],
              const SizedBox(height: 12),
              if (isProtected)
                const Text(
                  'Protected account',
                  style: TextStyle(
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else if (isCompact)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < actionButtons.length; i++) ...[
                      actionButtons[i],
                      if (i != actionButtons.length - 1)
                        const SizedBox(height: 8),
                    ],
                  ],
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: actionButtons,
                ),
            ],
          );
        },
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

class _CustomerPagination extends StatelessWidget {
  const _CustomerPagination({
    required this.page,
    required this.totalPages,
    required this.onPreviousPage,
    required this.onNextPage,
  });

  final int page;
  final int totalPages;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 420;
        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Page $page of $totalPages',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.secondaryText),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onPreviousPage,
                      child: const Text('Previous'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onNextPage,
                      child: const Text('Next'),
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            OutlinedButton(
              onPressed: onPreviousPage,
              child: const Text('Previous'),
            ),
            Expanded(
              child: Text(
                'Page $page of $totalPages',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.secondaryText),
              ),
            ),
            OutlinedButton(
              onPressed: onNextPage,
              child: const Text('Next'),
            ),
          ],
        );
      },
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.label,
    this.backgroundColor,
  });

  final String label;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.primaryText,
        ),
      ),
    );
  }
}

class _CustomerActionButton extends StatelessWidget {
  const _CustomerActionButton({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: child,
    );
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
