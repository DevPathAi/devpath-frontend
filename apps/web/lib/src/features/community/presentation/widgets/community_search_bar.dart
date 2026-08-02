import 'dart:async';

import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';

/// 커뮤니티 글 검색 입력. 입력이 멎으면(400ms) [onChangedDebounced] 를 호출한다.
/// 명령 팔레트(Ctrl+K)는 화면 이동용이라 이 위젯과 역할이 다르다.
class CommunitySearchBar extends StatefulWidget {
  const CommunitySearchBar({
    super.key,
    required this.onChangedDebounced,
    this.initialQuery = '',
  });

  final ValueChanged<String> onChangedDebounced;
  final String initialQuery;

  @override
  State<CommunitySearchBar> createState() => _CommunitySearchBarState();
}

class _CommunitySearchBarState extends State<CommunitySearchBar> {
  static const _debounceDelay = Duration(milliseconds: 400);

  late final TextEditingController _controller = TextEditingController(
    text: widget.initialQuery,
  );
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    // suffix(지우기) 노출이 입력 유무에 반응해야 하므로 리빌드가 필요하다.
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(
      _debounceDelay,
      () => widget.onChangedDebounced(value.trim()),
    );
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    setState(() {});
    // 지우기는 사용자의 명시적 행동이라 디바운스 없이 즉시 반영한다.
    widget.onChangedDebounced('');
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey('community-search-field'),
      controller: _controller,
      onChanged: _onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: '글 검색 (제목·본문·태그)',
        prefixIcon: const Icon(DpIcons.search, size: 20),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                key: const ValueKey('community-search-clear'),
                icon: const Icon(Icons.close, size: 18),
                tooltip: '검색어 지우기',
                onPressed: _clear,
              ),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}
