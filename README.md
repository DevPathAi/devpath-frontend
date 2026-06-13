# devpath-frontend

**DevPath AI** 프론트엔드 모노레포입니다. 사용자 웹 / 관리자 웹 / 모바일 앱을 한 레포에서 관리합니다.

## 구조

```
devpath-frontend/
├── web/        # 사용자 React SPA (Vite + TS)
├── admin/      # 관리자 React SPA (콘텐츠·FinOps)
└── mobile/     # Flutter 앱 (모바일 대시·퀵 캡처)
```

| 영역 | 스택 |
|------|------|
| web | React 18+ · TypeScript · Vite · (예정: Zustand, TanStack Query, Monaco Editor) |
| admin | React 18+ · TypeScript · Vite |
| mobile | Flutter 3.x · Dart · (예정: Riverpod, go_router, dio) |

## 실행

### web / admin

```bash
cd web        # 또는 admin
npm install
npm run dev
```

### mobile

```bash
cd mobile
flutter pub get
flutter run
```

## 환경 변수

API 엔드포인트·키 등은 `.env`로 주입하며 **절대 커밋하지 않습니다**. 예시는 각 앱의 `.env.example`을 따릅니다 ([documents/10_환경_설정_템플릿](https://github.com/DevPathAi/documents/blob/main/10_환경_설정_템플릿.md)).

## 개발 규칙

- 화면 설계: [documents/06_화면_기능_정의서](https://github.com/DevPathAi/documents/blob/main/06_화면_기능_정의서.md) · [storyboard](https://github.com/DevPathAi/storyboard)
- Git 규칙: [documents/09_Git_규칙_정의서](https://github.com/DevPathAi/documents/blob/main/09_Git_규칙_정의서.md)
- 워크플로우 현황: [workflow-dashboard](https://devpathai.github.io/workflow-dashboard/)
