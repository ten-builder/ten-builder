# Windsurf 치트시트

> Windsurf(구 Codeium) AI IDE 핵심 기능과 Cascade 에이전트 활용법 — 한 페이지 요약

## Cascade 에이전트 핵심 단축키

| 단축키 (macOS / Windows) | 기능 |
|--------------------------|------|
| `Cmd+L` / `Ctrl+L` | Cascade 채팅 열기 |
| `Cmd+I` / `Ctrl+I` | 인라인 편집 (선택 영역) |
| `Cmd+Shift+L` / `Ctrl+Shift+L` | 새 Cascade 세션 시작 |
| `Cmd+Enter` | 멀티라인 프롬프트 전송 |
| `Tab` | Supercomplete 자동완성 수락 |
| `Esc` | 자동완성 제안 무시 |
| `Cmd+.` / `Ctrl+.` | 인라인 제안 수락/거절 토글 |

## Cascade 모드 비교

| 모드 | 용도 | 특징 |
|------|------|------|
| **Write** | 새 코드 생성 | 파일 생성, 멀티파일 편집, 터미널 명령 실행 |
| **Chat** | 질문/분석 | 코드 수정 없이 설명만 제공 |
| **Edit** | 인라인 수정 | 선택한 코드 블록만 수정 |

## 프로젝트 인덱싱 활용

Windsurf는 프로젝트 전체를 자동 인덱싱해서 컨텍스트를 파악해요.

```
# .windsurfrules 파일로 프로젝트 컨텍스트 설정
# 프로젝트 루트에 생성

이 프로젝트는 Next.js 14 + TypeScript 기반이에요.
- src/app/ 디렉토리는 App Router를 사용해요
- Tailwind CSS로 스타일링해요
- Supabase를 백엔드로 사용해요
```

| 설정 | 위치 | 설명 |
|------|------|------|
| `.windsurfrules` | 프로젝트 루트 | 프로젝트별 AI 행동 규칙 |
| Global Rules | Settings → Cascade | 전역 AI 규칙 설정 |
| Memory | 자동 | 이전 대화 컨텍스트 자동 기억 |

## 효과적인 Cascade 프롬프트 패턴

### 멀티파일 수정 요청

```
src/components/에 있는 모든 Button 컴포넌트를
새로운 디자인 시스템에 맞게 업데이트해줘.
- variant prop 추가 (primary, secondary, ghost)
- Tailwind 클래스 사용
- 기존 테스트도 같이 수정
```

### 프로젝트 구조 분석

```
이 프로젝트의 폴더 구조를 분석하고
개선할 점을 알려줘. 수정하지 말고 분석만.
```

### 디버깅

```
이 에러를 분석해줘:
[에러 메시지 붙여넣기]

관련 파일을 찾아서 원인과 해결 방법을 알려줘.
```

## Supercomplete vs 일반 자동완성

| 기능 | Supercomplete | 일반 자동완성 |
|------|---------------|--------------|
| 범위 | 여러 줄 예측 | 현재 줄만 |
| 컨텍스트 | 프로젝트 전체 분석 | 현재 파일 위주 |
| 동작 | 다음 행동 예측 | 타이핑 기반 제안 |
| 수락 | `Tab` | `Tab` |

## Windsurf vs Cursor vs Copilot 비교

| 항목 | Windsurf | Cursor | GitHub Copilot |
|------|----------|--------|----------------|
| 기반 | VS Code 포크 | VS Code 포크 | VS Code 확장 |
| 에이전트 | Cascade | Composer | Workspace Agent |
| 인덱싱 | 자동 전체 인덱싱 | 코드베이스 인덱싱 | 레포 인덱싱 |
| 멀티파일 편집 | ✅ | ✅ | ✅ |
| 터미널 통합 | ✅ 명령 실행 | ✅ 명령 실행 | ⚠️ 제한적 |
| 무료 플랜 | 크레딧 제한 있음 | 2주 체험 | 월 $10 |
| 특장점 | 자연스러운 흐름 | 정밀한 코드 이해 | GitHub 생태계 통합 |

## 흔한 실수 & 해결

| 실수 | 해결 |
|------|------|
| Cascade가 엉뚱한 파일을 수정 | `.windsurfrules`에 수정 범위를 명시 |
| 인덱싱이 느림 | Settings에서 제외할 폴더 설정 (`node_modules`, `.git`) |
| 자동완성이 안 나옴 | Supercomplete 활성화 확인 (Settings → Cascade) |
| 이전 컨텍스트를 잊음 | `@파일명`으로 명시적 참조 추가 |
| 긴 대화에서 품질 저하 | 새 Cascade 세션 시작 (`Cmd+Shift+L`) |

## 유용한 @멘션 기능

| 멘션 | 용도 |
|------|------|
| `@파일명` | 특정 파일을 컨텍스트에 추가 |
| `@폴더명` | 폴더 전체를 참조 |
| `@Web` | 웹 검색 결과 참조 |
| `@Docs` | 공식 문서 검색 |
| `@Codebase` | 프로젝트 전체 검색 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
