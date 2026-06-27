import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/Models/field_definition.dart';

void main() {
  group('FieldDefinition Model', () {
    test('FieldDefinition for text field', () {
      final field = FieldDefinition(
        expectedType: ExpectedType.text,
        validator: (value) => null,
      );

      expect(field.expectedType, equals(ExpectedType.text));
      expect(field.isSuggested, equals(false));
      expect(field.confidence, equals(0.0));
    });

    test('Text validator accepts valid text', () {
      final validator = FieldDefinition.getValidatorForType(ExpectedType.text);

      expect(validator?.call('John Doe'), isNull);
      expect(validator?.call('Mary-Jane'), isNull);
      expect(validator?.call('First Last'), isNull);
    });

    test('Text validator rejects invalid text', () {
      final validator = FieldDefinition.getValidatorForType(ExpectedType.text);

      expect(validator?.call('John123'), isNotNull);
      expect(validator?.call('Test@'), isNotNull);
    });

    test('Number validator accepts valid numbers', () {
      final validator = FieldDefinition.getValidatorForType(ExpectedType.number);

      expect(validator?.call('123'), isNull);
      expect(validator?.call('45.67'), isNull);
      expect(validator?.call('-89'), isNull);
    });

    test('Number validator rejects invalid numbers', () {
      final validator = FieldDefinition.getValidatorForType(ExpectedType.number);

      expect(validator?.call('abc'), isNotNull);
      expect(validator?.call('12.34.56'), isNotNull);
    });

    test('Email validator accepts valid emails', () {
      final validator = FieldDefinition.getValidatorForType(ExpectedType.email);

      expect(validator?.call('john@example.com'), isNull);
      expect(validator?.call('test.user@domain.co.uk'), isNull);
    });

    test('Email validator rejects invalid emails', () {
      final validator = FieldDefinition.getValidatorForType(ExpectedType.email);

      expect(validator?.call('invalid-email'), isNotNull);
      expect(validator?.call('test@'), isNotNull);
      expect(validator?.call('@example.com'), isNotNull);
    });

    test('Phone validator accepts valid phone numbers', () {
      final validator = FieldDefinition.getValidatorForType(ExpectedType.phone);

      expect(validator?.call('+254712345678'), isNull);
      expect(validator?.call('0712345678'), isNull);
      expect(validator?.call('+1 (555) 123-4567'), isNull);
    });

    test('Phone validator rejects invalid phone numbers', () {
      final validator = FieldDefinition.getValidatorForType(ExpectedType.phone);

      expect(validator?.call('12345'), isNotNull);
      expect(validator?.call('abcdefghij'), isNotNull);
    });

    test('Date validator accepts valid dates', () {
      final validator = FieldDefinition.getValidatorForType(ExpectedType.date);

      expect(validator?.call('2024-01-15'), isNull);
      expect(validator?.call('2023-12-31'), isNull);
    });

    test('Date validator rejects invalid dates', () {
      final validator = FieldDefinition.getValidatorForType(ExpectedType.date);

      expect(validator?.call('2024-13-45'), isNotNull);
      expect(validator?.call('invalid-date'), isNotNull);
      expect(validator?.call('15-01-2024'), isNotNull);
    });

    test('Name validator accepts valid names', () {
      final validator = FieldDefinition.getValidatorForType(ExpectedType.name);

      expect(validator?.call('John Doe'), isNull);
      expect(validator?.call('Mary-Jane Smith'), isNull);
    });

    test('Name validator rejects invalid names', () {
      final validator = FieldDefinition.getValidatorForType(ExpectedType.name);

      expect(validator?.call('John123'), isNotNull);
      expect(validator?.call('Test@Name'), isNotNull);
    });

    test('Upload validator accepts valid file types', () {
      final validator = FieldDefinition.getValidatorForType(ExpectedType.upload);

      expect(validator?.call('document.pdf'), isNull);
      expect(validator?.call('image.jpg'), isNull);
      expect(validator?.call('photo.png'), isNull);
      expect(validator?.call('report.docx'), isNull);
    });

    test('Upload validator rejects invalid file types', () {
      final validator = FieldDefinition.getValidatorForType(ExpectedType.upload);

      expect(validator?.call('script.exe'), isNotNull);
      expect(validator?.call('archive.zip'), isNotNull);
      expect(validator?.call('video.mp4'), isNotNull);
    });

    test('Checkbox validator accepts valid values', () {
      final validator = FieldDefinition.getValidatorForType(ExpectedType.checkbox);

      expect(validator?.call('true'), isNull);
      expect(validator?.call('false'), isNull);
      expect(validator?.call('yes'), isNull);
      expect(validator?.call('no'), isNull);
      expect(validator?.call('1'), isNull);
      expect(validator?.call('0'), isNull);
    });

    test('Checkbox validator rejects invalid values', () {
      final validator = FieldDefinition.getValidatorForType(ExpectedType.checkbox);

      expect(validator?.call('maybe'), isNotNull);
      expect(validator?.call('2'), isNotNull);
    });

    test('Grid validator accepts valid JSON arrays', () {
      final validator = FieldDefinition.getValidatorForType(ExpectedType.grid);

      expect(validator?.call('[1, 2, 3]'), isNull);
      expect(validator?.call('["a", "b"]'), isNull);
    });

    test('Grid validator rejects non-JSON', () {
      final validator = FieldDefinition.getValidatorForType(ExpectedType.grid);

      expect(validator?.call('not json'), isNotNull);
      expect(validator?.call('{key: value}'), isNotNull);
    });

    test('FieldDefinition.toJson serializes correctly', () {
      final field = FieldDefinition(
        expectedType: ExpectedType.email,
        validator: (value) => null,
        isSuggested: true,
        confidence: 0.95,
        boundingBox: {'x': 10.0, 'y': 20.0},
      );

      final json = field.toJson();

      expect(json['expectedType'], equals('email'));
      expect(json['isSuggested'], equals(true));
      expect(json['confidence'], equals(0.95));
      expect(json['boundingBox'], equals({'x': 10.0, 'y': 20.0}));
    });

    test('FieldDefinition.fromJson deserializes correctly', () {
      final json = {
        'expectedType': 'phone',
        'isSuggested': true,
        'confidence': 0.88,
      };

      final field = FieldDefinition.fromJson(json);

      expect(field.expectedType, equals(ExpectedType.phone));
      expect(field.isSuggested, equals(true));
      expect(field.confidence, equals(0.88));
    });

    test('FieldDefinition with list item type', () {
      final json = {
        'expectedType': 'list',
        'listItemType': 'email',
        'isSuggested': false,
        'confidence': 0.75,
      };

      final field = FieldDefinition.fromJson(json);

      expect(field.expectedType, equals(ExpectedType.list));
      expect(field.listItemType, equals(ExpectedType.email));
    });

    test('Custom field type validator', () {
      final validator = FieldDefinition.getValidatorForType(ExpectedType.custom);

      expect(validator?.call('anything'), isNull);
      expect(validator?.call(''), isNull);
      expect(validator?.call(null), isNull);
    });

    test('Empty values are valid for most validators', () {
      expect(FieldDefinition.getValidatorForType(ExpectedType.text)?.call(''), isNull);
      expect(FieldDefinition.getValidatorForType(ExpectedType.number)?.call(''), isNull);
      expect(FieldDefinition.getValidatorForType(ExpectedType.email)?.call(''), isNull);
      expect(FieldDefinition.getValidatorForType(ExpectedType.phone)?.call(''), isNull);
      expect(FieldDefinition.getValidatorForType(ExpectedType.date)?.call(''), isNull);
    });

    test('Null values are valid for most validators', () {
      expect(FieldDefinition.getValidatorForType(ExpectedType.text)?.call(null), isNull);
      expect(FieldDefinition.getValidatorForType(ExpectedType.number)?.call(null), isNull);
      expect(FieldDefinition.getValidatorForType(ExpectedType.email)?.call(null), isNull);
    });

    test('FieldDefinition with suggested flag', () {
      final field = FieldDefinition(
        expectedType: ExpectedType.text,
        validator: (value) => null,
        isSuggested: true,
        confidence: 0.92,
      );

      expect(field.isSuggested, equals(true));
      expect(field.confidence, equals(0.92));
    });

    test('FieldDefinition with bounding box', () {
      final boundingBox = {'x': 50.5, 'y': 100.2, 'width': 200.0, 'height': 50.0};
      final field = FieldDefinition(
        expectedType: ExpectedType.text,
        validator: (value) => null,
        boundingBox: boundingBox,
      );

      expect(field.boundingBox, equals(boundingBox));
    });

    test('List validator with email items', () {
      final json = {
        'expectedType': 'list',
        'listItemType': 'email',
      };

      final field = FieldDefinition.fromJson(json);
      final validator = field.validator;

      expect(validator?.call('john@example.com,jane@example.com'), isNull);
      expect(validator?.call('invalid-email'), isNotNull);
    });
  });
}
