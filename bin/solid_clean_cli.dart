import 'dart:io';
import 'package:args/args.dart';

// ANSI escape codes for colorful prints.
const reset = "\x1B[0m";
const red = "\x1B[31m";
const green = "\x1B[32m";
const yellow = "\x1B[33m";

void colorPrint(String message, String colorCode) {
  print('$colorCode$message$reset');
}

void main(List<String> arguments) async {
  final parser = ArgParser()..addCommand('create');
  final results = parser.parse(arguments);

  if (results.command?.name == 'create') {
    final createArgs = results.command?.rest;

    if (createArgs == null || createArgs.isEmpty) {
      colorPrint('Invalid create command.', red);
      exit(1);
    }

    final parts = createArgs[0].split(':');
    if (parts.length != 2) {
      colorPrint('Invalid format. Expected format: type:Name', red);
      exit(1);
    }

    final type = parts[0];
    final prefix = parts[1];

    switch (type) {
      case 'screen':
        await _generateFile('lib/presentation/$prefix', screenTemplate, prefix, 'Screen');
        await _generateFile('lib/presentation/$prefix/controllers', controllerTemplate, prefix, 'Controller');
        await _generateFile('lib/infrastructure/dal/daos/entities', paramTemplate, prefix, 'Param');
        await _generateFile('lib/domain/repositories', abstractRepoTemplate, prefix, 'Repository');
        await _generateFile('lib/infrastructure/dal/apis', apiTemplate, prefix, 'Api');
        await _generateFile('lib/infrastructure/dal/repository', repoImplTemplate, prefix, 'Repository_Impl');
        await _generateFile('lib/domain/usecase', specificUseCaseTemplate, prefix, 'UseCase');
        await _generateFile('lib/infrastructure/dal/daos/models', modelTemplate, prefix, 'Response');
        await _generateBindingFile(prefix);
        await _updateRoutesFile(prefix);
        await _updateNavFile(prefix);
        await _addToPubspecYaml();
        await _generateDIFile(prefix);
        break;

      default:
        colorPrint('Unsupported type: $type', red);
        exit(1);
    }
  }
}

Future<void> _generateFile(String directory, String Function(String) templateFunc, String prefix, String suffix) async {
  String fileName;

  if (suffix == 'Screen') {
    fileName = '${prefix.toLowerCase()}_screen.dart';
  } else if (suffix == 'Controller') {
    fileName = '${prefix.toLowerCase()}_controller.dart';
  } else {
    fileName = '${prefix.toLowerCase()}.${suffix.toLowerCase().replaceAll('_', '.')}.dart';
  }

  directory = directory.toLowerCase();

  await Directory(directory).create(recursive: true);
  await File('$directory/$fileName').writeAsString(templateFunc(prefix));
  colorPrint('$suffix $fileName created successfully in the $directory directory.', green);
}

String paramTemplate(String name) => '''
class ${name}Param {
  ${name}Param.init();
}
''';
Future<void> _generateBindingFile(String prefix) async {
  final directory = 'lib/infrastructure/navigation/bindings/controllers';
  final fileName = '${prefix.toLowerCase()}.controller.binding.dart';

  await Directory(directory).create(recursive: true);
  await File('$directory/$fileName').writeAsString(bindingTemplate(prefix));
  colorPrint('Binding $fileName created successfully in the $directory directory.', green);
}

Future<void> _updateRoutesFile(String prefix) async {
  final filePath = 'lib/infrastructure/navigation/routes.dart';
  final file = File(filePath);

  if (!await file.exists()) {
    colorPrint('Error: routes.dart not found in lib/infrastructure/navigation/', red);
    return;
  }

  final newRoute = '  static const ${prefix.toUpperCase()} = \'/$prefix\';\n';

  final lines = await file.readAsLines();
  final insertPos = lines.lastIndexOf("}");

  if (insertPos == -1) {
    colorPrint('Error: Could not find the position to insert new route in routes.dart.', red);
    return;
  }

  lines.insert(insertPos, newRoute);
  await file.writeAsString(lines.join('\n'));
  colorPrint('Added route for $prefix in routes.dart.', green);
}

