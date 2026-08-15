import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:test/test.dart';

class _SandboxAdapter implements HttpClientAdapter {
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future? cancelFuture,
  ) async {
    lastRequest = options;
    if (options.method == 'GET') {
      return ResponseBody.fromString(
        jsonEncode({
          'sessionId': 91,
          'language': 'PYTHON',
          'contentId': 12,
          'codeBlockId': null,
          'stdout': 'ok\n',
          'stderr': '',
          'exitCode': 0,
          'status': 'COMPLETED',
          'truncated': true,
          'startedAt': '2026-08-16T00:00:00Z',
          'finishedAt': '2026-08-16T00:00:01Z',
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody(
      Stream.value(
        Uint8List.fromList(
          utf8.encode(
            'event: log\ndata: compiling\n\n'
            'event: result\n'
            'data: {"sessionId":91,"status":"COMPLETED",'
            '"exitCode":0,"truncated":false}\n\n',
          ),
        ),
      ),
      200,
      headers: {
        Headers.contentTypeHeader: ['text/event-stream'],
        'x-sandbox-session-id': ['91'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('v2 run은 early header를 session event로 먼저 내고 context ID를 보낸다', () async {
    final adapter = _SandboxAdapter();
    final client = ApiClient.create(
      const ApiConfig(baseUrl: 'https://mock/api/v1'),
    )..dio.httpClientAdapter = adapter;
    final api = SandboxApi(client);

    final events = await api
        .run(
          SandboxRunRequest(
            code: 'print("ok")',
            language: SandboxLanguage.python,
            contentId: 12,
          ),
        )
        .toList();

    expect(events.map((event) => event.event), ['session', 'log', 'result']);
    expect(events.first.data, '91');
    expect(adapter.lastRequest!.headers['X-Sandbox-Event-Version'], '2');
    expect((adapter.lastRequest!.data as Map).cast<String, Object?>(), {
      'code': 'print("ok")',
      'language': 'PYTHON',
      'contentId': 12,
      'codeBlockId': null,
    });
  });

  test('owner recovery는 terminal status와 truncation을 보존한다', () async {
    final adapter = _SandboxAdapter();
    final client = ApiClient.create(
      const ApiConfig(baseUrl: 'https://mock/api/v1'),
    )..dio.httpClientAdapter = adapter;

    final session = await SandboxApi(client).session(91);

    expect(session.sessionId, 91);
    expect(session.status, SandboxSessionStatus.completed);
    expect(session.truncated, isTrue);
    expect(session.contentId, 12);
    expect(session.codeBlockId, isNull);
    expect(adapter.lastRequest!.path, '/sandbox/sessions/91');
  });

  test('owner recovery request도 positive JS-safe session ID만 허용한다', () {
    final api = SandboxApi(ApiClient(Dio()));

    for (final id in [0, -1, 9007199254740992]) {
      expect(() => api.session(id), throwsArgumentError);
    }
  });

  test('result event는 네 terminal을 구분하고 delivery outcome을 받지 않는다', () {
    for (final entry in <String, SandboxSessionStatus>{
      'COMPLETED': SandboxSessionStatus.completed,
      'FAILED': SandboxSessionStatus.failed,
      'KILLED': SandboxSessionStatus.killed,
      'TIMED_OUT': SandboxSessionStatus.timedOut,
    }.entries) {
      final result = SandboxTerminalResult.fromJson({
        'sessionId': 7,
        'status': entry.key,
        'exitCode': entry.key == 'COMPLETED' ? 0 : 1,
        'truncated': false,
      });
      expect(result.status, entry.value);
    }

    expect(
      () => SandboxTerminalResult.fromJson({
        'sessionId': 7,
        'status': 'UNAVAILABLE',
        'exitCode': null,
        'truncated': false,
      }),
      throwsFormatException,
    );
  });

  test(
    'runtime language wire alias와 generic starter는 JAVA/NODE/PYTHON이 일치한다',
    () {
      expect(SandboxLanguage.fromWire('java'), SandboxLanguage.java);
      expect(SandboxLanguage.fromWire('javascript'), SandboxLanguage.node);
      expect(SandboxLanguage.fromWire('py'), SandboxLanguage.python);
      expect(
        SandboxLanguage.java.genericStarter,
        contains('public class Main'),
      );
      expect(SandboxLanguage.node.genericStarter, contains('console.log'));
      expect(SandboxLanguage.python.genericStarter, contains('print('));
      expect(
        SandboxLanguage.java.genericStarter,
        isNot(contains('void main()')),
      );
    },
  );

  test('ALLOCATING/RUNNING recovery의 nullable output은 빈 transcript로 정상화한다', () {
    for (final status in ['ALLOCATING', 'RUNNING']) {
      final session = SandboxSession.fromJson({
        'sessionId': 91,
        'language': 'JAVA',
        'contentId': 12,
        'codeBlockId': null,
        'stdout': null,
        'stderr': null,
        'exitCode': null,
        'status': status,
        'truncated': false,
        'startedAt': '2026-08-16T00:00:00Z',
        'finishedAt': null,
      });
      expect(session.stdout, '');
      expect(session.stderr, '');
      expect(session.status.isTerminal, isFalse);
    }
  });

  test('run request는 release에서도 code와 JS-safe positive IDs를 검증한다', () {
    expect(
      () => SandboxRunRequest(code: '   ', language: SandboxLanguage.java),
      throwsArgumentError,
    );
    expect(
      () => SandboxRunRequest(
        code: List.filled(64 * 1024 + 1, 'a').join(),
        language: SandboxLanguage.java,
      ),
      throwsArgumentError,
    );
    for (final id in [0, -1, 9007199254740992]) {
      expect(
        () => SandboxRunRequest(
          code: 'ok',
          language: SandboxLanguage.java,
          contentId: id,
        ),
        throwsArgumentError,
      );
      expect(
        () => SandboxRunRequest(
          code: 'ok',
          language: SandboxLanguage.java,
          codeBlockId: id,
        ),
        throwsArgumentError,
      );
    }
  });

  test('response IDs도 positive JS-safe 범위를 벗어나면 fail closed 한다', () {
    expect(
      () => SandboxTerminalResult.fromJson({
        'sessionId': 9007199254740992,
        'status': 'COMPLETED',
        'exitCode': 0,
        'truncated': false,
      }),
      throwsFormatException,
    );

    Map<String, Object?> session({
      Object? sessionId = 91,
      Object? contentId = 12,
      Object? codeBlockId,
    }) => {
      'sessionId': sessionId,
      'language': 'JAVA',
      'contentId': contentId,
      'codeBlockId': codeBlockId,
      'stdout': '',
      'stderr': '',
      'exitCode': 0,
      'status': 'COMPLETED',
      'truncated': false,
      'startedAt': '2026-08-16T00:00:00Z',
      'finishedAt': '2026-08-16T00:00:01Z',
    };

    for (final malformed in [
      session(sessionId: 9007199254740992),
      session(contentId: 9007199254740992),
      session(codeBlockId: 9007199254740992),
    ]) {
      expect(() => SandboxSession.fromJson(malformed), throwsFormatException);
    }
  });

  test('session status와 finishedAt 불변식 및 RFC3339 overflow를 거부한다', () {
    Map<String, Object?> session({
      String status = 'COMPLETED',
      Object? finishedAt = '2026-08-16T00:00:01Z',
      Object? startedAt = '2026-08-16T00:00:00Z',
    }) => {
      'sessionId': 91,
      'language': 'JAVA',
      'contentId': 12,
      'codeBlockId': null,
      'stdout': '',
      'stderr': '',
      'exitCode': status == 'COMPLETED' ? 0 : null,
      'status': status,
      'truncated': false,
      'startedAt': startedAt,
      'finishedAt': finishedAt,
      // Additive response fields remain forwards-compatible.
      'futureField': {'version': 3},
    };

    expect(
      () => SandboxSession.fromJson(
        session(status: 'RUNNING', finishedAt: '2026-08-16T00:00:01Z'),
      ),
      throwsFormatException,
    );
    expect(
      () => SandboxSession.fromJson(
        session(status: 'COMPLETED', finishedAt: null),
      ),
      throwsFormatException,
    );
    expect(
      () => SandboxSession.fromJson(session(startedAt: '2026-13-40T25:61:61Z')),
      throwsFormatException,
    );

    expect(SandboxSession.fromJson(session()).status.isTerminal, isTrue);
  });
}
