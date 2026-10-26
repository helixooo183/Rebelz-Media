# Rebelz Media — Sohbet (Flutter + Firebase)

![APK derle](https://github.com/helixooo183/Rebelz-Media/actions/workflows/build-apk.yml/badge.svg?branch=main)

Koyu temalı bir sohbet uygulaması. Backend: **Firebase Authentication
(Google Sign-In + e-posta/şifre)** ve **Cloud Firestore**.

![Ekranlar](docs/screens.png)

> Sıra: splash · giriş · kayıt · sohbet listesi · boş durum · sohbet · kurulum rehberi

| | |
|---|---|
| **Firebase projesi** | `rebelz-media` |
| **Android paketi** | `com.rebelz.media` |
| **App ID** | `1:824723400047:android:4f0919a943290bf905749a` |
| **Debug SHA-1** | `CA:D5:F0:42:CD:90:19:D7:61:E9:90:66:40:8A:D6:21:1C:A9:4C:4A` |
| **Flutter** | 3.35+ · **JDK** 17 · **Android SDK** 36 |

## Hızlı başlangıç

```bash
flutter pub get
flutter run            # cihaz/emülatör
flutter analyze        # statik analiz
flutter test           # 6 test
```

APK üretmek için iki yol var — ikisi de ayrıntılı olarak
[docs/KURULUM.md](docs/KURULUM.md) içinde:

**1) GitHub Actions (kurulum gerekmez, önerilen)**

`.github/workflows/build-apk.yml` hazır. Depoda **Actions** → **APK derle** →
**Run workflow**. ~6 dakika sonra **Artifacts** → `sohbet-apk`:

- `app-release.apk` — telefona kuracağın sürüm
- `app-debug.apk` — emülatör/eski cihazlar

Workflow `flutter analyze` + `flutter test` de çalıştırır; kırmızı olursa
artifact üretilmez. SHA-1/SHA-256 parmak izi workflow özetine yazılır.

**2) Kendi makinenizde**

```bash
flutter build apk --release   # build/app/outputs/flutter-apk/app-release.apk
```

> Bu depo 2 GB RAM'li bir ortamda hazırlandı ve `flutter build apk` orada
> OOM (exit 137) ile düştü. Bu yüzden `android/gradle.properties` düşük bellek
> için ayarlı (`-Xmx640m`, daemon kapalı, Kotlin in-process), release'te R8
> küçültme kapalı ve imza debug keystore ile yapılıyor. Kendi makinenizde bu
> satırları silebilirsiniz; Play Store'a çıkmadan önce kendi release
> keystore'unuzu tanımlayın.

## Depo yapısı

```
.
├── lib/
│   ├── main.dart                     # Firebase init (iki yol: options ya da native config)
│   ├── firebase_options.dart         # tool/ script'i üretir
│   ├── core/
│   │   ├── config/google_sign_in_config.dart   # Web client ID
│   │   ├── router/                   # go_router + AuthNotifier
│   │   ├── services/auth_service.dart# Google + e-posta/şifre + profil upsert
│   │   ├── theme/                    # koyu tema
│   │   └── widgets/                  # AppLogo, GoogleLogo, GoogleSignInButton, ...
│   └── features/
│       ├── auth/presentation/        # splash, login, register
│       ├── chat/{data,domain,presentation}
│       ├── profile/
│       └── setup/                    # anahtarlar eksikse rehber ekranı
├── android/                          # com.rebelz.media (google-services.json dahil)
├── ios/  web/
├── test/                             # 6 widget/model testi
├── test_preview/                     # golden önizleme testi (docs/screens.png kaynağı)
├── tool/firebase_from_services_json.py   # google-services.json → Dart yapılandırması
├── firestore.rules
├── docs/                             # ekran görüntüleri, kurulum rehberi, imza izleri
└── .github/workflows/build-apk.yml   # APK derleme + test workflow'u
```

## Firebase tarafı

- Android uygulaması `com.rebelz.media` olarak kayıtlı, debug SHA-1 eklendi
- Google ve Email/Password giriş yöntemleri etkin
- `google-services.json` → `android/app/google-services.json` (repoda)
- `lib/firebase_options.dart` gerçek değerlerle dolu
- Web client ID → `lib/core/config/google_sign_in_config.dart`

Firestore kurallarını yayınlayın:

```bash
npx -y firebase-tools@latest deploy --only firestore:rules --project rebelz-media
```

`google-services.json` değiştiğinde (yeni SHA-1, yeni istemci) yapılandırmayı
yenileyin:

```bash
python3 tool/firebase_from_services_json.py --check   # Web client ID geldi mi?
python3 tool/firebase_from_services_json.py           # firebase_options + Web client ID yaz
```

