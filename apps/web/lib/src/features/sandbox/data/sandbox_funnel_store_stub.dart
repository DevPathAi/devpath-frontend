import 'sandbox_funnel_store.dart';

final _sharedStore = MemorySandboxFunnelStore();

SandboxFunnelStore createSandboxFunnelStore() => _sharedStore;
