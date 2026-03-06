#!/bin/bash
# ──────────────────────────────────────────────
# 텐빌더 스킬 설치
# https://github.com/ten-builder/ten-builder
# ──────────────────────────────────────────────

set -euo pipefail

SKILLS_DIR="${HOME}/.claude/skills"
AGENTS_DIR="${HOME}/.claude/agents"
REPO_URL="https://raw.githubusercontent.com/ten-builder/ten-builder/main/skills"

echo ""
echo "📚 텐빌더 스킬을 설치합니다"
echo "──────────────────────────────────"
echo ""

# ─── 학습 스킬 ─────────────────────────────

mkdir -p "${SKILLS_DIR}/study-vault/references"
mkdir -p "${SKILLS_DIR}/study-quiz/references"

echo "⬇️  study-vault (교재 → 학습 노트 변환)..."
curl -fsSL "${REPO_URL}/study-vault/SKILL.md" -o "${SKILLS_DIR}/study-vault/SKILL.md"
curl -fsSL "${REPO_URL}/study-vault/references/vault-templates.md" -o "${SKILLS_DIR}/study-vault/references/vault-templates.md"
curl -fsSL "${REPO_URL}/study-vault/references/codebase-guide.md" -o "${SKILLS_DIR}/study-vault/references/codebase-guide.md"
curl -fsSL "${REPO_URL}/study-vault/references/quality-check.md" -o "${SKILLS_DIR}/study-vault/references/quality-check.md"

echo "⬇️  study-quiz (대화형 퀴즈 + 숙달도 추적)..."
curl -fsSL "${REPO_URL}/study-quiz/SKILL.md" -o "${SKILLS_DIR}/study-quiz/SKILL.md"
curl -fsSL "${REPO_URL}/study-quiz/references/quiz-policy.md" -o "${SKILLS_DIR}/study-quiz/references/quiz-policy.md"

# ─── 세션 관리 스킬 ────────────────────────

echo "⬇️  session-pack (세션 종료 시 자동 기록)..."

# Skill
mkdir -p "${SKILLS_DIR}/session-pack/references"
curl -fsSL "${REPO_URL}/session-pack/SKILL.md" -o "${SKILLS_DIR}/session-pack/SKILL.md"
curl -fsSL "${REPO_URL}/session-pack/references/handoff-template.md" -o "${SKILLS_DIR}/session-pack/references/handoff-template.md"

# Agents (→ ~/.claude/agents/)
mkdir -p "${AGENTS_DIR}"
curl -fsSL "${REPO_URL}/session-pack/agents/memory-extractor.md" -o "${AGENTS_DIR}/session-pack-memory-extractor.md"
curl -fsSL "${REPO_URL}/session-pack/agents/followup-planner.md" -o "${AGENTS_DIR}/session-pack-followup-planner.md"
curl -fsSL "${REPO_URL}/session-pack/agents/duplicate-checker.md" -o "${AGENTS_DIR}/session-pack-duplicate-checker.md"

# Handoff 디렉토리 생성
mkdir -p "${HOME}/.claude/handoff"

echo ""
echo "✅ 설치 완료!"
echo ""
echo "사용법:"
echo "  /study-vault   → PDF/문서를 학습 노트로 변환"
echo "  /study-quiz    → 대화형 퀴즈로 학습"
echo "  /pack          → 세션 종료 시 Memory/Handoff 자동 정리"
echo ""
echo "──────────────────────────────────"
echo "📮 더 많은 AI 코딩 팁: maily.so/tenbuilder"
echo "🎬 영상으로 보기: youtube.com/@ten-builder"
echo "──────────────────────────────────"
