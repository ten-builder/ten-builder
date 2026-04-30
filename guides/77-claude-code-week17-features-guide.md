# Claude Code Week 17 실전 가이드 — 커스텀 테마, 팀 온보딩, UI 개편 총정리

> 2026년 4월 20~24일(Week 17)에 배포된 Claude Code 업데이트를 실무에 적용하는 방법을 정리했어요.

## 이번 업데이트에서 바뀐 것

Week 17은 체감 변화가 큰 업데이트예요. 겉으로 보이는 UI부터 팀 협업 기능까지 여러 곳이 달라졌어요.

| 변경 사항 | 적용 범위 |
|-----------|----------|
| 커스텀 테마 생성 | 터미널 + 웹 |
| claude.ai/code UI 개편 | 웹 버전 |
| /team-onboarding 커맨드 추가 | 터미널 |
| OS CA 인증서 자동 신뢰 | 기업 환경 |
| 에이전트 팀 권한 대화상자 충돌 수정 | 에이전트 팀 |

---

## 커스텀 테마 설정하기

### 기본 사용법

```bash
# 테마 피커 열기
claude > /theme
```

테마 피커에서 기존 테마를 선택하거나 새 테마를 직접 만들 수 있어요.

### 새 테마 만들기

1. `/theme` 실행 후 "새 테마 만들기" 선택
2. 색상 팔레트 편집 화면에서 배경, 전경, 강조 색상 입력
3. 테마 이름 지정 후 저장

```json
{
  "name": "내 팀 테마",
  "background": "#1a1b26",
  "foreground": "#c0caf5",
  "accent": "#7aa2f7",
  "success": "#9ece6a",
  "warning": "#e0af68",
  "error": "#f7768e"
}
```

**팁:** 팀 전체가 동일한 테마를 쓰면 화면 공유나 페어 세션 때 서로 같은 시각적 맥락을 공유할 수 있어요.

### 테마 공유

저장된 테마 파일 위치:

```bash
~/.claude/themes/내-팀-테마.json
```

이 파일을 레포에 커밋하면 팀원 모두 동일한 테마를 사용할 수 있어요:

```bash
# 레포 루트에 .claude/themes/ 폴더 생성
mkdir -p .claude/themes
cp ~/.claude/themes/내-팀-테마.json .claude/themes/
```

---

## /team-onboarding 커맨드

새 팀원이 합류할 때 가장 번거로운 일이 코드베이스 파악이에요. 이번 업데이트로 추가된 `/team-onboarding` 커맨드가 이 과정을 단축시켜줘요.

### 동작 방식

Claude Code가 로컬 사용 이력을 분석해서 신규 팀원용 온보딩 가이드를 자동 생성해요.

```bash
# 팀 온보딩 가이드 생성
claude > /team-onboarding
```

생성되는 내용:

- 자주 수정되는 파일 목록
- 프로젝트에서 실제로 쓰인 명령어 패턴
- 반복적으로 해결된 이슈 유형
- 의존성 설치 및 실행 방법 요약

### 산출물 예시

```markdown
# [프로젝트명] 팀 온보딩 가이드

## 자주 수정되는 파일
- src/api/routes.ts — API 라우팅 정의
- src/db/migrations/ — 스키마 변경 내역
- .env.example — 환경변수 목록

## 핵심 명령어
- `pnpm dev` — 개발 서버 시작
- `pnpm test:watch` — 테스트 자동 실행
- `pnpm db:migrate` — 마이그레이션 적용

## 알아두면 좋은 패턴
- API 응답은 항상 ApiResponse<T> 래퍼 사용
- DB 쿼리는 repositories/ 아래 파일에서만 수행
```

### CLAUDE.md에 연결하기

생성된 가이드를 CLAUDE.md에 포함하면 다음 온보딩 때 Claude가 컨텍스트로 활용해요:

```bash
# CLAUDE.md에 온보딩 섹션 추가
cat >> CLAUDE.md << 'EOF'

## 팀 온보딩

신규 팀원은 `/team-onboarding` 커맨드로 프로젝트 개요를 빠르게 파악할 수 있어요.
EOF
```

---

## claude.ai/code UI 개편

웹 버전에서 접속하면 레이아웃이 달라진 걸 바로 느낄 수 있어요.

| 항목 | 이전 | 이후 |
|------|------|------|
| 세션 목록 | 드롭다운 | 왼쪽 사이드바 |
| 파일 첨부 | 텍스트 입력창 내부 | 드래그&드롭 지원 |
| 테마 | 단일 | 커스텀 테마 피커 |

### 세션 사이드바 활용법

세션 사이드바에서 이전 대화를 검색하고 빠르게 재개할 수 있어요.

```bash
# 특정 주제로 이전 세션 찾기 예시
검색: "인증 리팩토링"
→ 관련 세션 목록 표시
→ 클릭하면 맥락 포함해서 재개
```

### 파일 드래그&드롭

- 이미지: UI 스크린샷 첨부해서 "이 에러 메시지 뭔지 알아?" 같은 질문 가능
- 코드 파일: 여러 파일을 한 번에 끌어다 놓고 분석 요청

---

## 기업 환경 — OS CA 인증서 자동 신뢰

TLS 프록시를 쓰는 기업 네트워크에서 Claude Code가 연결 오류 없이 동작해요.

이전에는 별도로 인증서를 등록해야 했지만, 이번 업데이트부터는 OS 신뢰 저장소를 자동으로 참조해요.

```bash
# 별도 설정 필요 없음
# OS 수준에서 인증된 인증서는 Claude Code에서도 자동 신뢰

# 확인 방법 (macOS)
security find-certificate -a -c "회사CA명" ~/Library/Keychains/login.keychain-db
```

만약 여전히 연결 오류가 발생한다면:

```bash
# 수동 인증서 경로 지정 (fallback)
export NODE_EXTRA_CA_CERTS="/path/to/company-ca.crt"
```

---

## 에이전트 팀 권한 대화상자 수정

에이전트 팀 실행 중 팀원 에이전트가 도구 권한을 요청할 때 대화상자가 충돌하던 버그가 수정됐어요.

이전에는:

```
에이전트 A: 파일 쓰기 권한 요청
→ 권한 대화상자 표시
→ 충돌 발생 (v2.1.114 이전)
```

v2.1.114 이후:

```bash
# 안정적으로 권한 확인 가능
에이전트 A: 파일 쓰기 권한 요청
→ 대화상자 정상 표시
→ Allow / Deny 선택
→ 이후 동일 에이전트에서는 기억됨
```

---

## 업그레이드 방법

```bash
# npm 전역 설치인 경우
npm update -g @anthropic-ai/claude-code

# 버전 확인
claude --version
# v2.1.114 이상이어야 Week 17 기능 사용 가능
```

---

## 체크리스트

- [ ] `claude --version` 확인 → v2.1.114 이상
- [ ] `/theme` 실행해서 팀 테마 설정
- [ ] `/team-onboarding` 실행해서 온보딩 가이드 생성
- [ ] CLAUDE.md에 팀 온보딩 섹션 추가
- [ ] 웹 버전(`claude.ai/code`) 새 UI 확인
- [ ] 기업 환경이라면 CA 인증서 자동 신뢰 여부 확인

---

## 다음 단계

- [에이전트 팀 심화 가이드](./71-claude-code-agent-teams-ga-guide.md)
- [컨텍스트 엔지니어링](./63-context-engineering-2026.md)
- [Cursor IDE와 병행 사용하기](./73-cursor-ide-practical-guide-2026.md)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
