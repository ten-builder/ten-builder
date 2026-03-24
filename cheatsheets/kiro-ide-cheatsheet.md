# Kiro IDE 치트시트

> AWS가 만든 스펙 기반 에이전틱 IDE — 한 페이지 요약

## 설치

| 방법 | 내용 |
|------|------|
| macOS | [kiro.dev/downloads](https://kiro.dev/downloads/) → `.dmg` 다운로드 |
| Windows | [kiro.dev/downloads](https://kiro.dev/downloads/) → `.exe` 인스톨러 |
| Linux | [kiro.dev/downloads](https://kiro.dev/downloads/) → `.AppImage` 또는 `.deb` |

```bash
# macOS: 다운로드 후 Applications 폴더로 이동
# 첫 실행 시 로그인 필요 (Google, GitHub, AWS 계정)
```

## 핵심 특징

| 기능 | 설명 |
|------|------|
| 스펙 기반 코딩 | 요구사항 → 설계 → 태스크로 구조화된 개발 |
| VS Code 기반 | VS Code 익스텐션 호환, 익숙한 인터페이스 |
| 에이전트 훅 | 파일 저장, 도구 사용 등 이벤트 기반 자동화 |
| 스티어링 파일 | 프로젝트별 규칙을 `.kiro/steering/` 에 정의 |
| MCP 서버 지원 | Model Context Protocol로 외부 도구 연결 |
| 듀얼 모드 | Vibe 코딩(빠른 탐색) + Spec 코딩(체계적 개발) |
| Autonomous Agent | 장시간 태스크를 백그라운드로 실행 |
| 지원 언어 | TypeScript, JavaScript, Java, Python |

## Vibe vs Spec — 언제 뭘 쓰나

| 상황 | 모드 | 이유 |
|------|------|------|
| 프로토타이핑, 탐색 | Vibe | 빠르게 실험하고 방향 잡기 |
| 복잡한 기능 개발 | Spec | 요구사항 정리 → 설계 → 구현 추적 |
| 버그 수정 | Spec (Bugfix) | 근본 원인 분석 → 회귀 방지 |
| 간단한 수정 | Vibe | 오버헤드 없이 바로 작업 |
| 팀 협업 기능 | Spec | 설계 문서가 자동으로 남음 |

## Spec 워크플로우 (3단계)

### 1단계: 요구사항 (requirements.md)

```markdown
# 사용자 스토리
- 사용자로서 로그인 페이지에서 이메일로 가입할 수 있다
  - 수락 기준: 이메일 형식 검증
  - 수락 기준: 중복 이메일 체크
  - 수락 기준: 인증 메일 발송
```

### 2단계: 설계 (design.md)

```markdown
# 기술 아키텍처
- 시퀀스 다이어그램
- 컴포넌트 설계
- 에러 핸들링 전략
- 테스트 접근법
```

### 3단계: 태스크 (tasks.md)

```markdown
# 구현 태스크
- [ ] 이메일 입력 컴포넌트 생성
- [ ] 이메일 검증 유틸 구현
- [ ] 회원가입 API 엔드포인트
- [x] 인증 메일 템플릿 (완료)
```

> Spec을 만들면 이 3개 파일이 `.kiro/specs/{spec-name}/` 디렉토리에 자동 생성된다.
> 태스크는 개별 실행 또는 일괄 실행 가능하고, 실시간 진행 상태가 표시된다.

## 에이전트 훅 (Agent Hooks)

IDE 이벤트에 반응하는 자동화 트리거. `.kiro/hooks/` 디렉토리에 저장된다.

### 이벤트 타입

| 이벤트 | 트리거 시점 |
|--------|------------|
| File Save | 파일 저장 시 |
| File Create | 새 파일 생성 시 |
| File Delete | 파일 삭제 시 |
| Pre Tool Use | 도구 실행 전 |
| Post Tool Use | 도구 실행 후 |
| Pre Task Execution | Spec 태스크 실행 전 |
| Post Task Execution | Spec 태스크 실행 후 |
| Manual | 수동 실행 |

### 액션 타입

| 액션 | 설명 |
|------|------|
| Ask Kiro | 에이전트에게 프롬프트 전달 |
| Run Command | 셸 명령어 실행 |

### 실전 훅 예시

```
이벤트: File Save
파일 패턴: **/*.ts
액션: Ask Kiro
프롬프트: "저장된 파일의 타입 에러를 확인하고, 있으면 수정 제안해주세요"
```

```
이벤트: Post Tool Use
도구: file_write
액션: Run Command
명령어: npx eslint --fix ${file}
```

> 훅 생성 방법: Kiro 패널 → Agent Hooks → `+` → 직접 작성 또는 자연어로 설명

## 스티어링 파일 (Steering)

프로젝트별 규칙을 정의하는 파일. `.kiro/steering/` 디렉토리에 `.md` 형식으로 저장한다.

```markdown
# .kiro/steering/coding-standards.md

## 코딩 규칙
- TypeScript strict 모드 사용
- 모든 함수에 JSDoc 작성
- 에러는 커스텀 Error 클래스로 처리

## 테스트 규칙  
- 모든 유틸 함수에 단위 테스트 필수
- 테스트 파일명: *.test.ts
```

> Claude Code의 `CLAUDE.md`와 비슷한 역할. 차이점: 여러 파일로 분리 가능하고, 특정 파일 패턴에만 적용 가능.

## MCP 서버 연결

```json
// .kiro/settings/mcp.json
{
  "mcpServers": {
    "postgres": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-postgres", "postgresql://localhost/mydb"]
    },
    "github": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_TOKEN": "${GITHUB_TOKEN}"
      }
    }
  }
}
```

## 주요 단축키

| 동작 | macOS | Windows/Linux |
|------|-------|---------------|
| Kiro 채팅 열기 | `Cmd + Shift + P` → "Kiro" | `Ctrl + Shift + P` → "Kiro" |
| 새 Spec 생성 | Kiro 패널 → Specs → `+` | 동일 |
| 훅 생성 | Kiro 패널 → Agent Hooks → `+` | 동일 |
| 인라인 편집 | 코드 선택 → `Cmd + I` | 코드 선택 → `Ctrl + I` |

## 가격 (2026년 3월 기준)

| 플랜 | 가격 | 포함 내용 |
|------|------|----------|
| Free | $0/월 | 월 50회 에이전트 상호작용 |
| Pro | $19/월 | 무제한 에이전트 상호작용 |
| Pro+ | $39/월 | 우선 처리 + 더 많은 자율 실행 |

> 자세한 가격 정보: [kiro.dev/pricing](https://kiro.dev/pricing/)

## 다른 도구와 비교

| 항목 | Kiro | Cursor | Claude Code |
|------|------|--------|-------------|
| 형태 | 데스크톱 IDE | 데스크톱 IDE | 터미널 CLI |
| 기반 | VS Code | VS Code | 독립 실행 |
| 차별점 | Spec 기반 체계적 개발 | 빠른 자동완성 + Tab | 모델 품질 + 자율 실행 |
| 자동화 | Agent Hooks | Rules + Custom | Hooks + MCP |
| 프로젝트 규칙 | Steering 파일 | `.cursorrules` | `CLAUDE.md` |
| 적합한 상황 | 복잡한 기능, 팀 프로젝트 | 빠른 코딩, 개인 개발 | 대규모 리팩토링, 자동화 |
| MCP | 지원 | 지원 | 지원 |

## 시작 팁

1. **처음엔 Vibe 모드로** — 작은 작업부터 Kiro의 에이전트 응답을 파악
2. **중요 기능은 Spec으로** — 요구사항 → 설계 → 태스크 3단계를 직접 경험
3. **스티어링 파일 먼저 설정** — 팀/프로젝트 코딩 규칙을 `.kiro/steering/`에 작성
4. **훅은 점진적으로** — 파일 저장 시 린트 체크부터 시작, 필요에 따라 확장
5. **기존 VS Code 익스텐션 활용** — 대부분의 VS Code 익스텐션이 호환됨

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
