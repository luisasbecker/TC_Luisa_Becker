import 'dart:async';
import 'dart:convert';
import 'dart:io';

class CloudFailure implements Exception {
  const CloudFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract class CloudTransport {
  Future<Map<String, dynamic>> call(
    String operation,
    Map<String, Object?> data,
  );
}

class CloudApi implements CloudTransport {
  CloudApi(this.endpoint);
  final String endpoint;

  @override
  Future<Map<String, dynamic>> call(
    String operation,
    Map<String, Object?> data,
  ) async {
    final base = Uri.tryParse(endpoint);
    if (base == null ||
        base.scheme != 'https' ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment) {
      throw const CloudFailure(
        'O serviço cloud ainda não foi configurado nesta versão.',
      );
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      return await (() async {
        final request = await client.postUrl(base.resolve('/v1/$operation'));
        request.followRedirects = false;
        request.headers.contentType = ContentType.json;
        request.add(utf8.encode(jsonEncode(data)));
        final response = await request.close();
        final bytes = <int>[];
        await for (final chunk in response) {
          bytes.addAll(chunk);
          if (bytes.length > 20 * 1024 * 1024) {
            throw const CloudFailure(
              'A resposta da cloud excedeu o limite. Tente novamente.',
            );
          }
        }
        if (response.statusCode != 200) {
          throw CloudFailure(
            response.statusCode == 413
                ? 'A imagem ficou muito grande. Selecione uma imagem menor.'
                : 'A cloud não concluiu esta etapa. Sua sessão foi mantida; tente novamente.',
          );
        }
        final decoded = jsonDecode(utf8.decode(bytes));
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Resposta inválida');
        }
        return decoded;
      })().timeout(const Duration(seconds: 60));
    } on CloudFailure {
      rethrow;
    } on TimeoutException {
      throw const CloudFailure(
        'A cloud demorou para responder. Sua sessão foi mantida; tente novamente.',
      );
    } on SocketException {
      throw const CloudFailure(
        'Não foi possível conectar à cloud. Confira a internet e tente novamente.',
      );
    } on HandshakeException {
      throw const CloudFailure(
        'Não foi possível estabelecer uma conexão segura com a cloud.',
      );
    } on FormatException {
      throw const CloudFailure(
        'A cloud devolveu uma resposta inválida. Tente novamente.',
      );
    } finally {
      client.close(force: true);
    }
  }
}
