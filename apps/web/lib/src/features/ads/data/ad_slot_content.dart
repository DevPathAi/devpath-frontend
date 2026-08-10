import 'ad_view.dart';

/// 슬롯이 그릴 내용. 백엔드 GET /ads 봉투(`{"type":…}`)에 대응한다.
sealed class AdSlotContent {
  const AdSlotContent();
}

/// 하우스/스폰서 광고 1건. 노출·클릭 측정 대상이다.
class HouseAd extends AdSlotContent {
  const HouseAd(this.ad);
  final AdView ad;
}

/// 애드센스 광고 단위. **자체 측정을 붙이지 않는다**(구글 정책).
class AdsenseUnit extends AdSlotContent {
  const AdsenseUnit(this.adsenseSlotId);
  final String adsenseSlotId;
}

/// 봉투를 파싱한다. 모르는 `type`이나 필수 필드 누락은 null(전방 호환 + fail-silent).
AdSlotContent? adSlotContentFromJson(Map<String, dynamic> json) {
  switch (json['type']) {
    case 'HOUSE':
      final ad = json['ad'];
      if (ad is! Map) return null;
      try {
        return HouseAd(AdView.fromJson(ad.cast<String, dynamic>()));
      } catch (_) {
        return null;
      }
    case 'ADSENSE':
      final id = json['adsenseSlotId'];
      if (id is! String || id.isEmpty) return null;
      return AdsenseUnit(id);
    default:
      return null;
  }
}
