import 'package:my_app/Models/company.dart' as company_models;
import 'package:my_app/Models/policy.dart';

class PolicyModuleResolution {
  final PolicyType type;
  final PolicySubtype subtype;
  final CoverageType coverageType;
  final CoverageDetail? coverageDetail;
  final List<ModularPolicyComponent> additionalLevels;
  final String? companyName;
  final ModularPolicyBundle<PolicyType, PolicySubtype, CoverageType> bundle;

  const PolicyModuleResolution({
    required this.type,
    required this.subtype,
    required this.coverageType,
    this.coverageDetail,
    this.additionalLevels = const [],
    required this.bundle,
    this.companyName,
  });
}

abstract class PolicyModule {
  String get moduleId;
  String get displayName;
  String get guiHint;

  Future<PolicyModuleResolution?> resolveFromMessage(String message);
}

class ConfigDrivenPolicyModule implements PolicyModule {
  static const int _maxDynamicLevels = 25;

  final PolicyType policyType;
  final Future<List<PolicySubtype>> Function(String policyTypeId) getSubtypes;
  final Future<List<CoverageType>> Function(String subtypeId) getCoverageTypes;
  final Future<List<CoverageDetail>> Function(String coverageTypeId)?
      getCoverageDetails;
  final Future<List<ModularPolicyComponent>> Function(
    int levelIndex,
    ModularPolicyComponent parent,
  )? getNextLevels;
  final Future<List<company_models.Company>> Function() getCompanies;

  const ConfigDrivenPolicyModule({
    required this.policyType,
    required this.getSubtypes,
    required this.getCoverageTypes,
    this.getCoverageDetails,
    this.getNextLevels,
    required this.getCompanies,
  });

  @override
  String get moduleId => policyType.id;

  @override
  String get displayName => policyType.name;

  @override
  String get guiHint => 'Apply for ${policyType.name} insurance';

  @override
  Future<PolicyModuleResolution?> resolveFromMessage(String message) async {
    final normalizedMessage = message.toLowerCase();
    if (!_matchesPolicyType(normalizedMessage, policyType)) {
      return null;
    }

    final subtypes = await getSubtypes(policyType.id);
    if (subtypes.isEmpty) {
      return null;
    }

    final selectedSubtype = _matchByName(
      normalizedMessage,
      subtypes,
      (subtype) => subtype.name,
    );

    final coverageTypes = await getCoverageTypes(selectedSubtype.id);
    if (coverageTypes.isEmpty) {
      return null;
    }

    final selectedCoverageType = _matchByName(
      normalizedMessage,
      coverageTypes,
      (coverage) => coverage.name,
    );
    CoverageDetail? selectedCoverageDetail;
    if (getCoverageDetails != null) {
      final details = await getCoverageDetails!(selectedCoverageType.id);
      if (details.isNotEmpty) {
        selectedCoverageDetail = _matchByName(
          normalizedMessage,
          details,
          (detail) => detail.name,
        );
      }
    }
    final additionalLevels = await _resolveAdditionalLevels(
      normalizedMessage: normalizedMessage,
      startingParent: selectedCoverageDetail ?? selectedCoverageType,
    );

    final companies = await getCompanies();
    final selectedCompany = companies.isEmpty
        ? null
        : _matchByName(
            normalizedMessage,
            companies,
            (company) => company.name,
          ).name;

    return PolicyModuleResolution(
      type: policyType,
      subtype: selectedSubtype,
      coverageType: selectedCoverageType,
      coverageDetail: selectedCoverageDetail,
      additionalLevels: additionalLevels,
      bundle: ModularPolicyBundle<PolicyType, PolicySubtype, CoverageType>(
        moduleName: displayName,
        type: policyType,
        subtype: selectedSubtype,
        coverageType: selectedCoverageType,
        coverageDetail: selectedCoverageDetail,
        additionalLevels: additionalLevels,
      ),
      companyName: selectedCompany,
    );
  }

  Future<List<ModularPolicyComponent>> _resolveAdditionalLevels({
    required String normalizedMessage,
    required ModularPolicyComponent startingParent,
  }) async {
    if (getNextLevels == null) return const [];
    final resolved = <ModularPolicyComponent>[];
    ModularPolicyComponent parent = startingParent;
    for (var levelIndex = 0; levelIndex < _maxDynamicLevels; levelIndex++) {
      final options = await getNextLevels!(levelIndex, parent);
      if (options.isEmpty) break;
      final selected = _matchByName(
        normalizedMessage,
        options,
        (level) => level.name,
      );
      resolved.add(selected);
      parent = selected;
    }
    return resolved;
  }

  bool _matchesPolicyType(String normalizedMessage, PolicyType type) {
    final typeName = type.name.toLowerCase();
    if (normalizedMessage.contains(typeName)) {
      return true;
    }

    final descriptionTokens = type.description
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.length > 3);
    return descriptionTokens.any(normalizedMessage.contains);
  }

  T _matchByName<T>(
    String normalizedMessage,
    List<T> options,
    String Function(T item) getName,
  ) {
    return options.firstWhere(
      (item) => normalizedMessage.contains(getName(item).toLowerCase()),
      orElse: () => options.first,
    );
  }
}

class MotorPolicyModule extends ConfigDrivenPolicyModule {
  const MotorPolicyModule({
    required super.policyType,
    required super.getSubtypes,
    required super.getCoverageTypes,
    super.getCoverageDetails,
    super.getNextLevels,
    required super.getCompanies,
  });

  @override
  String get guiHint =>
      'Motor module: include vehicle type, subtype, and preferred company';
}

