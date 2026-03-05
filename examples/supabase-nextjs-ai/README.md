# Supabase + Next.js AI 풀스택 예제

> Supabase 인증/DB와 Next.js를 조합해서 AI 도구로 빠르게 풀스택 앱을 만드는 실전 가이드

## 이 예제에서 배울 수 있는 것

- Supabase Auth로 이메일/소셜 로그인을 10분 만에 구현하는 방법
- Row Level Security(RLS) 정책을 AI로 생성하고 검증하는 패턴
- Next.js Server Actions + Supabase 클라이언트를 연결하는 실전 구조

## 프로젝트 구조

```
supabase-nextjs-ai/
├── CLAUDE.md                  # Claude Code 프로젝트 설정
├── src/
│   ├── app/
│   │   ├── layout.tsx         # 루트 레이아웃 (AuthProvider 포함)
│   │   ├── page.tsx           # 랜딩 페이지
│   │   ├── login/
│   │   │   └── page.tsx       # 로그인 페이지
│   │   ├── dashboard/
│   │   │   └── page.tsx       # 인증된 사용자 대시보드
│   │   └── api/
│   │       └── notes/
│   │           └── route.ts   # Notes CRUD API
│   ├── components/
│   │   ├── AuthButton.tsx     # 로그인/로그아웃 버튼
│   │   ├── NoteCard.tsx       # 노트 카드
│   │   └── NoteForm.tsx       # 노트 작성 폼
│   └── lib/
│       ├── supabase/
│       │   ├── client.ts      # 브라우저용 클라이언트
│       │   ├── server.ts      # 서버용 클라이언트
│       │   └── middleware.ts  # 세션 갱신 미들웨어
│       └── types.ts           # DB 타입 (자동 생성)
├── supabase/
│   ├── migrations/
│   │   └── 001_create_notes.sql
│   └── seed.sql
├── package.json
└── .env.local.example
```

## 사전 준비

- Node.js 20+
- Supabase CLI (`npx supabase init`)
- Supabase 프로젝트 (무료 플랜 OK)

## 시작하기

### Step 1: 프로젝트 생성 + Supabase 연결

```bash
pnpm create next-app@latest my-notes --typescript --tailwind --app --src-dir
cd my-notes

# Supabase 패키지 설치
pnpm add @supabase/supabase-js @supabase/ssr

# Supabase CLI 초기화
npx supabase init
```

### Step 2: 환경 변수 설정

```bash
# .env.local
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...your-anon-key
```

Supabase 대시보드 → Settings → API에서 URL과 `anon` 키를 복사해요.

### Step 3: Supabase 클라이언트 설정

AI에게 이렇게 요청하면 클라이언트 설정 파일을 한 번에 만들 수 있어요:

```
Supabase SSR 패키지를 사용해서 브라우저용 클라이언트(lib/supabase/client.ts)와
서버용 클라이언트(lib/supabase/server.ts)를 만들어줘.
Next.js App Router + cookies() 기반으로 세션을 관리해야 해.
```

## 핵심 코드

### Supabase 서버 클라이언트

```typescript
// src/lib/supabase/server.ts
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

export async function createClient() {
  const cookieStore = await cookies();

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value, options }) =>
            cookieStore.set(name, value, options)
          );
        },
      },
    }
  );
}
```

**왜 이렇게 했나요?**

`@supabase/ssr` 패키지는 Next.js의 쿠키 기반 세션 관리와 자연스럽게 연결돼요. 서버 컴포넌트에서 `createClient()`를 호출하면 현재 사용자의 세션이 자동으로 포함돼요.

### 인증 미들웨어

```typescript
// src/middleware.ts
import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

export async function middleware(request: NextRequest) {
  let response = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value, options }) => {
            response.cookies.set(name, value, options);
          });
        },
      },
    }
  );

  const { data: { user } } = await supabase.auth.getUser();

  // 비인증 사용자는 로그인으로 리다이렉트
  if (!user && request.nextUrl.pathname.startsWith("/dashboard")) {
    return NextResponse.redirect(new URL("/login", request.url));
  }

  return response;
}

export const config = {
  matcher: ["/dashboard/:path*"],
};
```

