import 'package:flutter/material.dart';

import '../models/mosque_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../widgets/common/async_states.dart';
import '../widgets/common/screen_header.dart';

class NearbyEventsScreen extends StatelessWidget {
  const NearbyEventsScreen({
    super.key,
    required this.mosques,
  });

  final List<MosqueModel> mosques;

  @override
  Widget build(BuildContext context) {
    final publishedMosques = mosques
        .where((mosque) => mosque.events.isNotEmpty || mosque.classes.isNotEmpty)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            children: [
              const ScreenHeader(title: 'Nearby Events'),
              Expanded(
                child: publishedMosques.isEmpty
                    ? const EmptyState(
                        title: 'No published events nearby.',
                        subtitle:
                            'Nearby mosques have not published public event or class details for this location yet.',
                      )
                    : ListView.separated(
                        itemCount: publishedMosques.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final mosque = publishedMosques[index];
                          final location = [
                            mosque.addressLine,
                            mosque.city,
                            mosque.state,
                          ].where((part) => part.trim().isNotEmpty).join(', ');
                          final publishedEvents = mosque.events.length;
                          final publishedClasses = mosque.classes.length;
                          final firstSchedule = [
                            ...mosque.events.map((item) => item.schedule.trim()),
                            ...mosque.classes.map((item) => item.schedule.trim()),
                          ].firstWhere(
                            (value) => value.isNotEmpty,
                            orElse: () => '',
                          );
                          final publishedSummary = [
                            '$publishedEvents event${publishedEvents == 1 ? '' : 's'}',
                            if (publishedClasses > 0)
                              '$publishedClasses class${publishedClasses == 1 ? '' : 'es'}',
                          ].join(' • ');

                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.inputFill,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mosque.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(color: AppColors.primaryText),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  location.isEmpty
                                      ? 'Location unavailable'
                                      : location,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        color: AppColors.secondaryText,
                                      ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  'Published items: $publishedSummary',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(color: AppColors.primaryText),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  firstSchedule.isEmpty
                                      ? 'Schedule not published'
                                      : firstSchedule,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: AppColors.secondaryText,
                                      ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
