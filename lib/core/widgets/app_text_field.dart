import 'package:flutter/material.dart';

/// Tema ile uyumlu, kısa yoldan kullanılan metin alanı.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.labelText,
    this.prefixIcon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.maxLines = 1,
    this.autofillHints,
    this.onSubmitted,
    this.validator,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String hintText;
  final String? labelText;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final int maxLines;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final bool enabled;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscured = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.labelText != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              widget.labelText!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
        TextFormField(
          controller: widget.controller,
          enabled: widget.enabled,
          obscureText: _obscured,
          maxLines: widget.maxLines,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          onFieldSubmitted: widget.onSubmitted,
          validator: widget.validator,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon:
                widget.prefixIcon == null ? null : Icon(widget.prefixIcon, size: 20),
            suffixIcon: widget.obscureText
                ? IconButton(
                    onPressed: () => setState(() => _obscured = !_obscured),
                    icon: Icon(
                      _obscured
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
