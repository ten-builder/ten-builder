# React Native + AI 모바일 앱 예제

> Expo + React Native로 AI 코딩 도구를 활용해 모바일 앱을 처음부터 만드는 실전 가이드

## 이런 분께 추천

- React Native로 모바일 앱을 만들어보고 싶은 프론트엔드 개발자
- AI 코딩 도구를 모바일 개발에 적용하고 싶은 분
- Expo로 빠르게 프로토타입을 만들고 싶은 사이드 프로젝트 빌더
- 네비게이션, 상태 관리, API 연동까지 전 과정을 AI로 자동화하고 싶은 분

## 빠른 시작

```bash
# 1. Expo 프로젝트 생성
npx create-expo-app@latest my-app --template blank-typescript
cd my-app

# 2. 핵심 패키지 설치
npx expo install expo-router react-native-safe-area-context \
  react-native-screens expo-linking expo-constants expo-status-bar

# 3. 상태 관리 + HTTP 클라이언트
npm install zustand axios

# 4. AI 코딩 도구에 첫 프롬프트
# "Expo Router 기반 파일 시스템 라우팅을 설정해줘.
#  app/ 디렉토리에 탭 네비게이션(홈, 검색, 프로필) 구조로 만들어줘."
```

## 이 예제에서 배울 수 있는 것

- Expo + TypeScript 프로젝트를 AI와 함께 구축하는 워크플로우
- 파일 기반 라우팅(Expo Router)과 탭 네비게이션 설정
- Zustand로 가벼운 상태 관리를 구현하는 패턴
- 각 단계에서 사용할 수 있는 실전 AI 프롬프트

## 프로젝트 구조

```
react-native-ai/
├── app/
│   ├── _layout.tsx            # 루트 레이아웃 (탭 네비게이션)
│   ├── index.tsx              # 홈 화면
│   ├── search.tsx             # 검색 화면
│   ├── profile.tsx            # 프로필 화면
│   └── post/
│       └── [id].tsx           # 상세 화면 (동적 라우트)
├── components/
│   ├── PostCard.tsx           # 포스트 카드 컴포넌트
│   ├── SearchBar.tsx          # 검색바 컴포넌트
│   └── ProfileHeader.tsx     # 프로필 헤더
├── stores/
│   └── usePostStore.ts        # Zustand 상태 관리
├── services/
│   └── api.ts                 # API 클라이언트
├── hooks/
│   └── useRefresh.ts          # Pull-to-refresh 커스텀 훅
├── types/
│   └── post.ts                # 타입 정의
├── app.json                   # Expo 설정
├── package.json
└── tsconfig.json
```

## Step 1: 프로젝트 초기 설정

Expo Router를 사용하면 Next.js처럼 파일 시스템 기반 라우팅을 모바일에서도 쓸 수 있어요.

**AI 프롬프트:**
```
Expo Router로 탭 네비게이션을 설정해줘.
탭 3개: 홈(Ionicons home), 검색(Ionicons search), 프로필(Ionicons person).
_layout.tsx에서 Tabs 컴포넌트를 사용하고, 각 탭 화면은 빈 View로 만들어줘.
```

### app/_layout.tsx

```tsx
import { Tabs } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';

export default function RootLayout() {
  return (
    <Tabs
      screenOptions={{
        tabBarActiveTintColor: '#007AFF',
        headerShown: true,
      }}
    >
      <Tabs.Screen
        name="index"
        options={{
          title: '홈',
          tabBarIcon: ({ color, size }) => (
            <Ionicons name="home" size={size} color={color} />
          ),
        }}
      />
      <Tabs.Screen
        name="search"
        options={{
          title: '검색',
          tabBarIcon: ({ color, size }) => (
            <Ionicons name="search" size={size} color={color} />
          ),
        }}
      />
      <Tabs.Screen
        name="profile"
        options={{
          title: '프로필',
          tabBarIcon: ({ color, size }) => (
            <Ionicons name="person" size={size} color={color} />
          ),
        }}
      />
    </Tabs>
  );
}
```

