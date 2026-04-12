# AI 에이전트 메모리 아키텍처 치트시트

> AI 코딩 에이전트의 단기·장기·외부 메모리 패턴을 한 페이지로 정리 — CLAUDE.md, 메모리 파일, 벡터 DB 연동

---

## 메모리 3계층 구조

| 계층 | 범위 | 지속성 | 구현 방식 |
|------|------|--------|----------|
| **단기 메모리** | 현재 세션 | 세션 종료 시 소멸 | 컨텍스트 윈도우, 롤링 버퍼 |
| **장기 메모리** | 세션 간 | 영구 | CLAUDE.md, Memory 파일 |
| **외부 메모리** | 세션 간 | 영구 + 확장 가능 | 벡터 DB, 지식 그래프 |

---

## 단기 메모리 패턴

세션 내에서 대화 흐름과 태스크 연속성을 유지하는 메모리입니다.

| 패턴 | 설명 | 사용 시점 |
|------|------|----------|
| **전체 히스토리** | 대화 전체를 컨텍스트에 포함 | 짧은 세션, 중요 대화 |
| **롤링 버퍼** | 최근 N턴만 유지, 오래된 것 제거 | 긴 세션, 토큰 절약 |
| **선택적 추출** | 중요 내용만 요약해 보존 | 대규모 코드베이스 작업 |
| **체크포인팅** | 중간 상태를 파일에 저장 | 멀티 단계 태스크 |

### 롤링 버퍼 설정 예시

```python
# LangChain 기반 롤링 버퍼
from langchain.memory import ConversationBufferWindowMemory

memory = ConversationBufferWindowMemory(
    k=10,  # 최근 10턴만 유지
    return_messages=True
)
```

---

## 장기 메모리 패턴

### Claude Code 메모리 계층

```
~/.claude/CLAUDE.md          # 사용자 전역 설정
  └── {project}/CLAUDE.md    # 프로젝트별 규칙
        └── auto-memory/     # 자동 저장 학습 내용
              └── MEMORY.md  # 세션 간 기억 (최대 200줄 / 25KB)
```

### CLAUDE.md 활용 패턴

```markdown
## 프로젝트 메모리

### 빌드 명령어
- 개발 서버: `pnpm dev`
- 테스트: `pnpm test --watch`
- 빌드: `pnpm build && pnpm typecheck`

### 아키텍처 결정사항
- 상태 관리: Zustand (Redux 사용 금지)
- API 레이어: tRPC (REST 직접 호출 금지)
- 스타일: Tailwind CSS + shadcn/ui

### 반복 실수 방지
- `any` 타입 사용 금지 — 반드시 타입 정의
- 환경변수는 `process.env.NEXT_PUBLIC_` 접두어 필수
```

### 장기 메모리 3가지 유형

| 유형 | 설명 | 구현 예시 |
|------|------|----------|
| **에피소딕 메모리** | 특정 과거 경험 기억 | 버그 수정 이력, 리팩토링 결정 로그 |
| **시맨틱 메모리** | 구조화된 지식, 규칙 | 아키텍처 패턴, 코딩 컨벤션 |
| **절차적 메모리** | 반복 작업 스크립트 | 배포 절차, 테스트 루틴 |

---

## 외부 메모리 패턴 (벡터 DB)

컨텍스트 윈도우 한계를 넘어 대규모 지식을 관리할 때 사용합니다.

### 주요 벡터 DB 비교

| 도구 | 특징 | 적합한 상황 |
|------|------|-----------|
| **Pinecone** | 관리형, 빠른 시작 | 프로덕션, 팀 공유 |
| **Weaviate** | 오픈소스, 멀티모달 | 코드+문서 혼합 검색 |
| **Qdrant** | 고성능, Rust 기반 | 대규모 코드베이스 |
| **Chroma** | 로컬 임베딩, 무료 | 개인 프로젝트, 실험 |

### RAG 기반 코드 메모리 구현

```python
from langchain_openai import OpenAIEmbeddings
from langchain_chroma import Chroma
from langchain.text_splitter import RecursiveCharacterTextSplitter

# 1. 코드베이스 임베딩
splitter = RecursiveCharacterTextSplitter(
    chunk_size=1000,
    chunk_overlap=200,
    separators=["\nclass ", "\ndef ", "\n\n", "\n"]
)

# 2. 벡터 스토어에 저장
vectorstore = Chroma.from_documents(
    documents=code_chunks,
    embedding=OpenAIEmbeddings(),
    persist_directory="./code-memory"
)

# 3. 관련 코드 검색
retriever = vectorstore.as_retriever(search_kwargs={"k": 5})
relevant_code = retriever.get_relevant_documents("인증 로직")
```

---

## 메모리 관리 전략

### 메모리 계층 설계 원칙

```
[즉각 컨텍스트]    현재 파일, 선택 영역, 최근 에러
       ↓
[세션 메모리]      현재 작업 흐름, 관련 파일 목록
       ↓
[프로젝트 메모리]  CLAUDE.md, 아키텍처 문서
       ↓
[외부 메모리]      전체 코드베이스 임베딩, 과거 PR 기록
```

### 메모리 감쇠 전략

| 상황 | 처리 방법 |
|------|----------|
| MEMORY.md 200줄 초과 | 오래된 에피소딕 메모리부터 삭제 |
| 컨텍스트 윈도우 80% 초과 | 롤링 버퍼로 전환, 요약 삽입 |
| 오래된 벡터 임베딩 | 3개월 이상 미참조 항목 아카이브 |

### Mem0 연동 (Claude Code 플러그인)

```bash
# Mem0 설치
npm install mem0-claude-code

# claude_desktop_config.json 설정
{
  "mcpServers": {
    "mem0": {
      "command": "npx",
      "args": ["mem0-claude-code"],
      "env": {
        "MEM0_API_KEY": "your-key"
      }
    }
  }
}
```

Mem0는 기본 MEMORY.md의 200줄 제한을 우회하여 벡터 임베딩 기반으로 세션 간 메모리를 관리합니다.

---

## 멀티 에이전트 공유 메모리

여러 에이전트가 협업할 때 메모리 공유 패턴입니다.

```yaml
# 공유 메모리 구조 예시
shared-memory/
  ├── project-context.md    # 전체 에이전트 공유 컨텍스트
  ├── agent-A/              # 에이전트 A 전용 메모리
  │   └── task-state.json
  ├── agent-B/              # 에이전트 B 전용 메모리
  │   └── task-state.json
  └── handoff/              # 에이전트 간 인수인계 파일
      └── 2026-04-12.md
```

---

## 흔한 실수 & 해결

| 실수 | 해결 |
|------|------|
| MEMORY.md가 너무 커져서 잘림 | 주기적으로 불필요한 항목 삭제, Mem0 도입 |
| 에이전트가 이전 결정을 "망각" | 아키텍처 결정을 CLAUDE.md에 명시적으로 기록 |
| 벡터 검색 결과가 부정확함 | 청크 크기 조정, 코드 구조 기반 분할 |
| 여러 에이전트 메모리 충돌 | 에이전트별 네임스페이스 분리 + 공유 컨텍스트 명확화 |
| 민감한 정보가 메모리에 저장됨 | .gitignore에 메모리 파일 추가, 암호화 저장 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
