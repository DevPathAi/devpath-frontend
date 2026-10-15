import 'session_hint.dart';

/// VM(테스트) 구현 — 컨테이너마다 새 메모리 저장소라 테스트끼리 힌트가 새지 않는다.
SessionHintStore createSessionHintStore() => MemorySessionHintStore();