## Step 2: 타입 정의 + API 클라이언트

모바일 앱에서 데이터 흐름의 기본은 타입 정의 → API 클라이언트 → 상태 관리 순서예요.

**AI 프롬프트:**
```
JSONPlaceholder API를 사용하는 API 클라이언트를 만들어줘.
Post 타입 정의하고, getPosts, getPost, searchPosts 함수를 만들어줘.
axios를 쓰고, 에러 핸들링도 포함해줘.
```

### types/post.ts

```typescript
export interface Post {
  id: number;
  userId: number;
  title: string;
  body: string;
}

export interface PostsResponse {
  posts: Post[];
  total: number;
}
```

### services/api.ts

```typescript
import axios from 'axios';
import { Post } from '../types/post';

const client = axios.create({
  baseURL: 'https://jsonplaceholder.typicode.com',
  timeout: 10000,
});

export async function getPosts(page = 1, limit = 10): Promise<Post[]> {
  const start = (page - 1) * limit;
  const { data } = await client.get<Post[]>(
    `/posts?_start=${start}&_limit=${limit}`
  );
  return data;
}

export async function getPost(id: number): Promise<Post> {
  const { data } = await client.get<Post>(`/posts/${id}`);
  return data;
}

export async function searchPosts(query: string): Promise<Post[]> {
  const { data } = await client.get<Post[]>('/posts');
  return data.filter(
    (post) =>
      post.title.toLowerCase().includes(query.toLowerCase()) ||
      post.body.toLowerCase().includes(query.toLowerCase())
  );
}
```

## Step 3: Zustand 상태 관리

React Native에서 가벼운 상태 관리가 필요하면 Zustand가 좋은 선택이에요. Redux보다 보일러플레이트가 적고, Context API보다 성능이 나아요.

**AI 프롬프트:**
```
Zustand으로 포스트 목록 상태 관리 스토어를 만들어줘.
fetchPosts(페이지네이션), searchPosts, refreshPosts 액션을 포함하고,
로딩 상태와 에러 상태도 관리해줘.
```

### stores/usePostStore.ts

```typescript
import { create } from 'zustand';
import { Post } from '../types/post';
import * as api from '../services/api';

interface PostStore {
  posts: Post[];
  page: number;
  loading: boolean;
  refreshing: boolean;
  error: string | null;

  fetchPosts: () => Promise<void>;
  loadMore: () => Promise<void>;
  refresh: () => Promise<void>;
  searchPosts: (query: string) => Promise<void>;
}

export const usePostStore = create<PostStore>((set, get) => ({
  posts: [],
  page: 1,
  loading: false,
  refreshing: false,
  error: null,

  fetchPosts: async () => {
    set({ loading: true, error: null });
    try {
      const posts = await api.getPosts(1);
      set({ posts, page: 1, loading: false });
    } catch (e) {
      set({ error: '포스트를 불러올 수 없습니다', loading: false });
    }
  },

  loadMore: async () => {
    const { page, posts, loading } = get();
    if (loading) return;

    set({ loading: true });
    try {
      const nextPage = page + 1;
      const newPosts = await api.getPosts(nextPage);
      set({
        posts: [...posts, ...newPosts],
        page: nextPage,
        loading: false,
      });
    } catch (e) {
      set({ loading: false });
    }
  },

  refresh: async () => {
    set({ refreshing: true });
    try {
      const posts = await api.getPosts(1);
      set({ posts, page: 1, refreshing: false });
    } catch (e) {
      set({ refreshing: false });
    }
  },

  searchPosts: async (query: string) => {
    set({ loading: true, error: null });
    try {
      const posts = await api.searchPosts(query);
      set({ posts, loading: false });
    } catch (e) {
      set({ error: '검색에 실패했습니다', loading: false });
    }
  },
}));
```

## Step 4: 화면 구현

### 홈 화면 — FlatList + 무한 스크롤

**AI 프롬프트:**
```
FlatList로 포스트 목록을 보여주는 홈 화면을 만들어줘.
무한 스크롤(onEndReached), Pull-to-refresh, 로딩 인디케이터를 포함하고,
각 포스트 카드를 누르면 상세 화면으로 이동하도록 해줘.
```

