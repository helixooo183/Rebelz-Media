# Kurulum ve Derleme — Rebelz Media · Sohbet

Firebase projesi: **rebelz-media** · Android paketi: **com.rebelz.media**
App ID: `1:824723400047:android:4f0919a943290bf905749a`

## Depo içeriği

```
.
├── lib/ android/ ios/ web/ test/ test_preview/   Flutter projesi (kök = proje kökü)
├── .github/workflows/build-apk.yml               APK derleme workflow'u
├── tool/firebase_from_services_json.py           google-services.json → Dart config
├── firestore.rules
└── docs/
    ├── 01_splash.png … 07_setup.png  7 ayrı ekran görüntüsü
    ├── screens.png                   kolaj (README'de kullanılır)
    ├── imza-parmak-izleri.txt        debug keystore SHA-1 / SHA-256
    └── KURULUM.md                    bu dosya
```

> **APK repoda yok.** Derleme, paketin hazırlandığı ortamda 2 GB RAM yüzünden
> tamamlanamadı (Gradle/OOM killer `java`'yı öldürdü, exit 137). Aşağıdaki iki
> yolla APK'yı 5-10 dakikada üretebilirsiniz.

## 1. APK üretmenin en hızlı yolu — GitHub Actions

`.github/workflows/build-apk.yml` hazır geliyor.

1. Depoda **Actions** sekmesi → **APK derle** → **Run workflow**
   (`main`/`master` dalına `lib/**`, `android/**` veya `pubspec.yaml`
   dokunuşunda da otomatik çalışır).
2. ~6 dakika sonra **Artifacts** → `sohbet-apk` → indir:
   - `app-release.apk` (telefona kuracağın sürüm)
   - `app-debug.apk` (emülatör/eski cihazlar)

Workflow `flutter analyze` + `flutter test` de çalıştırır; kırmızı olursa
artifact üretilmez. Son adımda CI'ın debug keystore parmak izi (SHA-1/SHA-256)
workflow özetine yazılır.

## 2. Kendi makinenizde derleme

Gereksinimler: Flutter 3.35+, **JDK 17**, Android SDK 36, en az 8 GB RAM.

```bash
flutter pub get
flutter build apk --release
# çıktı: build/app/outputs/flutter-apk/app-release.apk
```

Telefona kurmak için: dosyayı cihaza kopyala → dokun → "bilinmeyen
kaynaklara izin ver" → kur.

Not: `android/gradle.properties` düşük bellekli ortam için ayarlandı
(`-Xmx640m`, daemon kapalı, Kotlin in-process). Kendi makinenizde bu satırları
silip varsayılana dönebilirsiniz. `android/app/build.gradle.kts` içinde
release R8 küçültme kapalı (APK biraz büyür, işlev aynı) ve imza debug
keystore ile yapılıyor — Play Store'a çıkmadan önce kendi release
keystore'unuzu tanımlayın.

## 3. Google ile giriş / SHA-1

Firebase konsolunda kayıtlı parmak izi:

```
CA:D5:F0:42:CD:90:19:D7:61:E9:90:66:40:8A:D6:21:1C:A9:4C:4A
```

Kendi makinenizde ya da CI'da derlerseniz **farklı bir keystore** kullanılır ve
Google girişi `ApiException: 10` verir. Yapılacak:

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey \
  -storepass android | grep SHA1
```

Çıkan SHA-1'i Firebase Console → Project settings → Android uygulaması →
**Add fingerprint** ile ekleyin (mevcut silinmesin; birden fazla olabilir).
CI kullanıyorsanız SHA-1 workflow özetinde de yazdırılır.

> **`debug.keystore` bu depoda yok.** Özel anahtar dosyası olduğu için
> `.gitignore` ile hariç tutuldu; yalnızca parmak izleri
> `docs/imza-parmak-izleri.txt` içinde. Paketle gelen keystore'u kullanmak
> isterseniz kendi kopyanızdan `~/.android/debug.keystore` üzerine koyun.

## 4. Firebase tarafı

- Android uygulaması `com.rebelz.media` olarak kayıtlı, SHA-1 eklendi
- Google ve Email/Password giriş yöntemleri etkin
- `google-services.json` → `android/app/google-services.json`
- `lib/firebase_options.dart` gerçek değerlerle dolu
- Web client ID → `lib/core/config/google_sign_in_config.dart`

Firestore kurallarını yayınlayın:

```bash
npx -y firebase-tools@latest deploy --only firestore:rules --project rebelz-media
```

## 5. Doğrulama durumu

| Kontrol | Sonuç |
|---|---|
| `flutter analyze` | ✅ 0 sorun |
| `flutter test` | ✅ 6/6 test |
| `flutter build web --release` | ✅ başarılı |
| Zip'ten çıkarılıp yeniden `pub get` + `analyze` + `test` | ✅ geçti |
| `flutter build apk` | ❌ 2 GB RAM'de OOM (paket ortamı) |
| Kotlin Gradle plugin | ✅ 2.1.0 → 2.2.20 (Firebase plugin'leri için gerekliydi) |

## 6. Bilinen sınırlar

- Mesaj geçmişi son 100 mesajla sınırlı (sayfalama yok)
- Sohbet odalarını oturum açan herkes görür (grup demosu)
- Push bildirim, fotoğraf yükleme, okundu bilgisi henüz yok
- iOS tarafı yapılandırılmadı (yalnızca Android kayıtlı)
