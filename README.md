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
| **Kayıtlı SHA-1 (debug)** | `CA:D5:F0:42:CD:90:19:D7:61:E9:90:66:40:8A:D6:21:1C:A9:4C:4A` |
| **Kayıtlı SHA-1 (release/upload)** | `92:A0:55:FE:C3:85:15:49:CC:45:8D:60:F1:E9:C4:B1:F4:D7:CC:3D` |
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

> Bu depo 2 GB RAM'li bir ortamda hazırlandı; `flutter build apk` orada OOM
> (exit 137) ile düştüğü için `android/gradle.properties` içinde daemon kapalı
> ve Kotlin derleyicisi in-process. Varsayılan heap CI için `-Xmx2048m`;
> ≤2 GB RAM'li bir makinede derlerken dosyanın başındaki `-Xmx640m` +
> `org.gradle.workers.max=1` kombinasyonuna geçin. Release'te R8 küçültme kapalı
> ve imza debug keystore ile yapılıyor — Play Store'a çıkmadan önce kendi
> release keystore'unuzu tanımlayın.

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

- Android uygulaması `com.rebelz.media` olarak kayıtlı; **iki** SHA-1 eklendi:
  debug (`CA:D5:F0:42:…:4C:4A`) ve release/upload (`92:A0:55:FE:…:CC:3D`)
- `google-services.json` bu iki Android OAuth istemcisini + Web istemcisini içeriyor
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

### 🔐 Güvenlik notu (depo public)

`google-services.json` ve `lib/firebase_options.dart` içindeki değerler
**istemci yapılandırmasıdır** (Firebase API anahtarı sır değildir; güvenlik
Firestore kuralları ve Authentication ile sağlanır) — bu yüzden repoya dahil.
Yine de public bir repoda önerilenler:

- Google Cloud Console → **APIs & Services → Credentials** → Android/iOS
  anahtarlarını uygulama kısıtlamasıyla (paket adı + SHA-1) sınırlayın,
  tarayıcı anahtarını yalnızca izinli domainlerle.
- `firestore.rules` dosyasını mutlaka yayınlayın (test modu kuralları açık bırakmayın).
- **Özel anahtarlar repoda yok:** `*.jks`, `*.keystore` ve `android/key.properties`
  `.gitignore` içinde.


Firebase'de **iki** parmak izi kayıtlı: debug (`CA:D5:F0:42:…`) ve
release/upload (`92:A0:55:FE:…`). **Senin bilgisayarındaki Flutter kendi debug
keystore'unu oluşturur ve parmak izi farklıdır**; GitHub Actions her koşuda yeni
bir keystore üretir. Google girişi `ApiException: 10` verirse o ortamın SHA-1'ini
Firebase'e ek fingerprint olarak ekle (mevcutlar silinmesin, yan yana durabilir):

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey \
  -storepass android | grep SHA1
```

Windows: `%USERPROFILE%\.android\debug.keystore`. Keystore yoksa bir kez
`flutter run` çalıştırınca oluşur.

> **Not:** Anahtar dosyaları (`*.jks`, `*.keystore`, `*.p12`) **repoya
> eklenmez** — public repoda özel anahtar tutulmaz. Release anahtarı yerelde
> `anahtarlar/upload-keystore.p12` (git dışı) durur; parolası ve kullanım
> adımları `anahtarlar/OKUBENI.txt`. Tüm parmak izleri ve doğrulama komutları:
> [docs/imza-parmak-izleri.txt](docs/imza-parmak-izleri.txt).

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

- [x] Release keystore SHA-1'ini Firebase'e ekleme (`92:A0:55:FE:…:CC:3D`)
- [ ] Release imzalamayı `build.gradle.kts`'e bağlama (şu an debug keystore ile imzalıyor) + Play imzalama
- [ ] iOS uygulamasını kaydetme (`GoogleService-Info.plist`, `REVERSED_CLIENT_ID`)
- [ ] `users` koleksiyonundan fotoğraf gösterimi (`photoUrl` zaten yazılıyor)
- [ ] Mesaj sayfalama (şu an son 100 mesaj), okundu bilgisi, FCM bildirimleri
- [ ] Sohbet odalarını `memberIds` ile sınırlama (şu an oturum açan tüm odaları görür)

---

Ayrıntılı kurulum/derleme adımları: [docs/KURULUM.md](docs/KURULUM.md)
