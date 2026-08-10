import 'package:flutter/material.dart';

import 'adsense_unit_view_stub.dart'
    if (dart.library.js_interop) 'adsense_unit_view_web.dart'
    as impl;

/// web 구현이 반환하는 핸들. stub도 동일 인터페이스를 만족한다.
abstract class AdSenseHandle {
  Widget get view;
  void dispose();
}

/// 애드센스 광고 단위. web=`<ins class="adsbygoogle">` 임베드, 그 외(테스트 포함)=stub.
///
/// 높이 0으로 시작해, 광고가 채워졌다는 신호를 받은 뒤에만 확장한다.
/// 채워지지 않으면(심사 대기·미매칭·애드블록·스크립트 차단·타임아웃) 접은 채로 둔다.
///
/// viewType은 **State에서 1회**(initState) 생성한다. 함수형 build에서 매 rebuild마다
/// 만들면 viewFactory가 무한 증식한다(Monaco에 기록된 함정).
class AdSenseUnitView extends StatefulWidget {
  const AdSenseUnitView({super.key, required this.slotId});
  final String slotId;

  @override
  State<AdSenseUnitView> createState() => _AdSenseUnitViewState();
}

class _AdSenseUnitViewState extends State<AdSenseUnitView> {
  late final AdSenseHandle _handle;
  double _height = 0;

  @override
  void initState() {
    super.initState();
    _handle = impl.createAdSenseHandle(
      slotId: widget.slotId,
      onResolved: (status, height) {
        if (!mounted) return;
        setState(() => _height = status == 'filled' ? height : 0);
      },
    );
  }

  @override
  void dispose() {
    _handle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: _height, child: _handle.view);
  }
}
