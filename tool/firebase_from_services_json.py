#!/usr/bin/env python3
"""google-services.json -> Flutter yapılandırması.

Kullanım:
    python3 tool/firebase_from_services_json.py [--check]

Yaptıkları:
  1. android/app/google-services.json dosyasını doğrular (paket adı eşleşmesi).
  2. lib/firebase_options.dart dosyasını gerçek değerlerle yeniden yazar.
  3. Web client ID'yi (client_type 3) lib/core/config/google_sign_in_config.dart
     içine gömer — Android'de Google idToken almak için gerekli.
  4. Projeye kayıtlı SHA-1 parmak izlerini ve OAuth istemcilerini listeler.

--check: hiçbir dosyayı değiştirmez, sadece rapor verir.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SERVICES_JSON = ROOT / "android" / "app" / "google-services.json"
APP_GRADLE = ROOT / "android" / "app" / "build.gradle.kts"
FIREBASE_OPTIONS = ROOT / "lib" / "firebase_options.dart"
GOOGLE_CONFIG = ROOT / "lib" / "core" / "config" / "google_sign_in_config.dart"

CHECK_ONLY = "--check" in sys.argv


def fail(message: str) -> None:
    print(f"HATA: {message}")
    sys.exit(1)


def read_application_id() -> str | None:
    if not APP_GRADLE.exists():
        return None
    match = re.search(r'applicationId\s*=\s*"([^"]+)"', APP_GRADLE.read_text())
    return match.group(1) if match else None


def pick_android_client(data: dict, expected_package: str | None) -> dict:
    clients = data.get("client") or []
    if not clients:
        fail("google-services.json içinde 'client' dizisi yok.")

    if expected_package:
        for client in clients:
            info = client.get("client_info", {})
            if info.get("android_client_info", {}).get("package_name") == expected_package:
                return client
        packages = [
            c.get("client_info", {}).get("android_client_info", {}).get("package_name")
            for c in clients
        ]
        fail(
            "google-services.json içinde uygulama paketi bulunamadı.\n"
            f"  Beklenen: {expected_package}\n"
            f"  Dosyadaki paketler: {packages}\n"
            "  Firebase konsolunda Android uygulamasını bu paket adıyla "
            "kaydettiğinizden emin olun."
        )

    return clients[0]


def main() -> None:
    if not SERVICES_JSON.exists():
        fail(
            f"{SERVICES_JSON.relative_to(ROOT)} yok.\n"
            "  Firebase konsolu → Project settings → Your apps → Android app → "
            "google-services.json dosyasını indirip bu konuma koyun."
        )

    data = json.loads(SERVICES_JSON.read_text())
    project_info = data.get("project_info", {})
    project_id = project_info.get("project_id")
    if not project_id:
        fail("google-services.json içinde project_info.project_id yok.")

    expected_package = read_application_id()
    client = pick_android_client(data, expected_package)
    client_info = client.get("client_info", {})
    package_name = client_info.get("android_client_info", {}).get("package_name")
    app_id = client_info.get("mobilesdk_app_id")
    api_key = next(
        (k.get("current_key") for k in client.get("api_key", []) if k.get("current_key")),
        "",
    )

    oauth_clients = client.get("oauth_client", []) or []
    web_client = next(
        (c for c in oauth_clients if c.get("client_type") == 3),
        None,
    )
    android_clients = [c for c in oauth_clients if c.get("client_type") == 1]

    print("── Firebase yapılandırması ─────────────────────────────")
    print(f"  proje          : {project_id}")
    print(f"  paket          : {package_name}")
    print(f"  app id         : {app_id}")
    print(f"  api key        : {api_key[:8]}…{api_key[-4:] if api_key else ''}")
    print(f"  storage bucket : {project_info.get('storage_bucket', '—')}")
    print(f"  web client id  : {web_client['client_id'] if web_client else 'YOK'}")
    for c in android_clients:
        print(f"  android client : {c['client_id']}")
        cert = (c.get("android_info") or {}).get("certificate_hash")
        if cert:
            pretty = ":".join(cert[i:i + 2] for i in range(0, len(cert), 2)).upper()
            print(f"     SHA-1       : {pretty}")

    if expected_package and package_name != expected_package:
        fail(f"Paket adı uyuşmuyor: dosya={package_name}, gradle={expected_package}")

    if not web_client:
        print(
            "\nUYARI: Web client ID bulunamadı. Google ile girişte idToken almak "
            "için gerekli.\n  Çözüm: Console → Authentication → Google → "
            "etkinleştirip Web SDK yapılandırmasını açın, ardından\n"
            "  google-services.json dosyasını yeniden indirin."
        )

    if CHECK_ONLY:
        print("\n(--check: dosyalar değiştirilmedi)")
        return

    # ---- lib/firebase_options.dart -----------------------------------------
    bucket = project_info.get("storage_bucket", "")
    sender_id = project_info.get("project_number", "")
    FIREBASE_OPTIONS.write_text(
        f"""// Bu dosya tool/firebase_from_services_json.py tarafından üretildi.
// Kaynak: android/app/google-services.json — elle düzenlemeyin.
// `flutterfire configure` çalıştırırsanız bu dosyayı kendisi yeniden yazar.

import 'package:firebase_core/firebase_core.dart';

abstract final class DefaultFirebaseOptions {{
  static const String projectId = '{project_id}';
  static const String apiKey = '{api_key}';
  static const String appId = '{app_id}';
  static const String messagingSenderId = '{sender_id}';
  static const String storageBucket = '{bucket}';

  static bool get isConfigured =>
      apiKey.isNotEmpty && projectId.isNotEmpty && appId.isNotEmpty;

  static FirebaseOptions get currentPlatform => FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        storageBucket: storageBucket.isEmpty ? null : storageBucket,
      );
}}
"""
    )

    # ---- lib/core/config/google_sign_in_config.dart ------------------------
    if web_client and GOOGLE_CONFIG.exists():
        source = GOOGLE_CONFIG.read_text()
        source = re.sub(
            r"static const String _fallbackServerClientId = '[^']*';",
            f"static const String _fallbackServerClientId = '{web_client['client_id']}';",
            source,
        )
        GOOGLE_CONFIG.write_text(source)

    print("\n✓ lib/firebase_options.dart güncellendi")
    if web_client:
        print("✓ lib/core/config/google_sign_in_config.dart (Web client ID) güncellendi")
    print("\nŞimdi: flutter run")


if __name__ == "__main__":
    main()
