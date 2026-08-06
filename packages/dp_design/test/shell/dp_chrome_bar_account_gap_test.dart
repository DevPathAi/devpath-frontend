import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 리뷰 발견 1 red-repro: account가 있을 때 액션그룹과 account 사이에
/// 실제로 렌더되는 SizedBox(width: DpSpacing.sm) 8px이 폭 예산(budget/fits/
/// inline) 계산에서 누락돼 있었다. 경계 폭에서는 "오버플로 없음"으로
/// 계산해 놓고 실제 콘텐츠가 상한(actionCap = 바 폭 / 2)을 넘겨 RenderFlex
/// overflow가 난다.
///
/// 재현 조건(인위적 라벨·crumbs 조정이 아니라 실제 산술 경계):
/// perAction=48, overflowButton=48, account 히트 영역=48
/// (`IconButton` — 실제 앱 `_AccountMenu`와 동등. 맨 `Icon`(24px)을 쓰면
/// 실제 콘텐츠가 예산의 가정보다 작아져 버그가 가려진다 — 최초 시도에서
/// 직접 확인), account 간격(sm)=8.
///
/// 액션 2개 + account 있음 — 실제 콘텐츠 폭의 두 가지 경우만 있다
/// (overflowButton도 perAction과 같은 48이라 "일부만 접기"는 "전부 접기"와
/// 폭이 같다):
///   - 오버플로 없음(2개 인라인): 2*48 + 8(간격) + 48(계정) = 152
///   - 전부 접힘(0개 인라인 + 더보기 버튼): 48 + 8(간격) + 48(계정) = 104
///
/// 버그 있는 예산 계산은 accountWidth로 48만 빼(간격 8 누락) budget=
/// actionCap-48을 쓴다. actionCap이 [144, 152) 구간이면
/// fits=floor((actionCap-48)/48)=2>=2(액션 수)로 "오버플로 없음"이라 오판해
/// 2개를 그대로 인라인 렌더한다 — 그런데 실제로는 152px이 필요해 최대
/// 8px 오버플로한다. 수정된 계산(accountReserve=48+8=56)은 같은 폭에서
/// budget=actionCap-56, fits<2가 나와 올바르게 전부 접기(104px, 상한 안에
/// 여유 있게 들어감)를 선택한다.
///
/// actionCap = barWidth/2, barWidth = physicalWidth - 2*DpSpacing.lg(16) =
/// physicalWidth - 32. actionCap을 148(144~152 구간 안)로 맞추려면
/// barWidth = 296, physicalWidth = 296 + 32 = 328.
void main() {
  testWidgets('account 간격(8px)이 폭 예산에 반영되지 않으면 경계 폭에서 오버플로한다', (tester) async {
    tester.view.physicalSize = const Size(328, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: Scaffold(
          body: DpChromeBar(
            breadcrumb: const [
              (label: '커뮤니티', path: null),
              (label: '게시판', path: '/community'),
            ],
            actions: [
              DpChromeAction(
                icon: Icons.star,
                label: '액션 0',
                onPressed: (_) {},
              ),
              DpChromeAction(
                icon: Icons.star,
                label: '액션 1',
                onPressed: (_) {},
              ),
            ],
            // 실제 앱의 account 슬롯(_AccountMenu, MenuAnchor+IconButton)과
            // 동등한 48px 히트 영역을 갖는 위젯을 쓴다 — 예산 계산이 가정하는
            // 실제 크기와 맞춰야 이 경계 산술이 재현된다.
            account: IconButton(
              icon: const Icon(Icons.person),
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
