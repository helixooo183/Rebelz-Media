import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_logo.dart';

/// Firebase anahtarları eklenmemişse gösterilen kurulum rehberi.
class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  static const _steps = <(String, String)>[
    (
      '1. google-services.json',
      'Dosya android/app/google-services.json konumunda olmalı.\n'
          'Sonra: python3 tool/firebase_from_services_json.py'
    ),
    (
      '2. SHA-1 parmak izi',
      'Console → Project settings → Android app → SHA-1 ekle:\n'
          'CA:D5:F0:42:CD:90:19:D7:61:E9:90:66:40:8A:D6:21:1C:A9:4C:4A'
    ),
    (
      '3. Google sağlayıcısı',
      'Authentication → Sign-in method → Google + Email/Password etkinleştir.\n'
          'Sonra google-services.json dosyasını YENİDEN indir.'
    ),
    (
      '4. Yeniden başlat',
      'flutter run — giriş ekranı ve Google butonu görünür.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.6),
            radius: 1.1,
            colors: [
              AppColors.brand.withValues(alpha: 0.16),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
            children: [
              const Center(child: RebelzLogo(height: 44)),
              const SizedBox(height: 26),
              Text(
                'Firebase yapılandırılmadı',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text(
                'Kod tarafı hazır: Google Sign-In, e-posta/şifre ve Firestore '
                'akışları bağlı. Eksik olan tek şey proje anahtarları.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              for (final (title, description) in _steps) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.55,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
              Text(
                'Detaylar: README.md → "Firebase kurulumu"',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
