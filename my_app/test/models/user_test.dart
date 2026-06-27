import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/Models/user.dart';

void main() {
  group('User Model', () {
    test('User.fromMap creates user correctly', () {
      const uid = 'user123';
      final userData = {
        'details': {
          'name': 'John Doe',
          'email': 'john@example.com',
          'phone': '+254712345678',
        },
        'role': 'user',
        'isAdmin': false,
      };

      final user = User.fromMap(uid, userData);

      expect(user.uid, equals(uid));
      expect(user.name, equals('John Doe'));
      expect(user.email, equals('john@example.com'));
      expect(user.phone, equals('+254712345678'));
      expect(user.role, equals('user'));
      expect(user.isAdmin, equals(false));
    });

    test('User.fromMap with missing details uses defaults', () {
      const uid = 'user456';
      final userData = {
        'role': 'admin',
        'isAdmin': true,
      };

      final user = User.fromMap(uid, userData);

      expect(user.uid, equals(uid));
      expect(user.name, equals('Anonymous'));
      expect(user.email, equals(''));
      expect(user.phone, equals(''));
      expect(user.role, equals('admin'));
      expect(user.isAdmin, equals(true));
    });

    test('User with admin role is recognized as admin', () {
      const uid = 'admin123';
      final userData = {
        'details': {
          'name': 'Admin User',
          'email': 'admin@example.com',
          'phone': '+254712345678',
        },
        'role': 'admin',
        'isAdmin': true,
      };

      final user = User.fromMap(uid, userData);

      expect(user.isAdmin, equals(true));
      expect(user.role, equals('admin'));
    });

    test('User.toMap converts user to map correctly', () {
      final user = User(
        uid: 'user123',
        name: 'John Doe',
        email: 'john@example.com',
        phone: '+254712345678',
        role: 'user',
        isAdmin: false,
        createdAt: DateTime(2024, 1, 1),
      );

      final userMap = user.toMap();

      expect(userMap['details']['name'], equals('John Doe'));
      expect(userMap['details']['email'], equals('john@example.com'));
      expect(userMap['details']['phone'], equals('+254712345678'));
      expect(userMap['role'], equals('user'));
      expect(userMap['isAdmin'], equals(false));
    });

    test('User can be created with all fields', () {
      final createdAt = DateTime(2024, 1, 15);
      final user = User(
        uid: 'user789',
        name: 'Jane Smith',
        email: 'jane@example.com',
        phone: '+254798765432',
        role: 'agent',
        isAdmin: false,
        createdAt: createdAt,
      );

      expect(user.uid, equals('user789'));
      expect(user.name, equals('Jane Smith'));
      expect(user.email, equals('jane@example.com'));
      expect(user.phone, equals('+254798765432'));
      expect(user.role, equals('agent'));
      expect(user.isAdmin, equals(false));
      expect(user.createdAt, equals(createdAt));
    });
  });
}
