import 'analytics_runtime_web.dart'
    if (dart.library.io) 'analytics_runtime_stub.dart';

String analyticsRuntimeUserAgent() => readAnalyticsRuntimeUserAgent();