### app/index.tsx

```tsx
import { useEffect } from 'react';
import {
  FlatList,
  RefreshControl,
  ActivityIndicator,
  View,
  StyleSheet,
} from 'react-native';
import { usePostStore } from '../stores/usePostStore';
import { PostCard } from '../components/PostCard';

export default function HomeScreen() {
  const { posts, loading, refreshing, fetchPosts, loadMore, refresh } =
    usePostStore();

  useEffect(() => {
    fetchPosts();
  }, []);

  return (
    <FlatList
      data={posts}
      keyExtractor={(item) => String(item.id)}
      renderItem={({ item }) => <PostCard post={item} />}
      onEndReached={loadMore}
      onEndReachedThreshold={0.5}
      refreshControl={
        <RefreshControl refreshing={refreshing} onRefresh={refresh} />
      }
      ListFooterComponent={
        loading ? (
          <View style={styles.loader}>
            <ActivityIndicator size="small" />
          </View>
        ) : null
      }
      contentContainerStyle={styles.list}
    />
  );
}

const styles = StyleSheet.create({
  list: { padding: 16 },
  loader: { padding: 20, alignItems: 'center' },
});
```

### components/PostCard.tsx

```tsx
import { View, Text, Pressable, StyleSheet } from 'react-native';
import { useRouter } from 'expo-router';
import { Post } from '../types/post';

interface Props {
  post: Post;
}

export function PostCard({ post }: Props) {
  const router = useRouter();

  return (
    <Pressable
      style={styles.card}
      onPress={() => router.push(`/post/${post.id}`)}
    >
      <Text style={styles.title}>{post.title}</Text>
      <Text style={styles.body} numberOfLines={2}>
        {post.body}
      </Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 2,
  },
  title: {
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 8,
    color: '#1a1a1a',
  },
  body: {
    fontSize: 14,
    color: '#666',
    lineHeight: 20,
  },
});
```

## Step 5: 검색 화면

**AI 프롬프트:**
```
검색바와 결과 목록이 있는 검색 화면을 만들어줘.
TextInput으로 검색어를 입력하면 300ms 디바운스 후 검색하고,
결과가 없을 때 빈 상태 메시지도 보여줘.
```

### app/search.tsx

```tsx
import { useState, useCallback } from 'react';
import {
  View,
  TextInput,
  FlatList,
  Text,
  StyleSheet,
} from 'react-native';
import { usePostStore } from '../stores/usePostStore';
import { PostCard } from '../components/PostCard';

export default function SearchScreen() {
  const [query, setQuery] = useState('');
  const { posts, loading, searchPosts, fetchPosts } = usePostStore();

  const handleSearch = useCallback(
    (text: string) => {
      setQuery(text);

      // 간단한 디바운스 대신 즉시 검색 (실제 앱에서는 lodash debounce 사용)
      if (text.trim().length > 1) {
        searchPosts(text.trim());
      } else if (text.trim().length === 0) {
        fetchPosts();
      }
    },
    [searchPosts, fetchPosts]
  );

  return (
    <View style={styles.container}>
      <TextInput
        style={styles.input}
        placeholder="포스트 검색..."
        value={query}
        onChangeText={handleSearch}
        autoCapitalize="none"
        returnKeyType="search"
      />

      <FlatList
        data={posts}
        keyExtractor={(item) => String(item.id)}
        renderItem={({ item }) => <PostCard post={item} />}
        contentContainerStyle={styles.list}
        ListEmptyComponent={
          !loading ? (
            <View style={styles.empty}>
              <Text style={styles.emptyText}>
                {query ? '검색 결과가 없습니다' : '검색어를 입력하세요'}
              </Text>
            </View>
          ) : null
        }
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#f5f5f5' },
  input: {
    margin: 16,
    padding: 12,
    backgroundColor: '#fff',
    borderRadius: 10,
    fontSize: 16,
    borderWidth: 1,
    borderColor: '#e0e0e0',
  },
  list: { padding: 16, paddingTop: 0 },
  empty: { padding: 40, alignItems: 'center' },
  emptyText: { color: '#999', fontSize: 15 },
});
```

