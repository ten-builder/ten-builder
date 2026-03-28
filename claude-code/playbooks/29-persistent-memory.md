# 플레이북 29: AI 코딩 에이전트 영속 메모리 구축

> 세션이 끝나면 모든 걸 잊는 AI — 기억을 이어붙이는 실전 메모리 아키텍처 구축법

## 소요 시간

20-30분

## 사전 준비

- Claude Code 또는 Cursor 설치 완료
- Node.js 18+ 또는 Python 3.10+
- 메모리 저장소 선택 (파일 기반 / Mem0 / Zep 중 하나)

## 왜 메모리가 필요한가

AI 코딩 에이전트는 기본적으로 무상태(stateless)입니다. 새 세션을 시작할 때마다:

- 프로젝트 아키텍처를 다시 설명해야 합니다
- 이전에 내린 설계 결정을 다시 논의합니다
- 같은 실수를 반복하고, 같은 해결책을 다시 찾습니다

메모리 시스템은 이 문제를 해결하여 **세션 간 컨텍스트 연속성**을 확보해 줍니다.

## Step 1: 메모리 유형 이해하기

AI 에이전트 메모리는 인지과학의 분류와 유사한 네 가지 유형으로 나뉩니다.

| 유형 | 설명 | 코딩 에이전트 적용 |
|------|------|-------------------|
| **단기 메모리** | 현재 대화 컨텍스트 | 진행 중인 태스크의 파일/변수 |
| **시맨틱 메모리** | 축적된 사실 지식 | 프로젝트 아키텍처, API 스펙 |
| **에피소드 메모리** | 과거 경험 기록 | 이전 세션에서 해결한 버그 패턴 |
| **절차적 메모리** | 학습된 실행 패턴 | 반복 태스크의 자동화 루틴 |

실전에서 가장 효과가 큰 순서: **시맨틱 > 에피소드 > 절차적 > 단기**

## Step 2: 파일 기반 메모리 시스템 (가장 쉬운 방법)

외부 서비스 없이 파일만으로 메모리를 구축하는 방법입니다.

### 디렉토리 구조

```
.claude/
├── CLAUDE.md          # 시맨틱 메모리 (프로젝트 지식)
├── memory/
│   ├── decisions.md   # 설계 결정 로그
│   ├── patterns.md    # 반복 패턴/해결책
│   ├── mistakes.md    # 실수와 교훈
│   └── sessions/
│       ├── 2026-03-28.md  # 에피소드 메모리
│       └── 2026-03-29.md
```

### CLAUDE.md에 메모리 지시 추가

```markdown
## Memory Protocol

매 세션 시작 시:
1. memory/decisions.md 읽기 — 이전 설계 결정 확인
2. memory/mistakes.md 읽기 — 같은 실수 방지
3. 최근 sessions/ 파일 1-2개 읽기 — 진행 상황 파악

매 세션 종료 전:
1. 중요 결정이 있었으면 decisions.md에 추가
2. 새로운 패턴 발견 시 patterns.md에 기록
3. sessions/ 에 오늘 세션 요약 작성
```

### 세션 로그 템플릿

```markdown
# 세션: 2026-03-29

## 작업 내용
- 인증 모듈 리팩토링
- JWT → 세션 기반으로 전환

## 결정사항
- Redis를 세션 스토어로 선택 (Memcached 대비 TTL 관리 용이)

## 미완료
- [ ] 세션 만료 시 자동 갱신 로직

## 교훈
- `express-session`의 `resave: false` 설정 안 하면 매 요청마다 세션 저장됨
```

## Step 3: 구조화된 메모리 시스템 구축

파일 기반에서 한 단계 업그레이드하여 JSON/YAML로 메모리를 구조화합니다.

### 메모리 스키마

```typescript
// memory-schema.ts
interface MemoryEntry {
  id: string;
  type: 'decision' | 'pattern' | 'mistake' | 'fact';
  content: string;
  context: string;        // 어떤 상황에서
  tags: string[];          // 검색용 태그
  created_at: string;
  relevance_score: number; // 1-10, 높을수록 자주 참조
}

interface SessionMemory {
  date: string;
  tasks_completed: string[];
  decisions: string[];
  unfinished: string[];
  lessons: string[];
  files_modified: string[];
}
```

### 메모리 관리 스크립트

