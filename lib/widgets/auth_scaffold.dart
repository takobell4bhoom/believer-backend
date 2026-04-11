import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.footer,
    this.onBack,
    this.onWillPop,
    this.eyebrow,
    this.subtitle,
  });

  final String title;
  final Widget body;
  final Widget footer;
  final VoidCallback? onBack;
  final Future<bool> Function()? onWillPop;
  final String? eyebrow;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: onWillPop == null,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || onWillPop == null) {
          return;
        }
        await onWillPop!.call();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bodyMinHeight = math.max(
                0.0,
                constraints.maxHeight - 38 - 58 - 40 - 36,
              );

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(38, 38, 38, 58),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 390),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _AuthHeader(
                          title: title,
                          onBack: onBack,
                          eyebrow: eyebrow,
                          subtitle: subtitle,
                        ),
                        const SizedBox(height: 36),
                        ConstrainedBox(
                          constraints: BoxConstraints(minHeight: bodyMinHeight),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              body,
                              const SizedBox(height: 28),
                              footer,
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AuthHeader extends StatelessWidget {
  const _AuthHeader({
    required this.title,
    this.onBack,
    this.eyebrow,
    this.subtitle,
  });

  final String title;
  final VoidCallback? onBack;
  final String? eyebrow;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                padding: EdgeInsets.zero,
                splashRadius: 18,
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  size: 28,
                  color: AppColors.primaryText,
                ),
                tooltip: 'Back',
              ),
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText,
                ),
              ),
            ),
            const SizedBox(width: 32),
          ],
        ),
        if (eyebrow != null || subtitle != null) ...[
          const SizedBox(height: 12),
          if (eyebrow != null)
            Text(
              eyebrow!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.accentSoft,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          if (subtitle != null) ...[
            SizedBox(height: eyebrow != null ? 8 : 0),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w400,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ],
      ],
    );
  }
}
