import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';

const Color _screenBackground = Color(0xFFF4F4F1);
const Color _fieldFill = Color(0xFFDDE1DD);
const Color _fieldText = Color(0xFF50615B);
const Color _progressDark = Color(0xFF25352E);
const Color _progressLine = Color(0xFF2E3C35);
const Color _linkIconBackground = Color(0xFF4D5F56);
const Color _labelRequired = Color(0xFFC27265);

class BusinessRegistrationContactScaffold extends StatelessWidget {
  const BusinessRegistrationContactScaffold({
    super.key,
    required this.child,
    this.bottomInset = 0,
  });

  final Widget child;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: _screenBackground,
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: bottomInset),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class BusinessRegistrationHeader extends StatelessWidget {
  const BusinessRegistrationHeader({
    super.key,
    required this.onBackPressed,
  });

  final VoidCallback onBackPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBackPressed,
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
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class BusinessRegistrationProgressIndicator extends StatelessWidget {
  const BusinessRegistrationProgressIndicator({
    super.key,
    this.currentStepComplete = false,
  });

  final bool currentStepComplete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      child: Column(
        children: [
          SizedBox(
            height: 30,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 16,
                  right: 16,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: _progressLine,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const _ProgressStop(
                      state: _ProgressStopState.complete,
                    ),
                    _ProgressStop(
                      state: currentStepComplete
                          ? _ProgressStopState.complete
                          : _ProgressStopState.current,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Basic Details',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTypography.figtreeFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryText,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Contact & Location',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTypography.figtreeFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 1, color: Color(0xFF8D948D)),
        ],
      ),
    );
  }
}

enum _ProgressStopState { complete, current }

class _ProgressStop extends StatelessWidget {
  const _ProgressStop({
    required this.state,
  });

  final _ProgressStopState state;

  @override
  Widget build(BuildContext context) {
    final bool complete = state == _ProgressStopState.complete;

    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: complete ? _progressDark : _screenBackground,
        shape: BoxShape.circle,
        border: Border.all(
          color: _progressDark,
          width: complete ? 0 : 2,
        ),
      ),
      child: Center(
        child: Icon(
          complete ? Icons.check_rounded : Icons.circle,
          size: complete ? 16 : 12,
          color: complete ? Colors.white : _progressDark,
        ),
      ),
    );
  }
}

