#!/usr/bin/env bash
# SessionStart hook: prints the CEO summary when the repo enables the banner.
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
[ "$(jq -r '.banner // false' .claude/mobilities.json 2>/dev/null)" = true ] || exit 0
NO_COLOR=1 "$HERE/ceo.sh" --once 2>&1 | jq -Rs '{systemMessage: .}'
