# Codex Settings Template

Codex로 프로젝트를 시작할 때 바로 가져다 쓸 수 있는 설정 템플릿입니다.
`AGENTS.md`, Codex hooks, Git pre-commit hook, 프로젝트 스킬, 단계 실행 스크립트를 한 번에 제공합니다.

## 포함된 구성

- `AGENTS.md`: 프로젝트 규칙, 기술 스택, 작업 방식, 검증 명령을 정의하는 Codex용 루트 지침
- `.codex/config.toml`: Codex hooks 기능 활성화 설정
- `.codex/hooks.json`: Codex 작업 중 위험 명령 차단, TDD guard, 종료 시 프로젝트 체크를 실행하는 hook 설정
- `.codex/hooks/tdd-guard.sh`: Codex hook과 Git pre-commit hook이 함께 사용하는 guard 스크립트
- `.githooks/pre-commit`: 커밋 전에 `lint`, `build`, `test` npm 스크립트를 실행하는 Git hook
- `.agents/skills/harness`: 문서 기반으로 phase/step 작업을 설계하고 실행하는 Harness 스킬
- `.agents/skills/review`: 변경사항을 `AGENTS.md`, 아키텍처 문서, ADR 기준으로 리뷰하는 스킬
- `docs/`: PRD, 아키텍처, ADR
- `scripts/execute.py`: `phases/` 아래 step을 순차 실행하는 Harness runner

## 빠른 시작

1. 이 템플릿을 새 프로젝트에 복사합니다.
2. `AGENTS.md`의 프로젝트명, 기술 스택, CRITICAL 규칙, 명령어를 실제 프로젝트에 맞게 수정합니다.
3. `docs/` 아래 문서를 프로젝트 맥락에 맞게 채웁니다.
4. Git hook 경로를 설정합니다:

```bash
git config core.hooksPath .githooks
```

5. hook 파일 실행 권한을 확인합니다:

```bash
chmod +x .githooks/pre-commit .codex/hooks/tdd-guard.sh
```

## Commit Hook 동작

커밋 전 `.githooks/pre-commit`이 `.codex/hooks/tdd-guard.sh git-pre-commit`을 호출합니다.

- `package.json`이 없으면 통과합니다.
- `package.json`이 있으면 `scripts.lint`, `scripts.build`, `scripts.test` 중 존재하는 스크립트만 순서대로 실행합니다.
- 실패한 스크립트가 있으면 커밋을 중단하고 해당 output을 출력합니다.
- 없는 스크립트는 실패로 보지 않고 건너뜁니다.

## Codex Hooks

`.codex/hooks.json`은 다음 guard를 제공합니다.

- `PreToolUse`: 위험 명령과 테스트 없는 구현 변경을 차단합니다.
- `PermissionRequest`: 위험 명령 승인 요청을 거부합니다.
- `Stop`: 작업 종료 시 프로젝트 체크를 실행합니다.

현재 hook script는 npm 기반 프로젝트를 기본값으로 가정합니다. 다른 패키지 매니저를 쓰는 프로젝트에서는 `.codex/hooks/tdd-guard.sh`의 `run_npm_checks`를 프로젝트 명령에 맞게 바꾸면 됩니다.

## Harness Workflow

Harness 스킬은 큰 작업을 `phases/{task-name}/step{N}.md` 파일들로 나누고, `scripts/execute.py`로 각 step을 순차 실행하는 흐름을 지원합니다.

```bash
python3 scripts/execute.py {task-name}
python3 scripts/execute.py {task-name} --push
```

각 step은 독립적인 Codex 실행 단위로 작성하고, 완료 시 `phases/{task-name}/index.json`의 상태와 summary를 업데이트합니다.