```python
#!/usr/bin/env python3
"""memory_manager.py — 세션 메모리 자동 관리"""

import json
import os
from datetime import datetime, timedelta
from pathlib import Path

MEMORY_DIR = Path(".claude/memory")

def compact_old_sessions(days_threshold: int = 30):
    """오래된 세션 로그를 요약으로 압축"""
    sessions_dir = MEMORY_DIR / "sessions"
    cutoff = datetime.now() - timedelta(days=days_threshold)

    summaries = []
    for f in sorted(sessions_dir.glob("*.json")):
        date_str = f.stem
        session_date = datetime.strptime(date_str, "%Y-%m-%d")

        if session_date < cutoff:
            with open(f) as fp:
                data = json.load(fp)
            summaries.append({
                "date": date_str,
                "key_decisions": data.get("decisions", []),
                "lessons": data.get("lessons", [])
            })
            f.unlink()  # 원본 삭제

    if summaries:
        archive_path = MEMORY_DIR / "archive.json"
        existing = json.loads(archive_path.read_text()) if archive_path.exists() else []
        existing.extend(summaries)
        archive_path.write_text(json.dumps(existing, indent=2, ensure_ascii=False))
        print(f"Archived {len(summaries)} old sessions")

def get_relevant_memories(query: str, top_k: int = 5):
    """태그 기반으로 관련 메모리 검색"""
    entries_path = MEMORY_DIR / "entries.json"
    if not entries_path.exists():
        return []

    entries = json.loads(entries_path.read_text())
    query_words = set(query.lower().split())

    scored = []
    for entry in entries:
        tag_overlap = len(query_words & set(t.lower() for t in entry["tags"]))
        score = tag_overlap * 2 + entry.get("relevance_score", 5)
        scored.append((score, entry))

    scored.sort(key=lambda x: x[0], reverse=True)
    return [entry for _, entry in scored[:top_k]]

if __name__ == "__main__":
    compact_old_sessions()
```

## Step 4: 외부 메모리 프레임워크 연동

프로젝트 규모가 크거나 팀으로 작업한다면 전용 메모리 프레임워크를 사용하세요.

### Mem0 연동 (가장 간편)

```bash
pip install mem0ai
```

```python
from mem0 import Memory

# 초기화
memory = Memory()

# 메모리 추가
memory.add(
    "이 프로젝트는 PostgreSQL 15를 사용하고 Prisma ORM으로 접근한다",
    user_id="project-backend",
    metadata={"category": "architecture"}
)

# 세션 시작 시 관련 메모리 검색
results = memory.search(
    "데이터베이스 연결 설정",
    user_id="project-backend"
)

for r in results:
    print(f"[{r['metadata'].get('category')}] {r['memory']}")
```

### MCP 서버로 메모리 연결

Claude Code에서 MCP를 통해 메모리에 접근하는 설정:

```json
{
  "mcpServers": {
    "memory": {
      "command": "npx",
      "args": ["-y", "@mem0/mcp-server"],
      "env": {
        "MEM0_API_KEY": "your-api-key"
      }
    }
  }
}
```

이렇게 설정하면 Claude Code 세션에서 자연어로 메모리를 조회하고 저장할 수 있습니다.

## Step 5: 메모리 위생 관리

메모리가 쌓이면 노이즈가 되어 오히려 성능이 떨어집니다.

### 위생 규칙

| 규칙 | 기준 | 실행 |
|------|------|------|
| 중복 제거 | 유사도 90% 이상 | 주 1회 스크립트 |
| 관련성 감쇠 | 30일 미참조 | relevance_score -1 |
| 아카이빙 | score 2 이하 | 월 1회 아카이브 이동 |
| 컨텍스트 예산 | 최대 2000토큰 | 세션 시작 시 상위 N개만 |

### 자동 정리 훅 (Claude Code Hooks)

```bash
#!/bin/bash
# .claude/hooks/post-session.sh
# 세션 종료 후 메모리 정리

python3 .claude/memory/memory_manager.py

# 메모리 파일 크기 체크
MEMORY_SIZE=$(du -sk .claude/memory/ | cut -f1)
if [ "$MEMORY_SIZE" -gt 512 ]; then
    echo "Warning: Memory directory exceeds 512KB. Consider compacting."
fi
```

## Step 6: 팀 메모리 공유 패턴

혼자 쓰는 메모리를 팀으로 확장하는 방법입니다.

### Git 기반 공유 (간편)

```bash
# .claude/memory/는 .gitignore에서 제외하여 팀과 공유
# 개인 메모리는 .claude/memory/personal/에 보관

.claude/memory/shared/     # 팀 공유 (커밋)
.claude/memory/personal/   # 개인용 (.gitignore)
```

### 공유 메모리 컨벤션

```markdown
# .claude/memory/shared/architecture.md

## 데이터베이스
- PostgreSQL 15 + Prisma ORM
- 마이그레이션: prisma migrate dev
- 시드: prisma db seed (결정일: 2026-03-15)

## 인증
- NextAuth.js v5
- Provider: Google, GitHub
- 세션 전략: JWT (결정일: 2026-03-20)
```

## 체크리스트

- [ ] `.claude/memory/` 디렉토리 생성
- [ ] CLAUDE.md에 메모리 프로토콜 추가
- [ ] 세션 로그 템플릿 작성
- [ ] 메모리 정리 스크립트 설정
- [ ] (선택) Mem0/Zep 연동
- [ ] (팀) 공유 메모리 컨벤션 합의

## 다음 단계

→ [컨텍스트 관리 플레이북](12-context-management.md) — 메모리와 컨텍스트 윈도우를 함께 최적화
→ [AI 세션 메모리 관리 워크플로우](../../workflows/ai-session-memory-management.md) — 세션 핸드오프 패턴

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
