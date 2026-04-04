# AI 에이전트 기반 스마트 계약 감사 도구

> Solidity 코드를 넣으면 취약점 리포트가 나오는 CLI — AI 에이전트로 처음부터 직접 만들어보기

## 이 예제에서 배울 수 있는 것

- AI 에이전트에게 보안 분석 도구를 설계시키는 프롬프트 패턴
- Solidity AST 파싱과 취약점 탐지 로직을 AI로 구현하는 워크플로우
- 알려진 취약점 패턴(reentrancy, overflow, access control)을 룰 엔진으로 코드화하는 방법
- CLI 도구의 리포트 출력과 CI 연동까지 한 번에 만드는 실전 프로세스

## 프로젝트 구조

```
ai-smart-contract-auditor/
├── CLAUDE.md                  # AI 에이전트 컨텍스트
├── src/
│   └── solaudit/
│       ├── __init__.py
│       ├── main.py            # CLI 엔트리포인트
│       ├── parser.py          # Solidity 파일 파싱 (AST 변환)
│       ├── rules/
│       │   ├── __init__.py
│       │   ├── reentrancy.py  # 재진입 공격 탐지
│       │   ├── overflow.py    # 정수 오버플로우 검사
│       │   ├── access.py      # 접근 제어 취약점
│       │   ├── gas.py         # 가스 최적화 이슈
│       │   └── custom.py      # 사용자 정의 룰
│       ├── reporter.py        # 리포트 생성 (터미널/JSON/MD)
│       ├── severity.py        # 심각도 분류 (Critical/High/Medium/Low)
│       └── config.py          # 설정 관리
├── tests/
│   ├── contracts/             # 테스트용 취약한 계약
│   │   ├── vulnerable.sol
│   │   └── safe.sol
│   ├── test_parser.py
│   ├── test_rules.py
│   └── conftest.py
├── pyproject.toml
└── README.md
```

## 만들 도구: solaudit

Solidity 스마트 계약 파일을 정적 분석해서 보안 취약점을 찾아내는 CLI 도구예요. Mythril이나 Slither 같은 도구의 경량 버전을 AI 에이전트로 직접 만들어보는 프로젝트입니다.

```bash
# 사용 예시
solaudit scan contracts/Token.sol          # 단일 파일 감사
solaudit scan contracts/ --recursive       # 디렉토리 전체 스캔
solaudit scan contracts/Token.sol -o json  # JSON 리포트 출력
solaudit scan contracts/Token.sol -o md    # 마크다운 리포트
solaudit rules --list                      # 적용 가능한 룰 목록
solaudit rules --enable gas               # 특정 룰 활성화
```

## 시작하기

### Step 1: 프로젝트 초기화 프롬프트

프로젝트의 전체 구조와 핵심 의존성을 먼저 잡아요.

```
Python CLI 도구를 만들어줘.

- 이름: solaudit
- 기능: Solidity 스마트 계약 파일을 정적 분석해서 보안 취약점을 탐지
- 기술 스택: Python 3.12+, Click (CLI), Rich (터미널 UI), solidity-parser (AST)
- 구조: src/solaudit/ 하위에 모듈 분리
- 룰 엔진: rules/ 디렉토리에 취약점 패턴별 모듈
- 리포트 포맷: 터미널 테이블, JSON, Markdown 3가지 지원
- pyproject.toml로 패키징, pytest로 테스트

먼저 프로젝트 구조만 생성하고, 각 파일에 docstring과 주요 인터페이스를 정의해줘.
```

이 프롬프트의 핵심:
- **룰 엔진 구조를 미리 설계**해서 취약점 패턴을 모듈로 분리
- 리포트 포맷을 3가지로 지정해서 CI 연동과 개발자 확인 모두 커버
- 파싱 레이어를 분리해서 Solidity 버전 변경에도 유연하게 대응

### Step 2: CLAUDE.md로 보안 컨텍스트 설정

AI 에이전트가 보안 도메인을 정확히 이해하도록 컨텍스트를 작성해요.

```markdown
# solaudit — Solidity 스마트 계약 보안 감사 CLI

## 기술 스택
- Python 3.12+, Click, Rich, solidity-parser
- 테스트: pytest + pytest-cov
- 포맷: ruff (lint + format)

## 보안 도메인 규칙
- OWASP Smart Contract Top 10 기준으로 룰 설계
- 각 취약점에 CWE ID 매핑 (예: Reentrancy → CWE-841)
- 심각도: Critical > High > Medium > Low > Informational
- False positive 최소화 — 확실한 패턴만 탐지, 의심 사항은 Info로 분류

## 코드 규칙
- 모든 룰은 BaseRule 클래스를 상속
- 룰 추가 시 tests/contracts/에 취약한 계약 예제 포함 필수
- 리포트는 터미널 기본, --output json|md 옵션으로 전환
```

