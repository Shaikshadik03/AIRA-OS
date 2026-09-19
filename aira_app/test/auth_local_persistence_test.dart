import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aira_app/features/auth/presentation/providers/auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Auth Local Offline Persistence Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initial state with empty preferences results in unauthenticated on checkAuthStatus', () async {
      final notifier = AuthNotifier();
      expect(notifier.state, equals(AuthStatus.unauthenticated));

      await notifier.checkAuthStatus();
      expect(notifier.state, equals(AuthStatus.unauthenticated));
    });

    test('signInGuest persists session to SharedPreferences and authenticates', () async {
      final notifier = AuthNotifier();

      await notifier.signInGuest();
      expect(notifier.state, equals(AuthStatus.authenticated));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('aira_auth_logged_in'), isTrue);
      expect(prefs.getString('aira_auth_user_email'), equals('guest@aira.local'));
      expect(prefs.getString('aira_auth_user_name'), equals('AIRA Explorer'));
    });

    test('checkAuthStatus restores authenticated session from SharedPreferences on cold start', () async {
      SharedPreferences.setMockInitialValues({
        'aira_auth_logged_in': true,
        'aira_auth_user_email': 'test@aira.local',
        'aira_auth_user_name': 'Test User',
      });

      final notifier = AuthNotifier();
      await notifier.checkAuthStatus();

      expect(notifier.state, equals(AuthStatus.authenticated));
    });

    test('signOut removes all persisted auth keys and updates state', () async {
      SharedPreferences.setMockInitialValues({
        'aira_auth_logged_in': true,
        'aira_auth_user_email': 'user@example.com',
        'aira_auth_user_name': 'User',
      });

      final notifier = AuthNotifier();
      await notifier.checkAuthStatus();
      expect(notifier.state, equals(AuthStatus.authenticated));

      await notifier.signOut();
      expect(notifier.state, equals(AuthStatus.unauthenticated));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('aira_auth_logged_in'), isNull);
      expect(prefs.getString('aira_auth_user_email'), isNull);
    });

    test('signIn in offline mode (no Supabase) creates local session successfully', () async {
      final notifier = AuthNotifier();

      final success = await notifier.signIn('student@university.edu', 'secret123');
      expect(success, isTrue);
      expect(notifier.state, equals(AuthStatus.authenticated));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('aira_auth_logged_in'), isTrue);
      expect(prefs.getString('aira_auth_user_email'), equals('student@university.edu'));
      expect(prefs.getString('aira_auth_user_name'), equals('student'));
    });

    test('signIn with empty inputs fails and sets error message', () async {
      final notifier = AuthNotifier();

      final success = await notifier.signIn('   ', '');
      expect(success, isFalse);
      expect(notifier.state, equals(AuthStatus.error));
      expect(notifier.errorMessage, contains('Please enter email and password'));
    });
  });
}
