import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/legal_texts.dart';

/// Koşul metnini okumak için açılan tam ekran sayfa.
Future<void> showTermsSheet(BuildContext context) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => const TermsScreen(),
    ),
  );
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(LegalTexts.title),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 44),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: context.colors.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Sürüm ${LegalTexts.version}',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: context.colors.primary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            LegalTexts.intro,
            style: TextStyle(fontSize: 14, height: 1.55, color: context.muted),
          ),
          for (final section in LegalTexts.sections) ...[
            const SizedBox(height: 22),
            Text(
              section.$1,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              section.$2,
              style: TextStyle(fontSize: 14, height: 1.55, color: context.muted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Kayıt ekranındaki onay kutusu.
class TermsCheckbox extends StatelessWidget {
  const TermsCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 12, 4),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value ? context.colors.primary : context.line,
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: enabled ? (v) => onChanged(v ?? false) : null,
          ),
          Expanded(
            child: GestureDetector(
              onTap: enabled ? () => onChanged(!value) : null,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LegalTexts.checkboxLabel,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: enabled ? context.colors.onSurface : context.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    InkWell(
                      onTap: () => showTermsSheet(context),
                      child: Text(
                        'Metni oku ›',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: context.colors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
