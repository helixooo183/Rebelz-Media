import '../../features/chat/data/chat_repository.dart';
import '../../features/moderation/data/moderation_repository.dart';
import '../../features/profile/data/user_repository.dart';
import 'auth_service.dart';

/// Basit servis kaydı (service locator).
/// Tek bağımlılık enjeksiyonu noktası: ileride Riverpod/Provider/get_it
/// kullanmak isterseniz sadece bu dosyayı değiştirmeniz yeterli.
final AuthService authServiceInstance = AuthService();

final ChatRepository chatRepositoryInstance = ChatRepository();

final UserRepository userRepositoryInstance = UserRepository();

final ModerationRepository moderationRepositoryInstance =
    ModerationRepository();

// ---------------------------------------------------------------------------
// Test/önizleme (Firebase başlatılmamış) ortamlarda patlamayan erişimciler.
// ---------------------------------------------------------------------------

/// Oturum açan kullanıcının kimliği; Firebase yoksa `null`.
String? get currentUserIdOrNull {
  try {
    return authServiceInstance.currentUser?.uid;
  } catch (_) {
    return null;
  }
}

/// Oturum açan kullanıcının görünen adı; Firebase yoksa `null`.
String? get currentUserNameOrNull {
  try {
    return authServiceInstance.displayName;
  } catch (_) {
    return null;
  }
}

/// Auth servisi; Firebase başlatılmamışsa `null`.
AuthService? get authServiceOrNull {
  try {
    return authServiceInstance;
  } catch (_) {
    return null;
  }
}
