import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return;
  }

  final host = _readOption(args, '--host') ?? '127.0.0.1';
  final port = int.tryParse(_readOption(args, '--port') ?? '8080');
  final rootPath = _readOption(args, '--root') ?? 'prefetched_feeds';

  if (port == null) {
    stderr.writeln('The --port option must be an integer.');
    exitCode = 64;
    return;
  }

  final server = await HttpServer.bind(host, port);
  stdout.writeln(
    'Serving prefetched feeds from $rootPath on http://$host:$port',
  );

  await for (final request in server) {
    await _handleRequest(request, rootPath);
  }
}

Future<void> _handleRequest(HttpRequest request, String rootPath) async {
  final response = request.response;

  if (request.uri.path == '/' || request.uri.path == '/health') {
    await _writeJson(response, {'ok': true, 'manifest': '/feeds/manifest'});
    return;
  }

  final file = _resolveFeedFile(rootPath, request.uri);
  if (file == null || !await file.exists()) {
    response.statusCode = HttpStatus.notFound;
    await _writeJson(response, {
      'error': 'Feed not found',
      'path': request.uri.path,
    });
    return;
  }

  response.headers.contentType = ContentType.json;
  await response.addStream(file.openRead());
  await response.close();
}

File? _resolveFeedFile(String rootPath, Uri uri) {
  final segments = uri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList();
  if (segments.isEmpty) {
    return null;
  }

  if (segments.length == 2 &&
      segments[0] == 'feeds' &&
      segments[1] == 'manifest') {
    return File(_joinPath(rootPath, ['manifest.json']));
  }

  if (segments.length == 2 &&
      segments[0] == 'feeds' &&
      segments[1] == 'search-index') {
    return File(_joinPath(rootPath, ['search', 'index.json']));
  }

  final page = uri.queryParameters['page'] ?? '1';

  if (segments.length == 2 && segments[0] == 'feeds') {
    final feedName = segments[1];
    if (feedName == 'latest' || feedName == 'trending') {
      return File(_joinPath(rootPath, [feedName, 'page-$page.json']));
    }
  }

  if (segments.length == 3 &&
      segments[0] == 'feeds' &&
      segments[1] == 'categories') {
    return File(
      _joinPath(rootPath, ['categories', segments[2], 'page-$page.json']),
    );
  }

  return null;
}

Future<void> _writeJson(
  HttpResponse response,
  Map<String, dynamic> payload,
) async {
  response.headers.contentType = ContentType.json;
  response.write(json.encode(payload));
  await response.close();
}

String? _readOption(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) {
    return null;
  }

  return args[index + 1];
}

String _joinPath(String root, List<String> segments) {
  final buffer = StringBuffer(root);
  for (final segment in segments) {
    buffer
      ..write(Platform.pathSeparator)
      ..write(segment);
  }
  return buffer.toString();
}

void _printUsage() {
  stdout.writeln('Usage: dart run tool/feed_server.dart [options]');
  stdout.writeln('');
  stdout.writeln('Options:');
  stdout.writeln('  --host <host>   Bind address (default: 127.0.0.1).');
  stdout.writeln('  --port <port>   Port number (default: 8080).');
  stdout.writeln(
    '  --root <dir>    Prefetched feed directory (default: prefetched_feeds).',
  );
  stdout.writeln('  --help          Show this message.');
}
