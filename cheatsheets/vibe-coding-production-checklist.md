# 바이브 코딩 프로덕션 배포 체크리스트

> AI 생성 코드를 프로덕션에 안전하게 올리기 위한 보안·검증·모니터링 체크리스트 — 한 페이지 요약

## 왜 필요한가

2026년 기준 AI 생성 코드는 사람이 작성한 코드보다 15~18% 더 많은 보안 취약점을 포함한다는 분석이 있다. 바이브 코딩은 속도를 주지만, 검증 없이 그대로 배포하면 그 속도가 부채로 돌아온다.

---

## 1. 코드 리뷰 단계

| 항목 | 확인 기준 |
|------|-----------|
| 시크릿 노출 | API 키, 토큰, 패스워드가 코드에 하드코딩되지 않음 |
| SQL 인젝션 | 파라미터화된 쿼리 사용, 문자열 직접 조합 없음 |
| 인증·인가 | 엔드포인트별 인증 미들웨어 적용 확인 |
| CORS 설정 | `*` 와일드카드 허용 없음, 허용 도메인 명시 |
| 에러 메시지 | 스택 트레이스·내부 경로가 응답에 포함되지 않음 |
| 입력값 검증 | 모든 외부 입력에 타입·범위·길이 검증 적용 |

### 2단계 보안 리뷰 패턴

```
1단계: AI에게 기능 구현 요청
2단계: "보안 엔지니어 역할로 이 코드의 취약점을 찾아줘"
       → AI가 스스로 리뷰하게 만들기
```

---

## 2. 자동화 게이트

```yaml
# .github/workflows/ai-code-gate.yml
- name: 시크릿 스캔
  uses: trufflesecurity/trufflehog@main

- name: SAST 분석
  uses: github/codeql-action/analyze@v3
  with:
    languages: python, javascript

- name: 의존성 취약점
  run: npm audit --audit-level=high
       # 또는: pip-audit, cargo audit

- name: 보안 헤더 확인
  run: |
    curl -I $STAGING_URL | grep -E "X-Frame|Content-Security|Strict-Transport"
```

### 필수 게이트 (머지 차단 조건)

- [ ] 시크릿 스캔 통과
- [ ] 고위험 CVE 없음 (CVSS ≥ 7.0)
- [ ] 테스트 커버리지 기준 이상 유지

---

## 3. 스테이징 검증

| 항목 | 방법 |
|------|------|
| 환경 변수 동일성 | 프로덕션과 같은 env flag 사용 여부 |
| 피처 플래그 | 위험 기능에 킬 스위치 준비 |
| 부하 테스트 | AI 생성 쿼리·루프 성능 확인 |
| 외부 서비스 | 실제 API 호출 시나리오 검증 |

```bash
# 스테이징 보안 헤더 자동 체크
CHECKS=("X-Frame-Options" "Content-Security-Policy" "X-Content-Type-Options")
for header in "${CHECKS[@]}"; do
  result=$(curl -s -I $STAGING_URL | grep "$header")
  [ -z "$result" ] && echo "MISSING: $header"
done
```

---

## 4. 배포 시

| 항목 | 체크 |
|------|------|
| 점진적 롤아웃 | 카나리 → 10% → 50% → 100% |
| 기능 플래그 | 문제 발생 시 즉시 비활성화 가능 |
| 롤백 계획 | 이전 버전 즉시 복구 방법 확인 |
| 모니터링 알림 | 배포 후 15분 내 5xx 스파이크 감지 |

---

## 5. 배포 후 모니터링

```yaml
배포 직후 확인 (첫 15분):
  - 인증 에러 급증 없음
  - 5xx 에러율 기준치 이하
  - 응답 시간 정상 범위
  - 메모리·CPU 사용량 이상 없음

배포 후 재스캔:
  - 로컬에서 안전해도 프로덕션 환경(CDN, 빌드 도구)에서 달라질 수 있음
  - 정적 자산 노출 경로 재확인
```

---

## 흔한 실수 & 해결

| 실수 | 해결 |
|------|------|
| AI가 `.env.example`에 실제 값 입력 | `.gitignore`에 `.env` 추가, pre-commit 훅으로 방지 |
| 문자열 직접 이어붙여 SQL 작성 | ORM 또는 파라미터화 쿼리로 교체 |
| CORS `*` 설정 | 허용할 도메인 명시, 와일드카드 제거 |
| 에러 시 전체 스택 반환 | 프로덕션 에러 핸들러에 sanitize 로직 추가 |
| 단순 변경이라 리뷰 스킵 | AI 버그는 단순해 보이는 코드에 숨어있음, 예외 없음 |

---

## 빠른 판단 기준

```
"이 코드를 지금 배포해도 되는가?"

1. 시크릿 노출 없음      → ✅
2. 자동 스캔 통과        → ✅
3. 스테이징 검증 완료    → ✅
4. 롤백 방법 확인        → ✅
5. 모니터링 알림 설정    → ✅

5개 모두 ✅ → 배포 진행
하나라도 ❌ → 해결 후 배포
```

---

**스펙 주도 개발 가이드:** [cheatsheets/spec-driven-development-cheatsheet.md](spec-driven-development-cheatsheet.md)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