## Step 6: 동적 라우트 — 상세 화면

Expo Router의 `[id].tsx` 패턴으로 동적 라우트를 만들 수 있어요.

### app/post/[id].tsx

```tsx
import { useEffect, useState } from 'react';
import {
  View,
  Text,
  ScrollView,
  ActivityIndicator,
  StyleSheet,
} from 'react-native';
import { useLocalSearchParams } from 'expo-router';
import { Post } from '../../types/post';
import { getPost } from '../../services/api';

export default function PostDetail() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const [post, setPost] = useState<Post | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (id) {
      getPost(Number(id))
        .then(setPost)
        .finally(() => setLoading(false));
    }
  }, [id]);

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" />
      </View>
    );
  }

  if (!post) {
    return (
      <View style={styles.center}>
        <Text>포스트를 찾을 수 없습니다</Text>
      </View>
    );
  }

  return (
    <ScrollView style={styles.container}>
      <Text style={styles.title}>{post.title}</Text>
      <View style={styles.meta}>
        <Text style={styles.metaText}>작성자 #{post.userId}</Text>
      </View>
      <Text style={styles.body}>{post.body}</Text>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, padding: 20, backgroundColor: '#fff' },
  center: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  title: {
    fontSize: 22,
    fontWeight: '700',
    marginBottom: 12,
    color: '#1a1a1a',
    lineHeight: 30,
  },
  meta: {
    flexDirection: 'row',
    marginBottom: 20,
    paddingBottom: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#f0f0f0',
  },
  metaText: { color: '#999', fontSize: 13 },
  body: { fontSize: 16, lineHeight: 26, color: '#333' },
});
```

## AI 활용 포인트

| 상황 | 프롬프트 예시 |
|------|-------------|
| 네비게이션 설정 | `Expo Router로 탭 + 스택 네비게이션 구조를 설정해줘` |
| 리스트 최적화 | `FlatList에서 리렌더링을 줄이는 방법을 적용해줘. React.memo, getItemLayout 포함` |
| 폼 구현 | `react-hook-form으로 회원가입 폼을 만들어줘. 실시간 검증 포함` |
| 애니메이션 | `Reanimated로 카드 슬라이드 인 애니메이션을 추가해줘` |
| 다크 모드 | `useColorScheme으로 라이트/다크 테마 전환 기능을 만들어줘` |
| 푸시 알림 | `expo-notifications로 로컬 푸시 알림을 설정해줘` |
| 캐싱 | `React Query로 API 응답을 캐싱하고 오프라인에서도 동작하도록 해줘` |

## 모바일 개발에서 AI를 쓸 때 주의할 점

| 문제 | 해결법 |
|------|--------|
| 플랫폼 차이를 무시한 코드 생성 | `Platform.OS`로 분기하거나 플랫폼별 파일(.ios.tsx, .android.tsx) 사용 |
| 과도한 리렌더링 | `React.memo`, `useCallback`, `useMemo`로 최적화 요청 |
| 네이티브 모듈 누락 | Expo SDK에 포함된 패키지를 우선 사용하도록 프롬프트에 명시 |
| 스타일 불일치 | 디바이스별 미리보기를 확인하고 수정 요청 |
| 오래된 API 사용 | "Expo SDK 52 기준으로" 같이 버전을 프롬프트에 명시 |

## 확장 아이디어

이 기본 구조에서 더 발전시킬 수 있는 방향이에요:

- **인증 추가**: `expo-auth-session`으로 Google/Apple 소셜 로그인
- **오프라인 지원**: `@react-native-async-storage/async-storage`로 로컬 캐싱
- **이미지 최적화**: `expo-image`로 캐싱과 블러 플레이스홀더 적용
- **딥링크**: Expo Router의 유니버설 링크 설정으로 웹 URL과 앱 연결
- **앱 배포**: EAS Build로 TestFlight/Play Store 배포 자동화

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