### DB 마이그레이션 (Notes 테이블)

```sql
-- supabase/migrations/001_create_notes.sql
CREATE TABLE notes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  content TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- RLS 활성화
ALTER TABLE notes ENABLE ROW LEVEL SECURITY;

-- 본인 노트만 조회
CREATE POLICY "Users can view own notes"
  ON notes FOR SELECT
  USING (auth.uid() = user_id);

-- 본인 노트만 생성
CREATE POLICY "Users can create own notes"
  ON notes FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- 본인 노트만 수정
CREATE POLICY "Users can update own notes"
  ON notes FOR UPDATE
  USING (auth.uid() = user_id);

-- 본인 노트만 삭제
CREATE POLICY "Users can delete own notes"
  ON notes FOR DELETE
  USING (auth.uid() = user_id);
```

**왜 이렇게 했나요?**

RLS 정책을 테이블 생성 시점에 바로 설정하는 게 중요해요. 나중에 추가하면 그 사이에 데이터가 노출될 수 있어요. `auth.uid()` 함수가 현재 로그인한 사용자의 ID를 자동으로 반환해요.

### Server Action으로 CRUD 구현

```typescript
// src/app/dashboard/actions.ts
"use server";

import { createClient } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";

export async function getNotes() {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("notes")
    .select("*")
    .order("created_at", { ascending: false });

  if (error) throw new Error(error.message);
  return data;
}

export async function createNote(formData: FormData) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) throw new Error("인증이 필요합니다");

  const { error } = await supabase.from("notes").insert({
    title: formData.get("title") as string,
    content: formData.get("content") as string,
    user_id: user.id,
  });

  if (error) throw new Error(error.message);
  revalidatePath("/dashboard");
}

export async function deleteNote(noteId: string) {
  const supabase = await createClient();
  const { error } = await supabase
    .from("notes")
    .delete()
    .eq("id", noteId);

  if (error) throw new Error(error.message);
  revalidatePath("/dashboard");
}
```

## AI 활용 포인트

| 상황 | 프롬프트 예시 |
|------|-------------|
| RLS 정책 생성 | `notes 테이블에 RLS 정책을 추가해줘. 사용자는 본인 데이터만 CRUD할 수 있어야 해` |
| 타입 자동 생성 | `npx supabase gen types typescript 실행하고 결과를 lib/types.ts에 저장해줘` |
| 소셜 로그인 추가 | `Google OAuth 로그인을 추가해줘. Supabase Auth 설정과 콜백 라우트 둘 다 만들어줘` |
| 에러 핸들링 | `Supabase 쿼리에서 에러가 발생하면 toast로 사용자에게 알려주는 패턴을 적용해줘` |
| 실시간 구독 | `notes 테이블에 Realtime 구독을 추가해서 다른 기기에서 변경하면 자동으로 UI가 갱신되게 해줘` |

## 자주 만나는 문제

| 문제 | 해결 |
|------|------|
| `auth.uid()` 반환값이 null | 미들웨어에서 세션 갱신 로직이 빠져 있는지 확인 |
| RLS로 인해 데이터 안 보임 | Supabase 대시보드 → SQL Editor에서 정책 확인. `auth.uid()` 테스트 |
| 타입 불일치 에러 | `npx supabase gen types typescript --local > src/lib/types.ts`로 타입 재생성 |
| 쿠키 관련 경고 | `@supabase/ssr` 최신 버전 사용 여부 확인. Next.js 15+는 `cookies()` await 필수 |

## 다음 단계

이 기본 구조를 확장해서 만들 수 있는 것들:

- **파일 업로드:** Supabase Storage로 이미지/파일 첨부 기능
- **실시간 협업:** Supabase Realtime으로 동시 편집
- **결제 연동:** Stripe + Supabase Edge Functions로 구독 모델

---

**더 자세한 가이드:** [claude-code/playbooks](../../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