### Step 3: Solidity 파서 구현

AST 파싱은 도구의 기반이에요. AI 에이전트에게 파서부터 만들도록 지시해요.

```
src/solaudit/parser.py를 구현해줘.

요구사항:
1. solidity-parser 라이브러리로 .sol 파일을 AST로 변환
2. 컨트랙트, 함수, 상태 변수, modifier를 추출하는 메서드
3. import 문 해석해서 의존성 그래프 구축
4. 파싱 에러 시 위치 정보(줄 번호, 컬럼)와 함께 에러 메시지 반환
5. 여러 파일을 한번에 파싱하는 batch 모드 지원

solidity-parser가 반환하는 AST 노드 구조를 먼저 확인하고, 
타입 힌트를 붙여서 구현해줘.
```

## 핵심 코드

### 룰 엔진 베이스 클래스

```python
from abc import ABC, abstractmethod
from dataclasses import dataclass
from enum import Enum

class Severity(Enum):
    CRITICAL = "critical"
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"
    INFO = "informational"

@dataclass
class Finding:
    rule_id: str
    title: str
    severity: Severity
    description: str
    line: int
    column: int
    snippet: str
    recommendation: str
    cwe_id: str | None = None

class BaseRule(ABC):
    """모든 감사 룰의 베이스 클래스"""
    
    @property
    @abstractmethod
    def rule_id(self) -> str: ...
    
    @property
    @abstractmethod
    def title(self) -> str: ...
    
    @property
    @abstractmethod
    def severity(self) -> Severity: ...
    
    @abstractmethod
    def check(self, ast_node: dict, context: dict) -> list[Finding]:
        """AST 노드를 분석해서 취약점 목록을 반환"""
        ...
```

**왜 이렇게 했나요?**

각 취약점 패턴을 독립 모듈로 분리하면, 새 룰을 추가할 때 기존 코드를 건드릴 필요가 없어요. `BaseRule`을 상속받아 `check()` 메서드만 구현하면 자동으로 스캐너에 등록돼요.

### 재진입 공격 탐지 룰

```python
class ReentrancyRule(BaseRule):
    """외부 호출 후 상태 변경 패턴을 탐지"""
    
    rule_id = "SOL-001"
    title = "Reentrancy Vulnerability"
    severity = Severity.CRITICAL
    
    def check(self, ast_node: dict, context: dict) -> list[Finding]:
        findings = []
        
        for func in context.get("functions", []):
            external_calls = self._find_external_calls(func)
            state_changes = self._find_state_changes(func)
            
            for call in external_calls:
                # 외부 호출 이후에 상태 변경이 있으면 위험
                later_changes = [
                    sc for sc in state_changes 
                    if sc["line"] > call["line"]
                ]
                
                if later_changes:
                    findings.append(Finding(
                        rule_id=self.rule_id,
                        title=self.title,
                        severity=self.severity,
                        description=(
                            f"함수 `{func['name']}`에서 외부 호출(line {call['line']}) "
                            f"이후 상태 변경(line {later_changes[0]['line']})이 감지됐어요. "
                            f"재진입 공격에 취약할 수 있어요."
                        ),
                        line=call["line"],
                        column=call.get("column", 0),
                        snippet=call.get("source", ""),
                        recommendation=(
                            "Checks-Effects-Interactions 패턴을 적용하세요. "
                            "외부 호출 전에 모든 상태 변경을 완료하거나, "
                            "ReentrancyGuard modifier를 사용하세요."
                        ),
                        cwe_id="CWE-841"
                    ))
        
        return findings
    
    def _find_external_calls(self, func: dict) -> list[dict]:
        """call, send, transfer 등 외부 호출 탐지"""
        patterns = ["call", "send", "transfer", "delegatecall"]
        # AST에서 MemberAccess 노드 중 패턴 매칭
        return [
            node for node in func.get("body_nodes", [])
            if node.get("type") == "MemberAccess"
            and node.get("member") in patterns
        ]
    
    def _find_state_changes(self, func: dict) -> list[dict]:
        """상태 변수 변경 탐지"""
        state_vars = func.get("contract_state_vars", set())
        return [
            node for node in func.get("body_nodes", [])
            if node.get("type") == "Assignment"
            and node.get("left", {}).get("name") in state_vars
        ]
```

### 스캔 엔진

