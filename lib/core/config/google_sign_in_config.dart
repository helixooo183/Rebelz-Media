/// Google Sign-In yapılandırması.
///
/// `serverClientId`, Google Cloud Console'da otomatik oluşan **Web client**
/// kimliğidir ve Android'de `idToken` alabilmek için zorunludur:
///   Console → Authentication → Google → Web SDK configuration
/// ya da `google-services.json` içindeki `oauth_client` dizisinde
/// `"client_type": 3` olan kayıt.
///
/// `tool/firebase_from_services_json.py` bu değeri otomatik doldurur; elle de
/// verilebilir:
///   flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=123-abc.apps.googleusercontent.com
abstract final class GoogleSignInConfig {
  static const String serverClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: _fallbackServerClientId,
  );

  /// `tool/firebase_from_services_json.py` bu satırı günceller.
  static const String _fallbackServerClientId = '824723400047-4dls5k2urdc2lvo43ir443d3iasuj6u0.apps.googleusercontent.com';

  static bool get isConfigured => serverClientId.isNotEmpty;
}
