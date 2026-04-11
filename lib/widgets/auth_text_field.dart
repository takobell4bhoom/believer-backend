import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.controller,
    this.obscureText = false,
    this.hasError = false,
    this.keyboardType,
    this.onChanged,
    this.showVisibilityToggle = false,
  });

  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final bool hasError;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final bool showVisibilityToggle;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late final FocusNode _focusNode;
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(() => setState(() {}));
    _obscure = widget.obscureText;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFocused = _focusNode.hasFocus;
    final borderColor = widget.hasError
        ? AppColors.error
        : (isFocused ? AppColors.primaryText : Colors.transparent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            color: AppColors.primaryText,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 44,
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            keyboardType: widget.keyboardType,
            obscureText: _obscure,
            onChanged: widget.onChanged,
            cursorColor: AppColors.secondaryText,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              filled: true,
              fillColor: AppColors.inputFill,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.figma12),
                borderSide: BorderSide(color: borderColor, width: 1.25),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.figma12),
                borderSide: BorderSide(color: borderColor, width: 1.25),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.figma12),
                borderSide:
                    const BorderSide(color: AppColors.error, width: 1.25),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.figma12),
                borderSide:
                    const BorderSide(color: AppColors.error, width: 1.25),
              ),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 44,
                minHeight: 44,
              ),
              suffixIcon: widget.showVisibilityToggle
                  ? IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.primaryText,
                        size: 22,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
