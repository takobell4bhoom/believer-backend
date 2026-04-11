import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_provider.dart';
import '../../navigation/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import 'business_moderation_service.dart';

class BusinessModerationScreen extends ConsumerStatefulWidget {
  const BusinessModerationScreen({
    super.key,
    this.service = const BusinessModerationService(),
  });

  final BusinessModerationService service;

  @override
  ConsumerState<BusinessModerationScreen> createState() =>
      _BusinessModerationScreenState();
}

class _BusinessModerationScreenState
    extends ConsumerState<BusinessModerationScreen> {
  bool _requestedInitialLoad = false;
  bool _isLoading = false;
  bool _isActing = false;
  String? _errorMessage;
  List<BusinessModerationListing> _items = const <BusinessModerationListing>[];
  String? _selectedListingId;

  Future<void> _loadPendingListings() async {
    final token = ref.read(authProvider).valueOrNull?.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await widget.service.fetchPendingListings(
        bearerToken: token,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
        _selectedListingId = items.any((item) => item.id == _selectedListingId)
            ? _selectedListingId
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

  BusinessModerationListing? get _selectedListing {
    final selectedId = _selectedListingId;
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

  Future<void> _approveSelectedListing() async {
    final token = ref.read(authProvider).valueOrNull?.accessToken;
    final listing = _selectedListing;
    if (token == null || token.isEmpty || listing == null) {
      return;
    }

    setState(() {
      _isActing = true;
    });

    try {
      await widget.service.approveListing(
        listingId: listing.id,
        bearerToken: token,
      );
      _removeListingFromQueue(listing.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listing approved.')),
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

  Future<void> _rejectSelectedListing() async {
    final token = ref.read(authProvider).valueOrNull?.accessToken;
    final listing = _selectedListing;
    if (token == null || token.isEmpty || listing == null) {
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
      await widget.service.rejectListing(
        listingId: listing.id,
        rejectionReason: rejectionReason,
        bearerToken: token,
      );
      _removeListingFromQueue(listing.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listing rejected.')),
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

  void _removeListingFromQueue(String listingId) {
    final nextItems =
        _items.where((item) => item.id != listingId).toList(growable: false);
    final nextSelectedListingId = nextItems.isEmpty
        ? null
        : nextItems.any((item) => item.id == _selectedListingId)
            ? _selectedListingId
            : nextItems.first.id;

    setState(() {
      _items = nextItems;
      _selectedListingId = nextSelectedListingId;
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
        title: 'Business Moderation',
        message:
            'Log in with a super admin account to review business listings.',
        primaryLabel: 'Go to Login',
        onPrimary: () => Navigator.of(context).pushReplacementNamed(
          AppRoutes.login,
        ),
      );
    }

    if (user.role != 'super_admin') {
      return _AccessScaffold(
        title: 'Business Moderation',
        message:
            'Only super admins can access the business listing review queue.',
        primaryLabel: 'Back to Settings',
        onPrimary: () => Navigator.of(context).pushReplacementNamed(
          AppRoutes.profileSettings,
        ),
      );
    }

    if (!_requestedInitialLoad) {
      _requestedInitialLoad = true;
      Future<void>.microtask(_loadPendingListings);
    }

    final selectedListing = _selectedListing;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F3EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F3EE),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.primaryText,
        title: const Text(
          'Business Moderation',
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
                            onPressed: _loadPendingListings,
                            child: const Text('Try Again'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _items.isEmpty
                    ? const Center(
                        child: Text(
                          'No business listings are waiting for review.',
                          key: ValueKey('business-moderation-empty'),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final queue = _ModerationQueue(
                            items: _items,
                            selectedListingId: _selectedListingId,
                            onSelect: (listing) {
                              setState(() {
                                _selectedListingId = listing.id;
                              });
                            },
                          );
                          final details = _ModerationDetails(
                            listing: selectedListing,
                            isActing: _isActing,
                            onApprove: _approveSelectedListing,
                            onReject: _rejectSelectedListing,
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
    required this.selectedListingId,
    required this.onSelect,
  });

  final List<BusinessModerationListing> items;
  final String? selectedListingId;
  final ValueChanged<BusinessModerationListing> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = item.id == selectedListingId;
        return Material(
          color: isSelected ? const Color(0xFFE4ECE7) : AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            key: ValueKey('business-moderation-item-${item.id}'),
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () => onSelect(item),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.businessName,
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
    required this.listing,
    required this.isActing,
    required this.onApprove,
    required this.onReject,
  });

  final BusinessModerationListing? listing;
  final bool isActing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    if (listing == null) {
      return const Center(
        child: Text('Select a listing to review.'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            listing!.businessName,
            style: const TextStyle(
              fontFamily: AppTypography.figtreeFamily,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            listing!.tagline,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 20),
          _DetailBlock(
              label: 'Submitted by', value: listing!.submitter.fullName),
          _DetailBlock(label: 'Email', value: listing!.submitter.email),
          _DetailBlock(label: 'Business email', value: listing!.businessEmail),
          _DetailBlock(label: 'Phone', value: listing!.phone),
          _DetailBlock(label: 'City', value: listing!.city),
          _DetailBlock(
            label: 'Submitted at',
            value: listing!.submittedAt?.toLocal().toString() ?? 'Unknown',
          ),
          _DetailBlock(label: 'Description', value: listing!.description),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  key: const ValueKey('business-moderation-approve'),
                  onPressed: isActing ? null : onApprove,
                  child: const Text('Approve'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('business-moderation-reject'),
                  onPressed: isActing ? null : onReject,
                  child: const Text('Reject'),
                ),
              ),
            ],
          ),
        ],
      ),
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
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: AppTypography.figtreeFamily,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
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

class _RejectionReasonDialog extends StatefulWidget {
  const _RejectionReasonDialog();

  @override
  State<_RejectionReasonDialog> createState() => _RejectionReasonDialogState();
}

class _RejectionReasonDialogState extends State<_RejectionReasonDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject Listing'),
      content: TextField(
        key: const ValueKey('business-moderation-rejection-reason'),
        controller: _controller,
        autofocus: true,
        minLines: 3,
        maxLines: 5,
        decoration: const InputDecoration(
          hintText: 'Explain what needs to change before approval.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final value = _controller.text.trim();
            if (value.length < 3) {
              return;
            }
            Navigator.of(context).pop(value);
          },
          child: const Text('Reject'),
        ),
      ],
    );
  }
}
