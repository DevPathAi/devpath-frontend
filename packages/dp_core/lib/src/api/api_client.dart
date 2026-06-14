import 'package:dio/dio.dart';

import '../error/api_exception.dart';
import '../sse/sse_client.dart';
import '../sse/sse_event.dart';
import 'api_config.dart';

/// dio 래퍼. 모든 응답 에러를 [ApiException]으로 정규화한다.
class ApiClient {
  ApiClient(this.dio);

  final Dio dio;

  factory ApiClient.create(
    ApiConfig config, {
    List<Interceptor> interceptors = const [],
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: config.baseUrl,
        connectTimeout: config.connectTimeout,
        receiveTimeout: config.receiveTimeout,
        headers: {Headers.acceptHeader: Headers.jsonContentType},
      ),
    );
    dio.interceptors.addAll(interceptors);
    // 에러 정규화는 가장 바깥(마지막)에 둔다.
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (e, handler) => handler.reject(
          DioException(
            requestOptions: e.requestOptions,
            error: ApiException.fromDio(e),
            response: e.response,
            type: e.type,
          ),
        ),
      ),
    );
    return ApiClient(dio);
  }

  /// GET 후 JSON map 반환. 실패 시 [ApiException] throw.
  Future<T> get<T>(String path, {Map<String, dynamic>? query}) async {
    try {
      final res = await dio.get<T>(path, queryParameters: query);
      return res.data as T;
    } on DioException catch (e) {
      throw (e.error is ApiException)
          ? e.error as ApiException
          : ApiException.fromDio(e);
    }
  }

  /// SSE 스트림 연결(D1). 앱은 dio를 직접 만지지 않고 이 헬퍼만 사용.
  /// 실패는 SseClient.connect 규약대로 [ApiException]으로 정규화된다.
  /// feature의 `*ConnectProvider`는 `apiClient.sse(path, body: ...)`를 호출한다.
  Stream<SseEvent> sse(String path, {Object? body}) =>
      SseClient(dio).connect(path, body: body);
}
