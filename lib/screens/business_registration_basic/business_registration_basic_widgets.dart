import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import 'business_registration_basic_models.dart';

class BusinessRegistrationBasicHeader extends StatelessWidget {
  const BusinessRegistrationBasicHeader({
    super.key,
    required this.onBack,
  });

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final dividerColor = AppColors.secondaryText.withValues(alpha: 0.48);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints.tightFor(width: 36, height: 36),
                splashRadius: 20,
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  size: 28,
                  color: AppColors.primaryText,
                ),
              ),
              const Expanded(
                child: Text(
                  'Register Your Business',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTypography.figtreeFamily,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                  ),
                ),
              ),
              const SizedBox(width: 36),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 0),
          child: BusinessRegistrationStepProgress(
            currentStep: 1,
            totalSteps: 2,
            currentLabel: 'Basic Details',
            nextLabel: 'Contact & Location',
          ),
        ),
        const SizedBox(height: 12),
        Divider(height: 1, thickness: 1, color: dividerColor),
      ],
    );
  }
}

class BusinessRegistrationStepProgress extends StatelessWidget {
  const BusinessRegistrationStepProgress({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.currentLabel,
    required this.nextLabel,
  });

  final int currentStep;
  final int totalSteps;
  final String currentLabel;
  final String nextLabel;

  @override
  Widget build(BuildContext context) {
    final isFirstActive = currentStep <= 1;
    final lineColor = AppColors.secondaryText.withValues(alpha: 0.82);
    final inactiveCircleColor = AppColors.background.withValues(alpha: 0.95);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 28,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 16,
                right: 16,
                child: Container(height: 3, color: lineColor),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ProgressStop(
                    active: isFirstActive,
                    lineColor: lineColor,
                    inactiveCircleColor: inactiveCircleColor,
                  ),
                  _ProgressStop(
                    active: currentStep >= totalSteps,
                    lineColor: lineColor,
                    inactiveCircleColor: inactiveCircleColor,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                currentLabel,
                style: const TextStyle(
                  fontFamily: AppTypography.figtreeFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText,
                ),
              ),
            ),
            Expanded(
              child: Text(
                nextLabel,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: AppTypography.figtreeFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.secondaryText.withValues(alpha: 0.88),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProgressStop extends StatelessWidget {
  const _ProgressStop({
    required this.active,
    required this.lineColor,
    required this.inactiveCircleColor,
  });

  final bool active;
  final Color lineColor;
  final Color inactiveCircleColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? inactiveCircleColor : AppColors.background,
        border: Border.all(color: lineColor, width: 1.5),
      ),
      child: active
          ? Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondaryText,
                ),
              ),
            )
          : null,
    );
  }
}

class BusinessRegistrationSectionLabel extends StatelessWidget {
  const BusinessRegistrationSectionLabel({
    super.key,
    required this.text,
    this.required = false,
  });

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontFamily: AppTypography.figtreeFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryText,
        ),
        children: [
          if (required)
            const TextSpan(
              text: '*',
              style: TextStyle(
                color: Color(0xFFB24634),
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}

class BusinessRegistrationTextField extends StatelessWidget {
  const BusinessRegistrationTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.minLines = 1,
    this.maxLines = 1,
    this.textInputAction,
    this.onTap,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final String? hintText;
  final int minLines;
  final int? maxLines;
  final TextInputAction? textInputAction;
  final VoidCallback? onTap;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final fillColor =
        Color.lerp(AppColors.surface, AppColors.lineStrong, 0.42)!;

    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      scrollPadding: _keyboardAwareScrollPadding(context),
      textInputAction: textInputAction,
      readOnly: readOnly,
      onTap: onTap,
      style: const TextStyle(
        fontFamily: AppTypography.figtreeFamily,
        fontSize: 15,
        height: 1.25,
        fontWeight: FontWeight.w400,
        color: AppColors.primaryText,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          fontFamily: AppTypography.figtreeFamily,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: AppColors.mutedText.withValues(alpha: 0.8),
        ),
        filled: true,
        fillColor: fillColor,
        contentPadding: EdgeInsets.fromLTRB(
          18,
          minLines == 1 ? 16 : 14,
          18,
          minLines == 1 ? 16 : 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: AppColors.secondaryText.withValues(alpha: 0.34),
            width: 1.2,
          ),
        ),
      ),
      cursorColor: AppColors.secondaryText,
    );
  }
}

