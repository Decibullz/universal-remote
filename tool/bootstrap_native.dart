import 'dart:io';

Future<void> main() async {
  final root = Directory.current;

  if (!File('${root.path}/pubspec.yaml').existsSync()) {
    stderr.writeln('Run this from the project root.');
    exitCode = 1;
    return;
  }

  final preserved = <String, List<int>>{};
  for (final path in [
    'pubspec.yaml',
    'analysis_options.yaml',
    'README.md',
  ]) {
    final file = File('${root.path}/$path');
    if (file.existsSync()) {
      preserved[path] = file.readAsBytesSync();
    }
  }

  final lib = Directory('${root.path}/lib');
  if (lib.existsSync()) {
    for (final entity in lib.listSync(recursive: true)) {
      if (entity is File) {
        final relative = entity.path.substring(root.path.length + 1);
        preserved[relative] = entity.readAsBytesSync();
      }
    }
  }

  stdout.writeln('Generating native Flutter scaffolding...');
  final create = await Process.run(
    'flutter',
    [
      'create',
      '--platforms=ios,android',
      '--project-name',
      'universal_tv_remote',
      '--org',
      'com.codysnell',
      '.',
    ],
    runInShell: true,
  );

  stdout.write(create.stdout);
  stderr.write(create.stderr);

  if (create.exitCode != 0) {
    exitCode = create.exitCode;
    return;
  }

  for (final entry in preserved.entries) {
    final file = File('${root.path}/${entry.key}');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(entry.value);
  }

  _patchIos(root.path);
  _patchAndroid(root.path);

  stdout.writeln('Getting packages...');
  final pubGet = await Process.run(
    'flutter',
    ['pub', 'get'],
    runInShell: true,
  );
  stdout.write(pubGet.stdout);
  stderr.write(pubGet.stderr);

  if (pubGet.exitCode != 0) {
    exitCode = pubGet.exitCode;
    return;
  }

  stdout.writeln('');
  stdout.writeln('Native setup complete.');
  stdout.writeln('Next: open ios/Runner.xcworkspace on your Mac and choose your signing Team.');
}

void _patchIos(String root) {
  final file = File('$root/ios/Runner/Info.plist');
  if (!file.existsSync()) {
    return;
  }

  var text = file.readAsStringSync();
  if (!text.contains('NSLocalNetworkUsageDescription')) {
    const insertion = '''
\t<key>NSLocalNetworkUsageDescription</key>
\t<string>Connect to TVs on your Wi-Fi network and use this phone as a remote.</string>
\t<key>NSAppTransportSecurity</key>
\t<dict>
\t\t<key>NSAllowsLocalNetworking</key>
\t\t<true/>
\t</dict>
''';
    final index = text.lastIndexOf('</dict>');
    if (index >= 0) {
      text = text.substring(0, index) + insertion + text.substring(index);
      file.writeAsStringSync(text);
    }
  }
}

void _patchAndroid(String root) {
  final file = File('$root/android/app/src/main/AndroidManifest.xml');
  if (!file.existsSync()) {
    return;
  }

  var text = file.readAsStringSync();

  if (!text.contains('android.permission.INTERNET')) {
    text = text.replaceFirst(
      '<manifest',
      '<manifest',
    );
    final end = text.indexOf('>');
    if (end >= 0) {
      text = '${text.substring(0, end + 1)}\n'
          '    <uses-permission android:name="android.permission.INTERNET" />'
          '${text.substring(end + 1)}';
    }
  }

  if (!text.contains('android:usesCleartextTraffic=')) {
    text = text.replaceFirst(
      '<application',
      '<application android:usesCleartextTraffic="true"',
    );
  }

  file.writeAsStringSync(text);
}
