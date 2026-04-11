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
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _screenBackground,
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: child,
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
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBackPressed,
                splashRadius: 22,
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  size: 32,
                  color: AppColors.primaryText,
                ),
              ),
              const Expanded(
                child: Text(
                  'Register Your Business',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTypography.figtreeFamily,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 18),
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
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 0),
      child: Column(
        children: [
          SizedBox(
            height: 38,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 24,
                  right: 24,
                  child: Container(
                    height: 6,
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
          const SizedBox(height: 8),
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Basic Details',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTypography.figtreeFamily,
                    fontSize: 18,
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
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
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
      width: 38,
      height: 38,
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
          size: complete ? 22 : 18,
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
          fontSize: 18,
          fontWeight: FontWeight.w500,
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
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: _fieldFill,
            borderRadius: BorderRadius.circular(18),
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
              if (value != null)
                Text(
                  value!,
                  style: const TextStyle(
                    fontFamily: AppTypography.figtreeFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryText,
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
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _linkIconBackground,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          Container(
            width: 1,
            height: 46,
            color: const Color(0xFF94A099),
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
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
                contentPadding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
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
    this.showSaveDraftAction = true,
    this.submitButtonLabel = 'Submit Listing',
    required this.onSubmitPressed,
    required this.onSaveDraftPressed,
  });

  final bool submitEnabled;
  final bool isSubmitting;
  final bool isSavingDraft;
  final bool showSaveDraftAction;
  final String submitButtonLabel;
  final VoidCallback onSubmitPressed;
  final VoidCallback onSaveDraftPressed;

  @override
  Widget build(BuildContext context) {
    final bool busy = isSubmitting || isSavingDraft;
    final String helperText = isSubmitting
        ? 'Submitting your listing for review...'
        : isSavingDraft
            ? 'Saving your draft...'
            : submitEnabled
                ? ''
                : 'Please fill all input fields to proceed';

    return Column(
      children: [
        SizedBox(
          height: 28,
          child: Center(
            child: Text(
              helperText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTypography.figtreeFamily,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: submitEnabled && !busy
                    ? Colors.transparent
                    : const Color(0xFF707671),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 68,
          child: ElevatedButton(
            onPressed: submitEnabled && !busy ? onSubmitPressed : null,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: AppColors.accentSoft,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF979B98),
              disabledForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            child: isSubmitting
                ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    submitButtonLabel,
                    style: TextStyle(
                      fontFamily: AppTypography.figtreeFamily,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        if (showSaveDraftAction) ...[
          const SizedBox(height: 18),
          TextButton(
            onPressed: busy ? null : onSaveDraftPressed,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentSoft,
              disabledForegroundColor: const Color(0xFF88928B),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            ),
            child: Text(
              isSavingDraft ? 'Saving draft...' : 'Save as draft & close',
              style: const TextStyle(
                fontFamily: AppTypography.figtreeFamily,
                fontSize: 19,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationThickness: 1.4,
              ),
            ),
          ),
        ],
      ],
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
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppColors.accentSoft, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppColors.error, width: 1.2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    ),
    errorStyle: const TextStyle(
      fontFamily: AppTypography.figtreeFamily,
      fontSize: 11.5,
    ),
  );
}