class BusinessRegistrationLogoUploadCard extends StatelessWidget {
  const BusinessRegistrationLogoUploadCard({
    super.key,
    required this.logo,
    required this.onTap,
    required this.onRemove,
    this.isLoading = false,
  });

  final BusinessRegistrationLogoAsset? logo;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final fillColor =
        Color.lerp(AppColors.surface, AppColors.lineStrong, 0.42)!;

    return Material(
      color: fillColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: logo == null
                ? _EmptyLogoUploadState(isLoading: isLoading)
                : Stack(
                    children: [
                      Center(child: _LogoPreviewTile(logo: logo!)),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          onPressed: isLoading ? null : onRemove,
                          splashRadius: 18,
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 24,
                            color: AppColors.primaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _EmptyLogoUploadState extends StatelessWidget {
  const _EmptyLogoUploadState({
    required this.isLoading,
  });

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final mutedColor = AppColors.secondaryText.withValues(alpha: 0.56);

    return SizedBox(
      height: 152,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading)
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: mutedColor,
              ),
            )
          else
            Icon(
              Icons.file_upload_outlined,
              size: 34,
              color: mutedColor,
            ),
          const SizedBox(height: 12),
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              style: TextStyle(
                fontFamily: AppTypography.figtreeFamily,
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: AppColors.primaryText,
              ),
              children: [
                TextSpan(
                  text: 'Click here',
                  style: TextStyle(
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentSoft,
                  ),
                ),
                TextSpan(text: ' to upload JPEG (Max size: 2MB)'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoPreviewTile extends StatelessWidget {
  const _LogoPreviewTile({
    required this.logo,
  });

  final BusinessRegistrationLogoAsset logo;

  @override
  Widget build(BuildContext context) {
    final preview = logo.previewImage;

    return Container(
      width: 164,
      height: 164,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: logo.tileBackgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: preview == null
          ? Center(
              child: Text(
                logo.fileName ?? 'Logo',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppTypography.figtreeFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText,
                ),
              ),
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image(
                image: preview,
                fit: BoxFit.contain,
              ),
            ),
    );
  }
}

class BusinessRegistrationTaxonomySelector extends StatelessWidget {
  const BusinessRegistrationTaxonomySelector({
    super.key,
    required this.groups,
    required this.isExpanded,
    required this.expandedGroupId,
    required this.selectedType,
    required this.onToggleExpanded,
    required this.onToggleGroup,
    required this.onSelectItem,
  });

  final List<BusinessRegistrationTaxonomyGroup> groups;
  final bool isExpanded;
  final String? expandedGroupId;
  final BusinessRegistrationSelectedType? selectedType;
  final VoidCallback onToggleExpanded;
  final ValueChanged<String> onToggleGroup;
  final void Function(
    BusinessRegistrationTaxonomyGroup group,
    BusinessRegistrationTaxonomyItem item,
  ) onSelectItem;

  @override
  Widget build(BuildContext context) {
    final fillColor =
        Color.lerp(AppColors.surface, AppColors.lineStrong, 0.42)!;
    final dividerColor = AppColors.secondaryText.withValues(alpha: 0.28);
    final placeholderStyle = TextStyle(
      fontFamily: AppTypography.figtreeFamily,
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: AppColors.mutedText.withValues(alpha: 0.88),
    );
    const selectedStyle = TextStyle(
      fontFamily: AppTypography.figtreeFamily,
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: AppColors.primaryText,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Material(
        color: fillColor,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: onToggleExpanded,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedType?.displayLabel ??
                              'Select from the options below',
                          style: selectedType == null
                              ? placeholderStyle
                              : selectedStyle,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 24,
                        color: AppColors.primaryText,
                      ),
                    ],
                  ),
                ),
              ),
              if (isExpanded)
                for (final group in groups) ...[
                  Divider(height: 1, thickness: 1, color: dividerColor),
                  _TaxonomyGroupRow(
                    group: group,
                    isExpanded: expandedGroupId == group.id,
                    onTap: () => onToggleGroup(group.id),
                    selectedType: selectedType,
                    onSelectItem: (item) => onSelectItem(group, item),
                  ),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TaxonomyGroupRow extends StatelessWidget {
  const _TaxonomyGroupRow({
    required this.group,
    required this.isExpanded,
    required this.onTap,
    required this.selectedType,
    required this.onSelectItem,
  });

  final BusinessRegistrationTaxonomyGroup group;
  final bool isExpanded;
  final VoidCallback onTap;
  final BusinessRegistrationSelectedType? selectedType;
  final ValueChanged<BusinessRegistrationTaxonomyItem> onSelectItem;

  @override
  Widget build(BuildContext context) {
    final dividerColor = AppColors.secondaryText.withValues(alpha: 0.26);

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    group.label,
                    style: const TextStyle(
                      fontFamily: AppTypography.figtreeFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primaryText,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  isExpanded
                      ? Icons.arrow_drop_up_rounded
                      : Icons.arrow_drop_down_rounded,
                  size: 28,
                  color: AppColors.primaryText,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 16, 14),
            child: Column(
              children: [
                for (int index = 0; index < group.items.length; index++) ...[
                  _TaxonomyChildRow(
                    item: group.items[index],
                    selected: selectedType?.itemId == group.items[index].id,
                    onTap: () => onSelectItem(group.items[index]),
                  ),
                  if (index != group.items.length - 1)
                    Divider(height: 1, thickness: 0, color: dividerColor),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _TaxonomyChildRow extends StatelessWidget {
  const _TaxonomyChildRow({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final BusinessRegistrationTaxonomyItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 8),
            const SizedBox(
              width: 18,
              height: 18,
              child: CustomPaint(painter: _BranchPainter()),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  fontFamily: AppTypography.figtreeFamily,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: AppColors.primaryText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BranchPainter extends CustomPainter {
  const _BranchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = AppColors.primaryText;

    final path = Path()
      ..moveTo(size.width * 0.25, 0)
      ..lineTo(size.width * 0.25, size.height * 0.68)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.92,
        size.width * 0.52,
        size.height * 0.92,
      )
      ..lineTo(size.width * 0.9, size.height * 0.92);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BusinessRegistrationFooter extends StatelessWidget {
  const BusinessRegistrationFooter({
    super.key,
    required this.canContinue,
    required this.showSaveDraft,
    this.isKeyboardVisible = false,
    this.nextButtonLabel = 'Next',
    required this.onNext,
    required this.onSaveDraftAndClose,
  });

  final bool canContinue;
  final bool showSaveDraft;
  final bool isKeyboardVisible;
  final String nextButtonLabel;
  final VoidCallback onNext;
  final VoidCallback onSaveDraftAndClose;

  @override
  Widget build(BuildContext context) {
    final buttonColor = canContinue ? AppColors.accentSoft : AppColors.disabled;
    final bool isCompact = isKeyboardVisible;
    final bool showHelperText = !isCompact;
    final bool showSaveDraftAction = showSaveDraft && !isCompact;

    return SafeArea(
      top: false,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: AnimatedContainer(
          key: const ValueKey('business-registration-basic-footer-container'),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.fromLTRB(
              20, isCompact ? 4 : 8, 20, isCompact ? 8 : 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: showHelperText
                    ? Text(
                        'Please fill all the input fields to proceed',
                        key: const ValueKey('business-registration-helper'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppTypography.figtreeFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color:
                              AppColors.secondaryText.withValues(alpha: 0.78),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              SizedBox(height: showHelperText ? 12 : 0),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: canContinue ? onNext : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    disabledBackgroundColor: AppColors.disabled,
                    foregroundColor: AppColors.background,
                    disabledForegroundColor: AppColors.background,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: AppTypography.figtreeFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(nextButtonLabel),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: showSaveDraftAction
                    ? Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: TextButton(
                          onPressed: onSaveDraftAndClose,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.accentSoft,
                            textStyle: const TextStyle(
                              fontFamily: AppTypography.figtreeFamily,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          child: const Text('Save as draft & close'),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

EdgeInsets _keyboardAwareScrollPadding(BuildContext context) {
  final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
  return EdgeInsets.fromLTRB(24, 24, 24, keyboardInset + 140);
}
