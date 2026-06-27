import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/Models/insured_item.dart';
import 'package:my_app/Models/policy.dart';
import 'package:my_app/insurance_app.dart';

void main() {
  group('InsuredItem Model', () {
    late PolicyType mockType;
    late PolicySubtype mockSubtype;
    late CoverageType mockCoverage;

    setUp(() {
      mockType = PolicyType(
        id: 'type1',
        name: 'Motor',
        description: 'Motor insurance',
      );
      mockSubtype = PolicySubtype(
        id: 'subtype1',
        name: 'Private',
        policyTypeId: 'type1',
        description: 'Private vehicle',
      );
      mockCoverage = CoverageType(
        id: 'coverage1',
        name: 'Comprehensive',
        description: 'Full coverage',
      );
    });

    test('InsuredItem creation with valid data', () {
      final item = InsuredItem(
        id: 'item1',
        name: 'John Doe',
        email: 'john@example.com',
        contact: '+254712345678',
        kraPin: 'P012345678A',
        details: {'key': 'value'},
        type: mockType,
        subtype: mockSubtype,
        coverageType: mockCoverage,
      );

      expect(item.id, equals('item1'));
      expect(item.name, equals('John Doe'));
      expect(item.email, equals('john@example.com'));
    });

    test('InsuredItem validates KRA PIN format', () {
      expect(
        () => InsuredItem(
          id: 'item1',
          name: 'John Doe',
          email: 'john@example.com',
          contact: '+254712345678',
          kraPin: 'invalid',
          details: {},
          type: mockType,
          subtype: mockSubtype,
          coverageType: mockCoverage,
        ),
        throwsAssertionError,
      );
    });

    test('InsuredItem validates email format', () {
      expect(
        () => InsuredItem(
          id: 'item1',
          name: 'John Doe',
          email: 'invalid-email',
          contact: '+254712345678',
          kraPin: 'P012345678A',
          details: {},
          type: mockType,
          subtype: mockSubtype,
          coverageType: mockCoverage,
        ),
        throwsAssertionError,
      );
    });

    test('InsuredItem allows empty email', () {
      final item = InsuredItem(
        id: 'item1',
        name: 'John Doe',
        email: '',
        contact: '+254712345678',
        kraPin: 'P012345678A',
        details: {},
        type: mockType,
        subtype: mockSubtype,
        coverageType: mockCoverage,
      );

      expect(item.email, equals(''));
    });

    test('InsuredItem.fromMap deserializes correctly', () {
      final map = {
        'id': 'item1',
        'name': 'Jane Smith',
        'email': 'jane@example.com',
        'contact': '+254798765432',
        'kraPin': 'A987654321B',
        'details': {'key': 'value'},
        'type': {
          'id': 'type1',
          'name': 'Motor',
          'description': 'Motor insurance',
        },
        'subtype': {
          'id': 'subtype1',
          'name': 'Private',
          'policyTypeId': 'type1',
          'description': 'Private vehicle',
        },
        'coverageType': {
          'id': 'coverage1',
          'name': 'Comprehensive',
          'description': 'Full coverage',
        },
      };

      final item = InsuredItem.fromMap(map);

      expect(item.id, equals('item1'));
      expect(item.name, equals('Jane Smith'));
      expect(item.email, equals('jane@example.com'));
    });

    test('InsuredItem.toMap serializes correctly', () {
      final item = InsuredItem(
        id: 'item1',
        name: 'John Doe',
        email: 'john@example.com',
        contact: '+254712345678',
        kraPin: 'P012345678A',
        details: {'registration': 'KBC123A'},
        type: mockType,
        subtype: mockSubtype,
        coverageType: mockCoverage,
        previousCompanies: ['Company A', 'Company B'],
      );

      final map = item.toMap();

      expect(map['id'], equals('item1'));
      expect(map['name'], equals('John Doe'));
      expect(map['email'], equals('john@example.com'));
      expect(map['previousCompanies'], equals(['Company A', 'Company B']));
    });

    test('InsuredItem.copyWith creates new instance with updated fields', () {
      final item = InsuredItem(
        id: 'item1',
        name: 'John Doe',
        email: 'john@example.com',
        contact: '+254712345678',
        kraPin: 'P012345678A',
        details: {},
        type: mockType,
        subtype: mockSubtype,
        coverageType: mockCoverage,
      );

      final updatedItem = item.copyWith(
        name: 'Jane Doe',
        email: 'jane@example.com',
      );

      expect(updatedItem.name, equals('Jane Doe'));
      expect(updatedItem.email, equals('jane@example.com'));
      expect(updatedItem.id, equals('item1'));
    });

    test('InsuredItem equality operator works', () {
      final item1 = InsuredItem(
        id: 'item1',
        name: 'John Doe',
        email: 'john@example.com',
        contact: '+254712345678',
        kraPin: 'P012345678A',
        details: {},
        type: mockType,
        subtype: mockSubtype,
        coverageType: mockCoverage,
      );

      final item2 = InsuredItem(
        id: 'item1',
        name: 'John Doe',
        email: 'john@example.com',
        contact: '+254712345678',
        kraPin: 'P012345678A',
        details: {},
        type: mockType,
        subtype: mockSubtype,
        coverageType: mockCoverage,
      );

      expect(item1, equals(item2));
    });

    test('InsuredItem.fromJson creates instance from JSON', () {
      final json = {
        'id': 'item1',
        'name': 'John Doe',
        'email': 'john@example.com',
        'contact': '+254712345678',
        'kraPin': 'P012345678A',
        'details': {},
        'type': {
          'id': 'type1',
          'name': 'Motor',
          'description': 'Motor insurance',
        },
        'subtype': {
          'id': 'subtype1',
          'name': 'Private',
          'policyTypeId': 'type1',
          'description': 'Private vehicle',
        },
        'coverageType': {
          'id': 'coverage1',
          'name': 'Comprehensive',
          'description': 'Full coverage',
        },
      };

      final item = InsuredItem.fromJson(json);

      expect(item.id, equals('item1'));
      expect(item.name, equals('John Doe'));
    });

    test('InsuredItem with previous companies', () {
      final item = InsuredItem(
        id: 'item1',
        name: 'John Doe',
        email: 'john@example.com',
        contact: '+254712345678',
        kraPin: 'P012345678A',
        details: {},
        type: mockType,
        subtype: mockSubtype,
        coverageType: mockCoverage,
        previousCompanies: ['APA', 'AAR', 'BRITAM'],
      );

      expect(item.previousCompanies, equals(['APA', 'AAR', 'BRITAM']));
      expect(item.previousCompanies.length, equals(3));
    });

    test('InsuredItem with logbook path', () {
      final item = InsuredItem(
        id: 'item1',
        name: 'John Doe',
        email: 'john@example.com',
        contact: '+254712345678',
        kraPin: 'P012345678A',
        details: {},
        type: mockType,
        subtype: mockSubtype,
        coverageType: mockCoverage,
        logbookPath: '/path/to/logbook.pdf',
      );

      expect(item.logbookPath, equals('/path/to/logbook.pdf'));
    });
  });
}
