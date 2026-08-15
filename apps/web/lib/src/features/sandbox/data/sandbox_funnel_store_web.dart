import 'package:web/web.dart' as web;

import 'sandbox_funnel_store.dart';

final class _WebSandboxFunnelStore extends SandboxFunnelStore {
  final _memoryFallback = <String>{};

  @override
  bool claimStorageKey(String key) {
    if (!_memoryFallback.add(key)) return false;
    try {
      if (web.window.sessionStorage.getItem(key) == '1') return false;
      web.window.sessionStorage.setItem(key, '1');
    } on Object {
      // Storage denial keeps an in-memory claim for the mounted app session.
    }
    return true;
  }
}

SandboxFunnelStore createSandboxFunnelStore() => _WebSandboxFunnelStore();
