import 'sandbox_session_store.dart';

final _sharedStore = MemorySandboxSessionStore();

SandboxSessionStore createSandboxSessionStore() => _sharedStore;