Future<void> _updateNavFile(String prefix) async {
  final filePath = 'lib/infrastructure/navigation/navigation.dart';
  final file = File(filePath);

  if (!await file.exists()) {
    colorPrint('Error: navigation.dart not found in lib/infrastructure/navigation/', red);
    return;
  }

  final screenImport = "import '../../presentation/${prefix.toLowerCase()}/${prefix.toLowerCase()}_screen.dart';";
  final bindingImport = "import 'bindings/controllers/${prefix.toLowerCase()}.controller.binding.dart';";

  final newPageRoute = '''
    GetPage(
      name: Routes.${prefix.toUpperCase()},
      page: () =>  ${prefix}Screen(),
      binding: ${prefix}ControllerBinding(),
    ),
  ''';

  final lines = await file.readAsLines();

  // Check if the imports already exist
  if (!lines.contains(screenImport)) {
    lines.insert(0, screenImport);
  }

  if (!lines.contains(bindingImport)) {
    lines.insert(1, bindingImport);
  }

  final insertPos = lines.lastIndexOf("  ];");

  if (insertPos == -1) {
    colorPrint('Error: Could not find the position to insert new GetPage in navigation.dart.', red);
    return;
  }

  lines.insert(insertPos, newPageRoute);
  await file.writeAsString(lines.join('\n'));
  colorPrint('Added GetPage route for $prefix in navigation.dart.', green);
}

Future<void> _addToPubspecYaml() async {
  final pubspecPath = 'pubspec.yaml';
  final file = File(pubspecPath);

  if (!await file.exists()) {
    colorPrint('Error: pubspec.yaml not found', red);
    return;
  }

  final lines = await file.readAsLines();

  // Find the position to insert the new dependency
  int dependenciesIndex = lines.indexOf('cupertino_icons');
  if (dependenciesIndex == -1) {
    colorPrint('Error: Could not find the "cupertino_icons:" line in pubspec.yaml.', red);
    return;
  }

  // Check if clean_arch dependency already exists. If so, remove it.
  final cleanArchIndex = lines.indexWhere((line) => line.startsWith('  clean_arch:'));
  if (cleanArchIndex != -1) {
    lines.removeRange(cleanArchIndex, cleanArchIndex + 2);
  }

  // Insert the new clean_arch dependency
  lines.insert(dependenciesIndex + 1, '  clean_arch: ');
  lines.insert(dependenciesIndex + 2, '    git: https://github.com/cg-tushar/clean_arch.git');

  await file.writeAsString(lines.join('\n'));
  colorPrint('Added or updated clean_arch to pubspec.yaml', green);
}

Future<void> _generateDIFile(String prefix) async {
  final baseDirectory = 'lib/infrastructure/di';
  final specificDirectory = '$baseDirectory/${prefix.toLowerCase()}_di';

  // Ensure base DI directory exists
  await Directory(baseDirectory).create(recursive: true);

  // Ensure specific {name}_di directory exists
  final diSpecificDirectory = Directory(specificDirectory);
  if (!await diSpecificDirectory.exists()) {
    await diSpecificDirectory.create();
    colorPrint('${prefix}_di directory created at $specificDirectory.', green);
  }

  final fileName = '${prefix.toLowerCase()}_di.dart';
  await File('$specificDirectory/$fileName').writeAsString(diTemplate(prefix));
  colorPrint('DI $fileName created successfully in the $specificDirectory directory.', green);
}

