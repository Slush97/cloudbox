import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

class AuthState {
  const AuthState({this.token, this.serverUrl, this.isLoading = true});
  final String? token;
  final String? serverUrl;
  final bool isLoading;

  bool get isAuthenticated => token != null;
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState(isLoading: true)) {
    _loadSaved();
  }

  static const _storage = FlutterSecureStorage();

  Future<void> _loadSaved() async {
    final token = await _storage.read(key: 'token');
    final serverUrl = await _storage.read(key: 'server_url');
    state = AuthState(token: token, serverUrl: serverUrl, isLoading: false);
  }

  Future<void> login({
    required String serverUrl,
    required String token,
  }) async {
    await _storage.write(key: 'token', value: token);
    await _storage.write(key: 'server_url', value: serverUrl);
    state = AuthState(token: token, serverUrl: serverUrl, isLoading: false);
  }

  Future<void> logout() async {
    await _storage.delete(key: 'token');
    await _storage.delete(key: 'server_url');
    state = const AuthState(isLoading: false);
  }
}
