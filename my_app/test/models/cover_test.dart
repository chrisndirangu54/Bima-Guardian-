import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/Models/cover.dart';
import 'package:my_app/Models/policy.dart';
import 'package:my_app/insurance_app.dart';

void main() {
  group('Cover Model', () {
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

    test('Cover creation with valid data', () {
      final cover = Cover(
        id: 'cover1',
        name: 'My Car Insurance',
        insuredItemId: 'item1',
        companyId: 'company1',
        type: mockType,
        subtype: mockSubtype,
        coverageType: mockCoverage,
        status: CoverStatus.active,
        pdfTemplateKey: 'template1',
        paymentStatus: 'paid',
        startDate: DateTime(2024, 1, 1),
      );

      expect(cover.id, equals('cover1'));
      expect(cover.name, equals('My Car Insurance'));
      expect(cover.status, equals(CoverStatus.active));
      expect(cover.extensionCount, equals(0));
    });

    test('Cover extension increases extension count and updates date', () {
      final initialDate = DateTime(2024, 12, 31);
      final cover = Cover(
        id: 'cover1',
        name: 'Test Cover',
        insuredItemId: 'item1',
        companyId: 'company1',
        type: mockType,
        subtype: mockSubtype,
        coverageType: mockCoverage,
        status: CoverStatus.active,
        pdfTemplateKey: 'template1',
        paymentStatus: 'paid',
        startDate: DateTime(2024, 1, 1),
        expirationDate: initialDate,
        extensionCount: 0,
      );

      final extendedCover = cover.extend();

      expect(extendedCover.extensionCount, equals(1));
      expect(extendedCover.expirationDate,
          equals(initialDate.add(Duration(days: 30))));
      expect(extendedCover.status, equals(CoverStatus.extended));
    });

    test('Cover extension fails when max extensions reached', () {
      final cover = Cover(
        id: 'cover1',
        name: 'Test Cover',
        insuredItemId: 'item1',
        companyId: 'company1',
        type: mockType,
        subtype: mockSubtype,
        coverageType: mockCoverage,
        status: CoverStatus.active,
        pdfTemplateKey: 'template1',
        paymentStatus: 'paid',
        startDate: DateTime(2024, 1, 1),
        expirationDate: DateTime(2024, 12, 31),
        extensionCount: 2,
      );

      expect(
        () => cover.extend(),
        throwsA(isA<StateError>()),
      );
    });

    test('Cover extension fails when expirationDate is null', () {
      final cover = Cover(
        id: 'cover1',
        name: 'Test Cover',
        insuredItemId: 'item1',
        companyId: 'company1',
        type: mockType,
        subtype: mockSubtype,
        coverageType: mockCoverage,
        status: CoverStatus.active,
        pdfTemplateKey: 'template1',
        paymentStatus: 'paid',
        startDate: DateTime(2024, 1, 1),
        extensionCount: 0,
      );

      expect(
        () => cover.extend(),
        throwsA(isA<StateError>()),
      );
    });

    test('Cover.toJson serializes correctly', () {
      final cover = Cover(
        id: 'cover1',
        name: 'Test Cover',
        insuredItemId: 'item1',
        companyId: 'company1',
        type: mockType,
        subtype: mockSubtype,
        coverageType: mockCoverage,
        status: CoverStatus.active,
        pdfTemplateKey: 'template1',
        paymentStatus: 'paid',
        premium: 5000.0,
        billingFrequency: 'monthly',
        startDate: DateTime(2024, 1, 1),
        expirationDate: DateTime(2024, 12, 31),
      );

      final json = cover.toJson();

      expect(json['id'], equals('cover1'));
      expect(json['name'], equals('Test Cover'));
      expect(json['status'], equals('active'));
      expect(json['premium'], equals(5000.0));
      expect(json['billingFrequency'], equals('monthly'));
    });

    test('Cover.fromJson deserializes correctly', () {
      final json = {
        'id': 'cover1',
        'name': 'Deserialized Cover',
        'insuredItemId': 'item1',
        'companyId': 'company1',
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
        'status': 'active',
        'pdfTemplateKey': 'template1',
        'paymentStatus': 'paid',
        'premium': 5000.0,
        'startDate': DateTime(2024, 1, 1).toIso8601String(),
        'expirationDate': DateTime(2024, 12, 31).toIso8601String(),
      };

      final cover = Cover.fromJson(json);

      expect(cover.id, equals('cover1'));
      expect(cover.name, equals('Deserialized Cover'));
      expect(cover.status, equals(CoverStatus.active));
      expect(cover.premium, equals(5000.0));
    });

    test('Cover.copyWith creates new instance with updated fields', () {
      final cover = Cover(
        id: 'cover1',
        name: 'Original Cover',
        insuredItemId: 'item1',
        companyId: 'company1',
        type: mockType,
        subtype: mockSubtype,
        coverageType: mockCoverage,
        status: CoverStatus.active,
        pdfTemplateKey: 'template1',
        paymentStatus: 'paid',
        startDate: DateTime(2024, 1, 1),
      );

      final updatedCover = cover.copyWith(
        name: 'Updated Cover',
        paymentStatus: 'pending',
      );

      expect(updatedCover.name, equals('Updated Cover'));
      expect(updatedCover.paymentStatus, equals('pending'));
      expect(updatedCover.id, equals('cover1'));
    });

    test('Cover equality operator works correctly', () {
      final cover1 = Cover(
        id: 'cover1',
        name: 'Test Cover',
        insuredItemId: 'item1',
        companyId: 'company1',
        type: mockType,
        subtype: mockSubtype,
        coverageType: mockCoverage,
        status: CoverStatus.active,
        pdfTemplateKey: 'template1',
        paymentStatus: 'paid',
        startDate: DateTime(2024, 1, 1),
      );

      final cover2 = Cover(
        id: 'cover1',
        name: 'Test Cover',
        insuredItemId: 'item1',
        companyId: 'company1',
        type: mockType,
        subtype: mockSubtype,
        coverageType: mockCoverage,
        status: CoverStatus.active,
        pdfTemplateKey: 'template1',
        paymentStatus: 'paid',
        startDate: DateTime(2024, 1, 1),
      );

      expect(cover1, equals(cover2));
    });

    test('Cover assertion for invalid extension count', () {
      expect(
        () => Cover(
          id: 'cover1',
          name: 'Test',
          insuredItemId: 'item1',
          companyId: 'company1',
          type: mockType,
          subtype: mockSubtype,
          coverageType: mockCoverage,
          status: CoverStatus.active,
          pdfTemplateKey: 'template1',
          paymentStatus: 'paid',
          startDate: DateTime(2024, 1, 1),
          extensionCount: 3,
        ),
        throwsAssertionError,
      );
    });
  });
}