class MedicalPolicyModule extends ConfigDrivenPolicyModule {
  const MedicalPolicyModule({
    required super.policyType,
    required super.getSubtypes,
    required super.getCoverageTypes,
    super.getCoverageDetails,
    super.getNextLevels,
    required super.getCompanies,
  });

  @override
  String get guiHint =>
      'Medical module: include plan level, beneficiaries, and preferred company';
}

class TravelPolicyModule extends ConfigDrivenPolicyModule {
  const TravelPolicyModule({
    required super.policyType,
    required super.getSubtypes,
    required super.getCoverageTypes,
    super.getCoverageDetails,
    super.getNextLevels,
    required super.getCompanies,
  });

  @override
  String get guiHint =>
      'Travel module: include destination, duration, and preferred company';
}

class GenericPolicyModule extends ConfigDrivenPolicyModule {
  const GenericPolicyModule({
    required super.policyType,
    required super.getSubtypes,
    required super.getCoverageTypes,
    super.getCoverageDetails,
    super.getNextLevels,
    required super.getCompanies,
  });
}

class PolicyModuleFactory {
  static final Map<String, PolicyModule Function(_PolicyModuleDependencies)>
      _builders = {
    'motor': (deps) => MotorPolicyModule(
          policyType: deps.policyType,
          getSubtypes: deps.getSubtypes,
          getCoverageTypes: deps.getCoverageTypes,
          getCoverageDetails: deps.getCoverageDetails,
          getNextLevels: deps.getNextLevels,
          getCompanies: deps.getCompanies,
        ),
    'medical': (deps) => MedicalPolicyModule(
          policyType: deps.policyType,
          getSubtypes: deps.getSubtypes,
          getCoverageTypes: deps.getCoverageTypes,
          getCoverageDetails: deps.getCoverageDetails,
          getNextLevels: deps.getNextLevels,
          getCompanies: deps.getCompanies,
        ),
    'travel': (deps) => TravelPolicyModule(
          policyType: deps.policyType,
          getSubtypes: deps.getSubtypes,
          getCoverageTypes: deps.getCoverageTypes,
          getCoverageDetails: deps.getCoverageDetails,
          getNextLevels: deps.getNextLevels,
          getCompanies: deps.getCompanies,
        ),
  };

  static void registerBuilder({
    required String policyTypeName,
    required PolicyModule Function(
      PolicyType policyType,
      Future<List<PolicySubtype>> Function(String policyTypeId) getSubtypes,
      Future<List<CoverageType>> Function(String subtypeId) getCoverageTypes,
      Future<List<CoverageDetail>> Function(String coverageTypeId)?
          getCoverageDetails,
      Future<List<ModularPolicyComponent>> Function(
        int levelIndex,
        ModularPolicyComponent parent,
      )?
          getNextLevels,
      Future<List<company_models.Company>> Function() getCompanies,
    )
        builder,
  }) {
    _builders[policyTypeName.toLowerCase()] = (deps) => builder(
          deps.policyType,
          deps.getSubtypes,
          deps.getCoverageTypes,
          deps.getCoverageDetails,
          deps.getNextLevels,
          deps.getCompanies,
        );
  }

  static PolicyModule fromPolicyType({
    required PolicyType policyType,
    required Future<List<PolicySubtype>> Function(String policyTypeId)
        getSubtypes,
    required Future<List<CoverageType>> Function(String subtypeId)
        getCoverageTypes,
    Future<List<CoverageDetail>> Function(String coverageTypeId)?
        getCoverageDetails,
    Future<List<ModularPolicyComponent>> Function(
      int levelIndex,
      ModularPolicyComponent parent,
    )?
        getNextLevels,
    required Future<List<company_models.Company>> Function() getCompanies,
  }) {
    final deps = _PolicyModuleDependencies(
      policyType: policyType,
      getSubtypes: getSubtypes,
      getCoverageTypes: getCoverageTypes,
      getCoverageDetails: getCoverageDetails,
      getNextLevels: getNextLevels,
      getCompanies: getCompanies,
    );
    final builder = _builders[policyType.name.toLowerCase()];
    if (builder != null) {
      return builder(deps);
    }
    return GenericPolicyModule(
      policyType: policyType,
      getSubtypes: getSubtypes,
      getCoverageTypes: getCoverageTypes,
      getCoverageDetails: getCoverageDetails,
      getNextLevels: getNextLevels,
      getCompanies: getCompanies,
    );
  }
}

class _PolicyModuleDependencies {
  final PolicyType policyType;
  final Future<List<PolicySubtype>> Function(String policyTypeId) getSubtypes;
  final Future<List<CoverageType>> Function(String subtypeId) getCoverageTypes;
  final Future<List<CoverageDetail>> Function(String coverageTypeId)?
      getCoverageDetails;
  final Future<List<ModularPolicyComponent>> Function(
    int levelIndex,
    ModularPolicyComponent parent,
  )? getNextLevels;
  final Future<List<company_models.Company>> Function() getCompanies;

  const _PolicyModuleDependencies({
    required this.policyType,
    required this.getSubtypes,
    required this.getCoverageTypes,
    this.getCoverageDetails,
    this.getNextLevels,
    required this.getCompanies,
  });
}

class PolicyModuleMatch {
  final PolicyModule module;
  final PolicyModuleResolution resolution;

  const PolicyModuleMatch({required this.module, required this.resolution});
}

class PolicyModuleResolver {
  static Future<PolicyModuleMatch?> resolve({
    required String message,
    required List<PolicyModule> modules,
  }) async {
    for (final module in modules) {
      final resolution = await module.resolveFromMessage(message);
      if (resolution != null) {
        return PolicyModuleMatch(module: module, resolution: resolution);
      }
    }
    return null;
  }
}
