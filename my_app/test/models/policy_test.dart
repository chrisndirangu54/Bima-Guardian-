import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/Models/policy.dart';

void main() {
  group('PolicyType Model', () {
    test('PolicyType.fromJson creates instance correctly', () {
      final json = {
        'id': 'policy_type_1',
        'name': 'Motor Insurance',
        'description': 'Vehicle insurance coverage',
      };

      final policyType = PolicyType.fromJson(json);

      expect(policyType.id, equals('policy_type_1'));
      expect(policyType.name, equals('Motor Insurance'));
      expect(policyType.description, equals('Vehicle insurance coverage'));
    });

    test('PolicyType.toJson serializes correctly', () {
      final policyType = PolicyType(
        id: 'pt123',
        name: 'Health Insurance',
        description: 'Health coverage',
      );

      final json = policyType.toJson();

      expect(json['id'], equals('pt123'));
      expect(json['name'], equals('Health Insurance'));
      expect(json['description'], equals('Health coverage'));
    });

    test('PolicyType.fromMap creates instance from map', () {
      final map = {
        'id': 'pt456',
        'name': 'Property Insurance',
        'description': 'Property coverage',
      };

      final policyType = PolicyType.fromMap(map);

      expect(policyType.id, equals('pt456'));
      expect(policyType.name, equals('Property Insurance'));
    });

    test('PolicyType.toMap converts to map correctly', () {
      final policyType = PolicyType(
        id: 'pt789',
        name: 'Travel Insurance',
        description: 'Travel coverage',
      );

      final map = policyType.toMap();

      expect(map['id'], equals('pt789'));
      expect(map['name'], equals('Travel Insurance'));
      expect(map['description'], equals('Travel coverage'));
    });

    test('PolicyType.fromFirestore creates instance from Firestore data', () {
      final data = {
        'id': 'pt999',
        'name': 'Life Insurance',
        'description': 'Life coverage',
      };

      final policyType = PolicyType.fromFirestore(data);

      expect(policyType.id, equals('pt999'));
      expect(policyType.name, equals('Life Insurance'));
    });

    test('PolicyType with missing fields uses defaults', () {
      final map = <String, dynamic>{};

      final policyType = PolicyType.fromMap(map);

      expect(policyType.id, equals(''));
      expect(policyType.name, equals(''));
      expect(policyType.description, equals(''));
    });
  });

  group('PolicySubtype Model', () {
    test('PolicySubtype.fromJson creates instance correctly', () {
      final json = {
        'id': 'subtype_1',
        'name': 'Private Vehicle',
        'policyTypeId': 'policy_type_1',
        'description': 'Coverage for private vehicles',
      };

      final subtype = PolicySubtype.fromJson(json);

      expect(subtype.id, equals('subtype_1'));
      expect(subtype.name, equals('Private Vehicle'));
      expect(subtype.policyTypeId, equals('policy_type_1'));
      expect(subtype.description, equals('Coverage for private vehicles'));
    });

    test('PolicySubtype.toJson serializes correctly', () {
      final subtype = PolicySubtype(
        id: 'st123',
        name: 'Commercial Vehicle',
        policyTypeId: 'pt123',
        description: 'Commercial coverage',
      );

      final json = subtype.toJson();

      expect(json['id'], equals('st123'));
      expect(json['name'], equals('Commercial Vehicle'));
      expect(json['policyTypeId'], equals('pt123'));
    });

    test('PolicySubtype.toString returns name', () {
      final subtype = PolicySubtype(
        id: 'st456',
        name: 'Test Subtype',
        policyTypeId: 'pt456',
        description: 'Test',
      );

      expect(subtype.toString(), equals('Test Subtype'));
    });
  });

  group('CoverageType Model', () {
    test('CoverageType.fromJson creates instance correctly', () {
      final json = {
        'id': 'coverage_1',
        'name': 'Third Party',
        'description': 'Third party liability coverage',
      };

      final coverageType = CoverageType.fromJson(json);

      expect(coverageType.id, equals('coverage_1'));
      expect(coverageType.name, equals('Third Party'));
      expect(coverageType.description, equals('Third party liability coverage'));
    });

    test('CoverageType.toString returns name', () {
      final coverageType = CoverageType(
        id: 'ct123',
        name: 'Comprehensive',
        description: 'Full coverage',
      );

      expect(coverageType.toString(), equals('Comprehensive'));
    });

    test('CoverageType.toMap converts correctly', () {
      final coverageType = CoverageType(
        id: 'ct456',
        name: 'Collision',
        description: 'Collision coverage',
      );

      final map = coverageType.toMap();

      expect(map['id'], equals('ct456'));
      expect(map['name'], equals('Collision'));
    });
  });

  group('CoverageDetail Model', () {
    test('CoverageDetail.fromMap creates instance correctly', () {
      final map = {
        'id': 'detail_1',
        'name': 'Windscreen Coverage',
        'description': 'Windscreen damage coverage',
        'coverageTypeId': 'coverage_1',
        'icon': 'windscreen',
      };

      final detail = CoverageDetail.fromMap(map);

      expect(detail.id, equals('detail_1'));
      expect(detail.name, equals('Windscreen Coverage'));
      expect(detail.coverageTypeId, equals('coverage_1'));
      expect(detail.icon, equals('windscreen'));
    });

    test('CoverageDetail.toMap converts correctly', () {
      final detail = CoverageDetail(
        id: 'detail123',
        name: 'Theft Coverage',
        description: 'Protection against theft',
        coverageTypeId: 'coverage_123',
        icon: 'theft',
      );

      final map = detail.toMap();

      expect(map['id'], equals('detail123'));
      expect(map['name'], equals('Theft Coverage'));
    });

    test('CoverageDetail.fromFirestore creates instance from Firestore', () {
      final data = {
        'id': 'detail_fire',
        'name': 'Fire Coverage',
        'description': 'Fire damage coverage',
        'coverageTypeId': 'coverage_fire',
        'icon': 'fire',
      };

      final detail = CoverageDetail.fromFirestore(data);

      expect(detail.id, equals('detail_fire'));
      expect(detail.name, equals('Fire Coverage'));
    });
  });
}