String diTemplate(String name) => '''
import '../../../domain/usecases/${name.toLowerCase()}.use_case.dart';
import '../../../presentation/${name.toLowerCase()}/controllers/${name.toLowerCase()}_controller.dart';
import '../../dal/daos/${name.toLowerCase()}_response.dart';
import '../../dal/repository/${name.toLowerCase()}.repo_impl.dart';
import 'package:get/get.dart';

class ${name}DI {
  // * injecting dependency and initializing the storage
  static init() async {
    // * Creating instance of Response model class
    Get.put(${name}Response());
    // * Creating instance of Implementation Repo class
    Get.put(${name}RepositoryIml<${name}Response>());
    // * adding Implementation repo in the same use-case
    Get.put(${name}UseCase<${name}Response, ${name}Param>(Get.find<${name}RepositoryIml<${name}Response>>()));
  }
}
''';
// File Templates:

String screenTemplate(String name) => '''
import 'package:flutter/material.dart';
import 'package:clean_arch/state_manager.dart';
import '../../infrastructure/dal/daos/models/${name.toLowerCase()}.response.dart';
import 'controllers/${name.toLowerCase()}_controller.dart';

class ${name}Screen extends StatelessWidget {
const ${name}Screen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$name')),
      body: SuperStateBuilder<${name}Controller, ${name}Response>(
        child: (controller, response) => Text(response.toString()),
      ),
    );
  }
}
''';

String controllerTemplate(String name) => '''
import 'package:clean_arch/state_manager.dart';
import '../../../domain/usecase/${name.toLowerCase()}.usecase.dart';
import '../../../infrastructure/dal/daos/models/${name.toLowerCase()}.response.dart';

class ${name}Controller extends SuperStateController<${name}Response>{
  ${name}Param ${name[0].toLowerCase()}${name.substring(1)}Param = ${name}Param.init();
  final ${name}UseCase<${name}Response, ${name}Param> ${name[0].toLowerCase()}${name.substring(1)}UseCase;
  ${name}Controller(this.${name[0].toLowerCase()}${name.substring(1)}UseCase);
}
''';

String abstractRepoTemplate(String name) => '''
import 'package:clean_arch/clean_arch.dart';

abstract class ${name}Repository<T, P> {
  Stream<NetworkResponse<T>> ${name.toLowerCase()}(P params);
}
''';

String apiTemplate(String name) => '''
import 'package:clean_arch/clean_arch.dart';

class ${name}Api implements APIRequestRepresentable {
}
''';

String repoImplTemplate(String name) => '''
import 'package:clean_arch/core/model/base_model.dart';
import '../../../domain/repositories/${name.toLowerCase()}.repository.dart';
import '../daos/entities/${name.toLowerCase()}.param.dart';

class ${name}RepositoryIml<T extends BaseModel> extends ${name}Repository<T, ${name}Param> {
}
''';

String specificUseCaseTemplate(String name) => '''
import 'package:clean_arch/clean_arch.dart';
import 'package:clean_arch/core/model/base_model.dart';
import '../../../domain/repositories/${name.toLowerCase()}.repository.dart';

class ${name}UseCase<T, P> extends ParamUseCase<T, P> {
 final ${name}Repository<T, P> _repo;
 ${name}UseCase(this._repo);
}
''';

String modelTemplate(String name) => '''
import 'package:clean_arch/core/model/base_model.dart';

class ${name}Response extends BaseModel<${name}Response> {
}
''';

String bindingTemplate(String name) => '''
import '../../../../domain/usecase/${name.toLowerCase()}.usecase.dart';
import 'package:get/get.dart';
import '../../../dal/daos/entities/${name.toLowerCase()}.param.dart';
import '../../../dal/daos/models/${name.toLowerCase()}.response.dart';
import '../../../../presentation/${name.toLowerCase()}/controllers/${name.toLowerCase()}_controller.dart';
import '../../../di/login_di/${name.toLowerCase()}_di.dart';

class ${name}ControllerBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<${name}Controller>(
      () => ${name}Controller(Get.find<${name}UseCase<${name}Response, ${name}Param>>()),
    );
    ${name}DI.init();
  }
}
''';