class BusinessRegistrationFieldLabel extends StatelessWidget {
  const BusinessRegistrationFieldLabel({
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
        style: const TextStyle(
          fontFamily: AppTypography.figtreeFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryText,
        ),
        children: [
          TextSpan(text: text),
          if (required)
            const TextSpan(
              text: '*',
              style: TextStyle(
                color: _labelRequired,
                fontWeight: FontWeight.w700,
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
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.maxLines = 1,
    this.minLines,
  });

  final TextEditingController controller;
  final String? hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final int maxLines;
  final int? minLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      minLines: minLines,
      maxLines: maxLines,
      scrollPadding: _keyboardAwareScrollPadding(context),
      cursorColor: _progressDark,
      style: const TextStyle(
        fontFamily: AppTypography.figtreeFamily,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppColors.primaryText,
      ),
      decoration: _inputDecoration(hintText: hintText),
    );
  }
}

class BusinessRegistrationTimeField extends StatelessWidget {
  const BusinessRegistrationTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _fieldFill,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: AppTypography.figtreeFamily,
                    fontSize: 15,
                    color: _fieldText,
                  ),
                ),
              ),
              if (value != null) const SizedBox(width: 8),
              if (value != null)
                Flexible(
                  child: Text(
                    value!,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontFamily: AppTypography.figtreeFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primaryText,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class BusinessRegistrationLinkField extends StatelessWidget {
  const BusinessRegistrationLinkField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.icon,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _fieldFill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _linkIconBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          Container(
            width: 1,
            height: 36,
            color: const Color(0xFF94A099),
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              scrollPadding: _keyboardAwareScrollPadding(context),
              cursorColor: _progressDark,
              style: const TextStyle(
                fontFamily: AppTypography.figtreeFamily,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.primaryText,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(
                  fontFamily: AppTypography.figtreeFamily,
                  fontSize: 15,
                  color: _fieldText,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BusinessRegistrationSubmitSection extends StatelessWidget {
  const BusinessRegistrationSubmitSection({
    super.key,
    required this.submitEnabled,
    required this.isSubmitting,
    required this.isSavingDraft,
    required this.onBackPressed,
    this.isKeyboardVisible = false,
    this.showSaveDraftAction = true,
    this.submitButtonLabel = 'Submit Listing',
    required this.onSubmitPressed,
    required this.onSaveDraftPressed,
  });

  final bool submitEnabled;
  final bool isSubmitting;
  final bool isSavingDraft;
  final VoidCallback onBackPressed;
  final bool isKeyboardVisible;
  final bool showSaveDraftAction;
  final String submitButtonLabel;
  final VoidCallback onSubmitPressed;
  final VoidCallback onSaveDraftPressed;

  @override
  Widget build(BuildContext context) {
    final bool busy = isSubmitting || isSavingDraft;
    final bool isCompact = isKeyboardVisible;
    final bool showHelperText = !isCompact;
    final bool showSaveDraft = showSaveDraftAction && !isCompact;
    final String helperText = isSubmitting
        ? 'Submitting your listing for review...'
        : isSavingDraft
            ? 'Saving your draft...'
            : submitEnabled
                ? ''
                : 'Please fill all input fields to proceed';

    return SafeArea(
      top: false,
      child: AnimatedContainer(
        key: const ValueKey('business-registration-contact-footer-container'),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding:
            EdgeInsets.fromLTRB(20, isCompact ? 4 : 8, 20, isCompact ? 8 : 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: showHelperText
                  ? SizedBox(
                      height: 28,
                      child: Center(
                        child: Text(
                          helperText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppTypography.figtreeFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: submitEnabled && !busy
                                ? Colors.transparent
                                : const Color(0xFF707671),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            SizedBox(height: showHelperText ? 12 : 0),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 58,
                    child: OutlinedButton(
                      onPressed: onBackPressed,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryText,
                        side: const BorderSide(
                          color: Color(0xFF94A099),
                          width: 1.4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        backgroundColor: Colors.white.withValues(alpha: 0.78),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Back',
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: AppTypography.figtreeFamily,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 58,
                    child: ElevatedButton(
                      onPressed:
                          submitEnabled && !busy ? onSubmitPressed : null,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: AppColors.accentSoft,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF979B98),
                        disabledForegroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.6,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                submitButtonLabel,
                                maxLines: 1,
                                style: const TextStyle(
                                  fontFamily: AppTypography.figtreeFamily,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: showSaveDraft
                  ? Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: TextButton(
                        onPressed: busy ? null : onSaveDraftPressed,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.accentSoft,
                          disabledForegroundColor: const Color(0xFF88928B),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 8,
                          ),
                        ),
                        child: Text(
                          isSavingDraft
                              ? 'Saving draft...'
                              : 'Save as draft & close',
                          style: const TextStyle(
                            fontFamily: AppTypography.figtreeFamily,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                            decorationThickness: 1.4,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration({String? hintText}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(
      fontFamily: AppTypography.figtreeFamily,
      fontSize: 15,
      color: _fieldText,
    ),
    filled: true,
    fillColor: _fieldFill,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.accentSoft, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.error, width: 1.2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    ),
    errorStyle: const TextStyle(
      fontFamily: AppTypography.figtreeFamily,
      fontSize: 11.5,
    ),
  );
}

EdgeInsets _keyboardAwareScrollPadding(BuildContext context) {
  final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
  return EdgeInsets.fromLTRB(24, 24, 24, keyboardInset + 128);
}
