import '../../features/chat/data/chat_repository.dart';
import 'auth_service.dart';

/// Basit servis kaydı (service locator).
/// Tek bağımlılık enjeksiyonu noktası: ileride Riverpod/Provider/get_it
/// kullanmak isterseniz sadece bu dosyayı değiştirmeniz yeterli.
final AuthService authServiceInstance = AuthService();

final ChatRepository chatRepositoryInstance = ChatRepository(
  authService: authServiceInstance,
);
