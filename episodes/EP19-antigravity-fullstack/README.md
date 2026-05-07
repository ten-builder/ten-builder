# EP19: Google Antigravity로 풀스택 앱 처음부터 만들기 — Agent Manager 실전

> Google Antigravity IDE의 Agent Manager를 활용해 백엔드 API, 프론트엔드, 데이터베이스를 여러 에이전트가 동시에 구현하는 라이브 코딩 에피소드 — 멀티 에이전트 병렬 실행 실전

## 📺 영상

**[YouTube에서 보기](https://youtube.com/@ten-builder)**

---

## 이 에피소드에서 다루는 것

- Antigravity의 두 가지 모드(Editor vs Agent Manager)를 언제 어떻게 쓰는지 실전 비교
- Agent Manager에서 프론트엔드·백엔드·데이터베이스 에이전트를 동시에 스폰하는 방법
- 병렬로 실행 중인 에이전트들이 충돌 없이 코드를 합치는 조율 패턴
- 에이전트 실행 중 실패·충돌 발생 시 대응하는 실전 트러블슈팅
- 완성된 풀스택 앱 실제 데모

---

## 스택

| 레이어 | 기술 |
|--------|------|
| 프론트엔드 | Next.js 15 + Tailwind CSS + shadcn/ui |
| 백엔드 | FastAPI (Python) + Pydantic |
| 데이터베이스 | PostgreSQL + Prisma |
| AI 에이전트 IDE | Google Antigravity (Agent Manager) |
| 배포 | Vercel (프론트) + Railway (백엔드) |
| 인증 | Clerk |

---

## Antigravity 모드 비교

| 항목 | Editor 모드 | Agent Manager 모드 |
|------|------------|------------------|
| 주요 사용 시점 | 단일 파일 편집, 빠른 수정 | 복잡한 기능, 멀티 레이어 개발 |
| 에이전트 수 | 1개 | 여러 개 동시 실행 |
| 사용자 역할 | 직접 코드 확인하며 진행 | 아키텍트 — 에이전트들을 조율 |
| 적합한 태스크 | 버그 수정, 리팩토링, 단순 기능 | 신규 기능 구현, 풀스택 앱 구축 |
| 컨텍스트 공유 | 단일 에이전트가 모든 파일 담당 | 에이전트별 독립 워크스페이스 |

---

## 타임라인

### Part 1 (0-20분): 프로젝트 설정 + 아키텍처 계획

```
0min  → Antigravity 설치 확인 + 새 프로젝트 열기
5min  → Agent Manager 모드 진입 + 에이전트 역할 정의
10min → 프로젝트 구조 계획 (Agent Manager에 스코프 설명)
15min → 3개 에이전트 동시 스폰: Frontend / Backend / Database
```

### Part 2 (20-50분): 병렬 구현

```
20min → 에이전트들 독립 실행 시작 (실시간 상태 모니터링)
30min → 백엔드 API 엔드포인트 완성 확인
35min → 데이터베이스 스키마 + 마이그레이션 완성
45min → 프론트엔드 컴포넌트 완성
50min → 에이전트 결과물 통합 시작
```

### Part 3 (50-80분): 통합 + 검증

```
50min → 프론트엔드 ↔ 백엔드 API 연결 확인
60min → 인증 에이전트 추가 스폰 (Clerk 통합)
70min → 통합 테스트 에이전트 실행
80min → 배포 에이전트로 Vercel + Railway 배포
```

---

## Agent Manager 에이전트 구성

### 역할별 에이전트 정의

```
Agent 1 (Frontend):
"Next.js 15 App Router로 대시보드 UI를 구현해줘.
사이드바 네비게이션, 통계 카드 3개, 최근 활동 피드가 필요해.
API 베이스 URL은 환경변수 NEXT_PUBLIC_API_URL로 참조해.
Tailwind + shadcn/ui 사용."

Agent 2 (Backend):
"FastAPI로 대시보드에 필요한 REST API를 만들어줘.
GET /api/stats, GET /api/activities, POST /api/items 엔드포인트.
데이터베이스 연결은 DATABASE_URL 환경변수로 처리.
응답 스키마는 Pydantic으로 정의해."

Agent 3 (Database):
"PostgreSQL 스키마를 설계하고 Prisma 마이그레이션 파일을 만들어줘.
User, Item, Activity 3개 테이블이 필요해.
created_at, updated_at은 자동 설정."
```

### 병렬 실행 중 에이전트 상태 확인

Agent Manager 뷰에서 각 에이전트의 상태가 실시간으로 표시됩니다:

```
[Agent 1 - Frontend]  ● 진행 중 — components/Dashboard.tsx 생성 중
[Agent 2 - Backend]   ● 진행 중 — api/routes/stats.py 작성 중
[Agent 3 - Database]  ✓ 완료    — schema.prisma + 마이그레이션 파일 생성
```

---

## 핵심 코드 & 설정

### 프로젝트 루트 AGENTS.md

```markdown
# AGENTS.md

## 프로젝트 개요
풀스택 대시보드 앱 — Next.js(프론트) + FastAPI(백엔드) + PostgreSQL(DB)

## 디렉토리 구조
/frontend  - Next.js 15 앱
/backend   - FastAPI 앱
/db        - Prisma 스키마 + 마이그레이션

## API 계약
- 베이스 URL: http://localhost:8000 (로컬), NEXT_PUBLIC_API_URL (프로덕션)
- 모든 응답은 JSON, Content-Type: application/json
- 에러 형식: { "detail": "error message" }

## 환경변수
- NEXT_PUBLIC_API_URL: 백엔드 API 주소
- DATABASE_URL: PostgreSQL 연결 문자열
- CLERK_SECRET_KEY: 인증 서버 키

## 에이전트 조율 규칙
- Frontend 에이전트: /frontend 폴더만 수정
- Backend 에이전트: /backend 폴더만 수정
- Database 에이전트: /db 폴더만 수정
- 공유 타입이 필요하면 /shared/types.ts에 정의
```

### 백엔드 API 엔드포인트 (FastAPI)

```python
# backend/api/routes/stats.py
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List
from ..database import get_db
from ..schemas import StatsResponse, ActivityItem

router = APIRouter(prefix="/api", tags=["dashboard"])

@router.get("/stats", response_model=StatsResponse)
async def get_stats(db: Session = Depends(get_db)):
    total_items = db.query(Item).count()
    active_users = db.query(User).filter(User.is_active == True).count()
    recent_count = db.query(Activity).filter(
        Activity.created_at >= datetime.now() - timedelta(days=7)
    ).count()

    return StatsResponse(
        total_items=total_items,
        active_users=active_users,
        recent_activity=recent_count
    )

@router.get("/activities", response_model=List[ActivityItem])
async def get_activities(
    limit: int = 10,
    db: Session = Depends(get_db)
):
    activities = db.query(Activity)\
        .order_by(Activity.created_at.desc())\
        .limit(limit)\
        .all()
    return activities
```

### 프론트엔드 대시보드 컴포넌트

```tsx
// frontend/components/Dashboard.tsx
import { useEffect, useState } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"

interface Stats {
  total_items: number
  active_users: number
  recent_activity: number
}

export default function Dashboard() {
  const [stats, setStats] = useState<Stats | null>(null)

  useEffect(() => {
    fetch(`${process.env.NEXT_PUBLIC_API_URL}/api/stats`)
      .then(res => res.json())
      .then(setStats)
  }, [])

  if (!stats) return <div className="p-8">불러오는 중...</div>

  return (
    <div className="grid grid-cols-3 gap-4 p-6">
      <Card>
        <CardHeader>
          <CardTitle>전체 항목</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-3xl font-bold">{stats.total_items}</p>
        </CardContent>
      </Card>
      <Card>
        <CardHeader>
          <CardTitle>활성 사용자</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-3xl font-bold">{stats.active_users}</p>
        </CardContent>
      </Card>
      <Card>
        <CardHeader>
          <CardTitle>최근 7일 활동</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-3xl font-bold">{stats.recent_activity}</p>
        </CardContent>
      </Card>
    </div>
  )
}
```

### 데이터베이스 스키마 (Prisma)

```prisma
// db/schema.prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id         String     @id @default(cuid())
  email      String     @unique
  name       String?
  is_active  Boolean    @default(true)
  created_at DateTime   @default(now())
  updated_at DateTime   @updatedAt
  items      Item[]
  activities Activity[]
}

model Item {
  id         String   @id @default(cuid())
  title      String
  content    String?
  user_id    String
  user       User     @relation(fields: [user_id], references: [id])
  created_at DateTime @default(now())
  updated_at DateTime @updatedAt
}

model Activity {
  id         String   @id @default(cuid())
  action     String
  user_id    String
  user       User     @relation(fields: [user_id], references: [id])
  created_at DateTime @default(now())
}
```

---

## 에이전트 충돌 처리 패턴

### 같은 파일을 여러 에이전트가 수정할 때

Agent Manager에서 에이전트 간 파일 충돌이 감지되면, 아래처럼 조율합니다:

```
상황: Frontend 에이전트와 Backend 에이전트가 모두
      /shared/types.ts를 수정하려고 할 때

해결:
1. Backend 에이전트에게 먼저 타입 정의를 완성하도록 대기 설정
2. Frontend 에이전트는 Backend 에이전트 완료 신호 후 해당 타입을 import

프롬프트 패턴:
"shared/types.ts는 Backend 에이전트가 먼저 정의한다.
Frontend 에이전트는 해당 파일을 읽기만 하고 수정하지 않는다."
```

### 에이전트 실패 시 재시작 없이 이어받기

```
에이전트가 중간에 실패했을 때:
1. Agent Manager의 실패 에이전트 아티팩트(작업 로그) 확인
2. 실패 지점을 파악 후 새 에이전트에게 "여기서부터 계속해줘" 지시
3. 이미 완료된 파일은 다시 만들지 않도록 맥락 제공
```

---

## AI 에이전트 활용 포인트

| 상황 | 프롬프트 예시 |
|------|-------------|
| 에이전트 역할 정의 | `백엔드 에이전트: /backend 폴더만 담당. 다른 폴더는 읽기만 가능.` |
| 병렬 작업 분배 | `세 가지 태스크를 동시에 실행해줘. 각 에이전트가 독립적으로 완료할 수 있는 작업으로 나눠.` |
| 충돌 방지 | `공유 타입은 /shared/types.ts 한 곳에만 정의. 다른 에이전트들은 import해서 사용.` |
| 통합 검증 | `세 에이전트 결과물을 통합하고 API 호출이 정상적으로 연결되는지 확인해줘.` |
| 배포 자동화 | `프론트엔드는 Vercel, 백엔드는 Railway에 배포하는 스크립트를 각각 만들어줘.` |

---

## 따라하기

### Step 1: Antigravity에서 Agent Manager 열기

```
1. Antigravity IDE 실행
2. 좌측 상단 모드 전환 버튼 → "Agent Manager" 선택
3. 새 프로젝트 폴더 설정
4. AGENTS.md 파일을 루트에 먼저 작성
```

### Step 2: 에이전트 스폰

```
Agent Manager 뷰에서 "New Agent" 클릭 → 역할과 초기 태스크 입력
세 에이전트를 순차적으로 스폰하면 자동으로 병렬 실행 시작
```

### Step 3: 진행 상황 모니터링

```bash
# Agent Manager 뷰에서 확인 가능한 정보
- 각 에이전트의 현재 작업 파일
- 에이전트별 아티팩트 목록 (생성된 파일, diff)
- 대기 중인 사용자 승인 요청
```

### Step 4: 통합 + 검증

```bash
# 에이전트들 완료 후 통합 확인
cd frontend && npm install && npm run dev    # 프론트엔드 실행
cd backend && pip install -r requirements.txt && uvicorn main:app  # 백엔드 실행
cd db && npx prisma migrate dev             # DB 마이그레이션
```

---

## 더 알아보기

- [Google Antigravity IDE 실전 가이드 2026](../../guides/85-google-antigravity-ide-practical-guide-2026.md)
- [AI 에이전트 팀 구성 가이드 — 역할 분담으로 복잡한 기능 완성하기](../../guides/72-ai-coding-agent-team-composition-guide.md)
- [Next.js + Vercel AI SDK 풀스택 AI 앱 개발 가이드 2026](../../guides/82-nextjs-vercel-ai-sdk-guide-2026.md)

---

**구독하기:** [@ten-builder](https://youtube.com/@ten-builder) | [뉴스레터](https://maily.so/tenbuilder)