```python
from pathlib import Path
from solaudit.parser import SolidityParser
from solaudit.rules import get_all_rules

class Scanner:
    """Solidity 파일을 스캔하고 모든 룰을 적용"""
    
    def __init__(self, enabled_rules: list[str] | None = None):
        self.parser = SolidityParser()
        all_rules = get_all_rules()
        
        if enabled_rules:
            self.rules = [r for r in all_rules if r.rule_id in enabled_rules]
        else:
            self.rules = all_rules
    
    def scan_file(self, path: Path) -> list[Finding]:
        """단일 .sol 파일 스캔"""
        ast = self.parser.parse_file(path)
        context = self.parser.extract_context(ast)
        
        findings = []
        for rule in self.rules:
            findings.extend(rule.check(ast, context))
        
        # 심각도 순으로 정렬
        findings.sort(key=lambda f: list(Severity).index(f.severity))
        return findings
    
    def scan_directory(self, path: Path, recursive: bool = True) -> dict:
        """디렉토리 내 모든 .sol 파일 스캔"""
        pattern = "**/*.sol" if recursive else "*.sol"
        results = {}
        
        for sol_file in path.glob(pattern):
            results[str(sol_file)] = self.scan_file(sol_file)
        
        return results
```

### 리포트 생성 (터미널 출력)

```python
from rich.console import Console
from rich.table import Table
from rich.panel import Panel

SEVERITY_COLORS = {
    Severity.CRITICAL: "red bold",
    Severity.HIGH: "red",
    Severity.MEDIUM: "yellow",
    Severity.LOW: "blue",
    Severity.INFO: "dim",
}

def print_terminal_report(findings: list[Finding], file_path: str):
    """Rich 테이블로 감사 결과를 터미널에 출력"""
    console = Console()
    
    if not findings:
        console.print(
            Panel("[green]취약점이 발견되지 않았어요[/green]", 
                  title=file_path)
        )
        return
    
    table = Table(title=f"감사 결과: {file_path}")
    table.add_column("심각도", width=10)
    table.add_column("룰", width=10)
    table.add_column("위치", width=8)
    table.add_column("설명", ratio=1)
    
    for f in findings:
        color = SEVERITY_COLORS[f.severity]
        table.add_row(
            f"[{color}]{f.severity.value.upper()}[/{color}]",
            f.rule_id,
            f"L{f.line}",
            f.description[:80],
        )
    
    console.print(table)
    
    # 요약 통계
    stats = {}
    for f in findings:
        stats[f.severity.value] = stats.get(f.severity.value, 0) + 1
    
    summary = " | ".join(
        f"[{SEVERITY_COLORS[Severity(k)]}]{k}: {v}[/{SEVERITY_COLORS[Severity(k)]}]"
        for k, v in stats.items()
    )
    console.print(f"\n총 {len(findings)}개 이슈 발견 — {summary}")
```

## AI 활용 포인트

| 상황 | 프롬프트 예시 |
|------|-------------|
| 새 취약점 룰 추가 | `SOL-005 룰을 만들어줘. tx.origin 인증 우회 패턴 탐지. tests/contracts/에 취약한 계약 예제도 추가해줘.` |
| 리포트 포맷 확장 | `SARIF 포맷 리포터를 추가해줘. GitHub Security 탭에서 볼 수 있도록.` |
| CI 연동 | `GitHub Actions 워크플로우를 만들어줘. PR에 .sol 파일이 포함되면 solaudit를 실행하고, 결과를 PR 코멘트로 남기도록.` |
| 커스텀 룰 작성 | `우리 프로젝트 규칙에 맞는 커스텀 룰을 만들고 싶어. .solaudit.yaml에서 룰 정의를 읽어서 동적으로 적용하도록 해줘.` |
| False positive 줄이기 | `reentrancy 룰에서 ReentrancyGuard가 적용된 함수는 제외하도록 개선해줘.` |

## 주요 취약점 패턴 레퍼런스

| 룰 ID | 취약점 | 심각도 | CWE |
|--------|--------|--------|-----|
| SOL-001 | Reentrancy (재진입 공격) | Critical | CWE-841 |
| SOL-002 | Integer Overflow/Underflow | High | CWE-190 |
| SOL-003 | Unprotected Access Control | High | CWE-284 |
| SOL-004 | Unchecked Return Value | Medium | CWE-252 |
| SOL-005 | tx.origin Authentication | Medium | CWE-477 |
| SOL-006 | Gas Limit DoS | Medium | CWE-400 |
| SOL-007 | Floating Pragma | Low | — |
| SOL-008 | Unused State Variable | Low | — |

## 확장 아이디어

- **AI 보조 분석**: 정적 분석으로 의심 구간을 찾고, AI 에이전트에게 컨텍스트와 함께 분석을 요청하는 하이브리드 방식
- **DeFi 특화 룰**: flash loan 공격, price oracle 조작, front-running 패턴 등 DeFi 프로토콜 특화 룰셋
- **자동 수정 제안**: 취약점 발견 시 패치 코드를 AI가 생성해서 함께 제시
- **실시간 모니터링**: Hardhat/Foundry 개발 서버와 연동해서 코드 저장 시 자동 스캔

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
