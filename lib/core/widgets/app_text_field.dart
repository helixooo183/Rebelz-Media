import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Tema ile uyumlu metin alanı.
///
/// Giriş/kayıt ekranlarında koyu varyant kullanılır:
/// `AppTextField.dark(...)` → zemin #111113, çerçeve #2A2A2E, odakta kırmızı,
/// ikonlar marka kırmızısı.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.labelText,
    this.prefixIcon,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.maxLines = 1,
    this.maxLength,
    this.autofillHints,
    this.onSubmitted,
    this.onChanged,
    this.validator,
    this.enabled = true,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.fillColor,
    this.borderColor,
    this.iconColor,
  });

  /// Koyu (auth) görünüm: koyu zemin, ince çerçeve, kırmızı ikonlar.
  const AppTextField.dark({
    super.key,
    required this.controller,
    required this.hintText,
    this.labelText,
    this.prefixIcon,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.maxLines = 1,
    this.maxLength,
    this.autofillHints,
    this.onSubmitted,
    this.onChanged,
    this.validator,
    this.enabled = true,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
  })  : fillColor = const Color(0xFF111113),
        borderColor = const Color(0xFF2A2A2E),
        iconColor = AppColors.brand;

  final TextEditingController controller;
  final String hintText;
  final String? labelText;
  final IconData? prefixIcon;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final int maxLines;
  final int? maxLength;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final bool autofocus;
  final TextCapitalization textCapitalization;

  /// Alan zemini (null → tema `surfaceContainerHighest`).
  final Color? fillColor;

  /// Çerçeve rengi (null → tema `outlineVariant`).
  final Color? borderColor;

  /// Baştaki ikon rengi (null → tema ikincil metin rengi).
  final Color? iconColor;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscured = widget.obscureText;
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fill = widget.fillColor ?? context.cardHigh;
    final line = widget.borderColor ?? context.line;
    final iconColor = widget.iconColor ?? context.muted;
    final radius = BorderRadius.circular(16);

    OutlineInputBorder outline(Color color, double width) => OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: color, width: width),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.labelText != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Text(
              widget.labelText!,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
                color: context.muted,
              ),
            ),
          ),
        ],
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          obscureText: _obscured,
          maxLines: widget.maxLines,
          maxLength: widget.maxLength,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          textCapitalization: widget.textCapitalization,
          autofillHints: widget.autofillHints,
          onFieldSubmitted: widget.onSubmitted,
          onChanged: widget.onChanged,
          validator: widget.validator,
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w500,
            height: 1.2,
            color: context.colors.onSurface,
          ),
          decoration: InputDecoration(
            hintText: widget.hintText,
            counterText: '',
            filled: true,
            fillColor: fill,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 18,
              horizontal: 16,
            ),
            hintStyle: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: context.muted,
            ),
            errorStyle: TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: context.colors.error,
            ),
            border: outline(line, 1),
            enabledBorder: outline(line, 1),
            focusedBorder: outline(AppColors.brand, 1.4),
            errorBorder: outline(context.colors.error, 1),
            focusedErrorBorder: outline(context.colors.error, 1.4),
            disabledBorder: outline(line, 1),
            prefixIcon: widget.prefixIcon == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 16, right: 10),
                    child: Icon(widget.prefixIcon, size: 20, color: iconColor),
                  ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 46,
              minHeight: 24,
            ),
            suffixIcon: widget.suffix ??
                (widget.obscureText
                    ? IconButton(
                        tooltip: _obscured ? 'Şifreyi göster' : 'Şifreyi gizle',
                        onPressed: () => setState(() => _obscured = !_obscured),
                        icon: Icon(
                          _obscured
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                          color: context.muted,
                        ),
                      )
                    : null),
          ),
        ),
      ],
    );
  }
}
