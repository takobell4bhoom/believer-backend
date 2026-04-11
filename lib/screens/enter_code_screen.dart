import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/otp_input_row.dart';

class EnterCodeScreen extends StatefulWidget {
  const EnterCodeScreen({super.key});

  @override
  State<EnterCodeScreen> createState() => _EnterCodeScreenState();
}

class _EnterCodeScreenState extends State<EnterCodeScreen> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  bool _wrongCode = false;

  bool get _isFilled => _controllers.every((c) => c.text.isNotEmpty);

  String get _value => _controllers.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(6, (_) => TextEditingController());
    _focusNodes = List.generate(6, (_) => FocusNode()..addListener(_refresh));
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onCodeChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    setState(() => _wrongCode = false);
  }

  void _verify() {
    setState(() => _wrongCode = _value != '657224');
    if (!_wrongCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code verified')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Enter Code',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Please enter the confirmation code sent to\nyour email address to complete signing up',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.primaryText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 42),
          OtpInputRow(
            controllers: _controllers,
            focusNodes: _focusNodes,
            hasError: _wrongCode,
            onChanged: _onCodeChanged,
          ),
          if (_wrongCode) ...[
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Wrong code, please try again',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.center,
              children: [
                const Text(
                  'Didn’t receive a code? ',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                    color: AppColors.primaryText,
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Resend',
                    style: TextStyle(
                      decoration: TextDecoration.underline,
                      color: AppColors.accentSoft,
                      decorationColor: AppColors.accentSoft,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          AuthPrimaryButton(
            text: 'Verify',
            enabled: _isFilled,
            onPressed: _verify,
          ),
        ],
      ),
    );
  }
}