### ⚠️ Kendi makinende ilk çalıştırmada: SHA-1

Kayıtlı SHA-1, paket hazırlanırken üretilen debug keystore'a ait. **Senin
bilgisayarındaki Flutter kendi debug keystore'unu oluşturur ve parmak izi
farklıdır.** Google girişi `ApiException: 10` verirse kendi SHA-1'ini
Firebase'e ek fingerprint olarak ekle (mevcut silinmesin, ikisi birlikte
durabilir):

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey \
  -storepass android | grep SHA1
```

Windows: `%USERPROFILE%\.android\debug.keystore`. Keystore yoksa bir kez
`flutter run` çalıştırınca oluşur.

> **Not:** Paketle gelen `debug.keystore` **repoya eklenmedi** (özel anahtar
> dosyasıdır, public repoya girmez). Yalnızca parmak izleri
> [docs/imza-parmak-izleri.txt](docs/imza-parmak-izleri.txt) içinde.

## Google Sign-In akışı (kod)

`lib/core/services/auth_service.dart`:

- **Android/iOS:** `GoogleSignIn.instance.initialize(serverClientId: ...)` →
  `authenticate()` → `idToken` → `GoogleAuthProvider.credential(idToken:)` →
  `signInWithCredential`.
- **Web:** `GoogleSignIn` hiç başlatılmaz; `signInWithPopup(GoogleAuthProvider())`
  kullanılır (aksi halde DWDS sonsuz bekler). Web'de `signOut()` de çağrılmaz.
- Kullanıcı vazgeçerse (`GoogleSignInExceptionCode.canceled`) hata gösterilmez,
  akış sessizce biter.
- Başarılı girişte `users/{uid}` dokümanı `displayName` / `email` / `photoUrl` /
  `lastSeenAt` ile upsert edilir.

**`main.dart` iki yolu destekler:**

1. `lib/firebase_options.dart` dolduysa → `Firebase.initializeApp(options: ...)`
2. Boşsa ama `google-services.json` varsa → `Firebase.initializeApp()`
   (native yapılandırma okunur — Android'de çalışır, web'de çalışmaz)

İkisi de yoksa uygulama çökmez, kurulum rehberi ekranını gösterir.

## Firestore veri modeli

```
users/{uid}
  displayName, email, photoUrl, createdAt, lastSeenAt

rooms/{roomId}
  name, createdBy, memberIds[], lastMessage, lastMessageAt, createdAt
  └─ messages/{messageId}
       senderId, senderName, text, createdAt
```

Kurallar `hasOnly` ile alan beyaz listesi uygular: `users` güncellemesinde
yalnızca `displayName`, `photoUrl`, `lastSeenAt` değişebilir; mesajlar
oluşturulduktan sonra değiştirilemez/silinemez.

## Test ve önizleme

```bash
flutter analyze    # 0 issue
flutter test       # 6 test (Google butonu, avatar, empty state, model)
flutter test test_preview/preview_test.dart --update-goldens   # docs/screens.png kaynağı
```

| Kontrol | Sonuç |
|---|---|
| `flutter analyze` | ✅ 0 sorun |
| `flutter test` | ✅ 6/6 test |
| `flutter build web --release` | ✅ başarılı |
| `flutter build apk` | ❌ bu ortamda OOM (2 GB RAM) — Actions/kendi makineniz |

## Sorun giderme

| Belirti | Sebep / çözüm |
|---|---|
| `ApiException: 10` (DEVELOPER_ERROR) | SHA-1 Firebase'e eklenmemiş ya da yanlış paket adı |
| `idToken` null | `google-services.json` içinde `client_type: 3` yok → Google sağlayıcısını etkinleştir, dosyayı yeniden indir |
| `auth/unauthorized-domain` (web) | Authentication → Settings → Authorized domains'e alan adını ekle (port yazma) |
| `operation-not-allowed` | İlgili sağlayıcı konsolda etkin değil |
| Kurulum ekranı geliyor | `google-services.json` yok/yanlış konumda ya da `firebase_options.dart` boş |

## Sırada

- [ ] Release keystore SHA-1'ini Firebase'e ekleme + Play imzalama
- [ ] iOS uygulamasını kaydetme (`GoogleService-Info.plist`, `REVERSED_CLIENT_ID`)
- [ ] `users` koleksiyonundan fotoğraf gösterimi (`photoUrl` zaten yazılıyor)
- [ ] Mesaj sayfalama (şu an son 100 mesaj), okundu bilgisi, FCM bildirimleri
- [ ] Sohbet odalarını `memberIds` ile sınırlama (şu an oturum açan tüm odaları görür)

---

Ayrıntılı kurulum/derleme adımları: [docs/KURULUM.md](docs/KURULUM.md)
