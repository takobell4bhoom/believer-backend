import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_provider.dart';
import '../../navigation/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import 'mosque_moderation_service.dart';

class MosqueModerationScreen extends ConsumerStatefulWidget {
  const MosqueModerationScreen({
    super.key,
    this.service = const MosqueModerationService(),
  });

  final MosqueModerationService service;

  @override
  ConsumerState<MosqueModerationScreen> createState() =>
      _MosqueModerationScreenState();
}

class _MosqueModerationScreenState
    extends ConsumerState<MosqueModerationScreen> {
  bool _requestedInitialLoad = false;
  bool _isLoading = false;
  bool _isActing = false;
  String? _errorMessage;
  List<MosqueModerationItem> _items = const <MosqueModerationItem>[];
  String? _selectedMosqueId;

  Future<void> _loadPendingMosques() async {
    final token = ref.read(authProvider).valueOrNull?.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await widget.service.fetchPendingMosques(
        bearerToken: token,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _items = items;
        _selectedMosqueId = items.any((item) => item.id == _selectedMosqueId)
            ? _selectedMosqueId
            : items.isEmpty
                ? null
                : items.first.id;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  MosqueModerationItem? get _selectedMosque {
    final selectedId = _selectedMosqueId;
    if (selectedId == null) {
      return null;
    }

    for (final item in _items) {
      if (item.id == selectedId) {
        return item;
      }
    }

    return null;
  }

  Future<void> _approveSelectedMosque() async {
    final token = ref.read(authProvider).valueOrNull?.accessToken;
    final mosque = _selectedMosque;
    if (token == null || token.isEmpty || mosque == null) {
      return;
    }

    setState(() {
      _isActing = true;
    });

    try {
      await widget.service.approveMosque(
        mosqueId: mosque.id,
        bearerToken: token,
      );
      _removeMosqueFromQueue(mosque.id);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mosque approved and now live.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isActing = false;
        });
      }
    }
  }

  Future<void> _rejectSelectedMosque() async {
    final token = ref.read(authProvider).valueOrNull?.accessToken;
    final mosque = _selectedMosque;
    if (token == null || token.isEmpty || mosque == null) {
      return;
    }

    final rejectionReason = await showDialog<String>(
      context: context,
      builder: (context) => const _RejectionReasonDialog(),
    );

    if (!mounted || rejectionReason == null) {
      return;
    }

    setState(() {
      _isActing = true;
    });

    try {
      await widget.service.rejectMosque(
        mosqueId: mosque.id,
        rejectionReason: rejectionReason,
        bearerToken: token,
      );
      _removeMosqueFromQueue(mosque.id);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mosque rejected.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isActing = false;
        });
      }
    }
  }

  void _removeMosqueFromQueue(String mosqueId) {
    final nextItems =
        _items.where((item) => item.id != mosqueId).toList(growable: false);
    final nextSelectedMosqueId = nextItems.isEmpty
        ? null
        : nextItems.any((item) => item.id == _selectedMosqueId)
            ? _selectedMosqueId
            : nextItems.first.id;

    setState(() {
      _items = nextItems;
      _selectedMosqueId = nextSelectedMosqueId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.valueOrNull?.user;

    if (authState.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (user == null) {
      return _AccessScaffold(
        title: 'Mosque Moderation',
        message: 'Log in with a super admin account to review pending mosques.',
        primaryLabel: 'Go to Login',
        onPrimary: () => Navigator.of(context).pushReplacementNamed(
          AppRoutes.login,
        ),
      );
    }

    if (user.role != 'super_admin') {
      return _AccessScaffold(
        title: 'Mosque Moderation',
        message: 'Only super admins can access the mosque approval queue.',
        primaryLabel: 'Back to Settings',
        onPrimary: () => Navigator.of(context).pushReplacementNamed(
          AppRoutes.profileSettings,
        ),
      );
    }

    if (!_requestedInitialLoad) {
      _requestedInitialLoad = true;
      Future<void>.microtask(_loadPendingMosques);
    }

    final selectedMosque = _selectedMosque;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F3EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F3EE),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.primaryText,
        title: const Text(
          'Mosque Moderation',
          style: TextStyle(
            fontFamily: AppTypography.figtreeFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadPendingMosques,
                            child: const Text('Try Again'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _items.isEmpty
                    ? const Center(
                        child: Text(
                          'No pending mosques are waiting for approval.',
                          key: ValueKey('mosque-moderation-empty'),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final queue = _ModerationQueue(
                            items: _items,
                            selectedMosqueId: _selectedMosqueId,
                            onSelect: (mosque) {
                              setState(() {
                                _selectedMosqueId = mosque.id;
                              });
                            },
                          );
                          final details = _ModerationDetails(
                            mosque: selectedMosque,
                            isActing: _isActing,
                            onApprove: _approveSelectedMosque,
                            onReject: _rejectSelectedMosque,
                          );

                          if (constraints.maxWidth >= 900) {
                            return Row(
                              children: [
                                SizedBox(
                                  width: 320,
                                  child: queue,
                                ),
                                const VerticalDivider(width: 1),
                                Expanded(child: details),
                              ],
                            );
                          }

                          return Column(
                            children: [
                              SizedBox(
                                height: 260,
                                child: queue,
                              ),
                              const Divider(height: 1),
                              Expanded(child: details),
                            ],
                          );
                        },
                      ),
      ),
    );
  }
}

class _ModerationQueue extends StatelessWidget {
  const _ModerationQueue({
    required this.items,
    required this.selectedMosqueId,
    required this.onSelect,
  });

  final List<MosqueModerationItem> items;
  final String? selectedMosqueId;
  final ValueChanged<MosqueModerationItem> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = item.id == selectedMosqueId;
        return Material(
          color: isSelected ? const Color(0xFFE4ECE7) : AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            key: ValueKey('mosque-moderation-item-${item.id}'),
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () => onSelect(item),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontFamily: AppTypography.figtreeFamily,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.submitter.fullName,
                    style: const TextStyle(color: AppColors.secondaryText),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.city.isEmpty ? item.submitter.email : item.city,
                    style: const TextStyle(color: AppColors.mutedText),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ModerationDetails extends StatelessWidget {
  const _ModerationDetails({
    required this.mosque,
    required this.isActing,
    required this.onApprove,
    required this.onReject,
  });

  final MosqueModerationItem? mosque;
  final bool isActing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    if (mosque == null) {
      return const Center(
        child: Text('Select a mosque to review.'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mosque!.name,
            style: const TextStyle(
              fontFamily: AppTypography.figtreeFamily,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Status: Pending approval',
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 20),
          _DetailBlock(
              label: 'Submitted by', value: mosque!.submitter.fullName),
          _DetailBlock(
              label: 'Submitter email', value: mosque!.submitter.email),
          _DetailBlock(label: 'Address', value: mosque!.addressLine),
          _DetailBlock(label: 'City', value: mosque!.city),
          _DetailBlock(label: 'State', value: mosque!.state),
          _DetailBlock(label: 'Country', value: mosque!.country),
          _DetailBlock(label: 'Sect', value: mosque!.sect),
          _DetailBlock(label: 'Contact name', value: mosque!.contactName),
          _DetailBlock(label: 'Contact email', value: mosque!.contactEmail),
          _DetailBlock(label: 'Contact phone', value: mosque!.contactPhone),
          _DetailBlock(
            label: 'Submitted at',
            value: mosque!.submittedAt?.toLocal().toString() ?? 'Unknown',
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('mosque-moderation-reject'),
                  onPressed: isActing ? null : onReject,
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  key: const ValueKey('mosque-moderation-approve'),
                  onPressed: isActing ? null : onApprove,
                  child: const Text('Approve and Publish Live'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RejectionReasonDialog extends StatefulWidget {
  const _RejectionReasonDialog();

  @override
  State<_RejectionReasonDialog> createState() => _RejectionReasonDialogState();
}

class _RejectionReasonDialogState extends State<_RejectionReasonDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trimmedValue = _controller.text.trim();

    return AlertDialog(
      title: const Text('Reject Mosque'),
      content: TextField(
        key: const ValueKey('mosque-moderation-rejection-reason'),
        controller: _controller,
        maxLines: 4,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Add a short reason for the submitter',
        ),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: trimmedValue.length < 3
              ? null
              : () => Navigator.of(context).pop(trimmedValue),
          child: const Text('Reject'),
        ),
      ],
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: AppTypography.figtreeFamily,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(value.isEmpty ? 'Not provided' : value),
        ],
      ),
    );
  }
}

class _AccessScaffold extends StatelessWidget {
  const _AccessScaffold({
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
        elevation: 0,
        foregroundColor: AppColors.primaryText,
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
                ),
                const SizedBox(height: 16),
                ElevatedButton(
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
