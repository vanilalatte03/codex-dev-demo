# Codex Project Ops Template

Codex 기반 개인 프로젝트 운영 템플릿입니다. 이 레포는 Spring Boot, Python,
Node 앱 코드를 직접 생성하지 않습니다. 대신 프로젝트 시작 폴더에 Codex 운영
레이어를 설치하고, Plan Mode로 확정한 MVP 범위와 기술 스택을 문서화한 뒤,
Harness skill로 phase 단위 구현, 테스트, 리뷰를 반복하는 흐름을 제공합니다.

## 포함된 구성

- `AGENTS.md`: Codex가 따르는 100줄 안팎의 프로젝트 운영 규칙
- `docs/PRD.md`: MVP 범위와 완료 기준
- `docs/ARCHITECTURE.md`: 구조, 데이터 흐름, 경계
- `docs/ADR.md`: 기술 결정 기록과 ADR 분리 규칙
- `docs/COMMANDS.md`: dev, lint, test, build, review 명령의 단일 출처
- `.codex/hooks.json`: Codex tool hook 설정
- `.codex/hooks/tdd-guard.sh`: Git/Codex hook wrapper
- `.codex/project-profile.json`: guard 모드와 명령 설정
- `.githooks/pre-commit`: 커밋 전 검증 hook
- `.agents/skills/harness`: phase/step 설계와 실행 워크플로우
- `.agents/skills/review`: 문서와 규칙 기준 자체 리뷰 워크플로우
- `scripts/execute.py`: phase step 실행기
- `scripts/checks.py`: 프로젝트 명령 감지 및 실행
- `scripts/doctor.py`: 템플릿 설치 상태 점검
- `scripts/guard.py`: 위험 명령, TDD, pre-commit/stop 정책
- `issues/README.md`: phase 실패 기록 형식

## 시작 절차

1. 프로젝트 폴더에 이 템플릿을 가져옵니다.
2. Git hook 경로와 실행 권한을 설정합니다.

```bash
git config core.hooksPath .githooks
chmod +x .githooks/pre-commit .codex/hooks/tdd-guard.sh
```

3. Codex Plan Mode를 3~5회 사용해 MVP 범위, 기술 스택, 아키텍처, 명령어,
   완료 기준을 확정합니다.
4. 확정 내용을 `AGENTS.md`, `docs/PRD.md`, `docs/ARCHITECTURE.md`,
   `docs/ADR.md`, `docs/COMMANDS.md`에 반영합니다.
5. 설치 상태를 확인합니다.

```bash
python3 scripts/doctor.py
```

## 운영 흐름

1. Harness skill로 MVP를 `phases/{phase}/index.json`과 `stepN.md`로 나눕니다.
2. phase를 실행합니다.

```bash
python3 scripts/execute.py {phase-name}
python3 scripts/execute.py {phase-name} --push
```

3. 각 step은 별도 브랜치에서 구현, 테스트, 빌드, 상태 갱신, 커밋을 수행합니다.
4. review skill로 아키텍처, ADR, 테스트, CRITICAL 규칙, 빌드 가능 여부를 확인합니다.
5. 통과하지 못하면 `issues/{phase}/issue-N.md`를 만들고 fix step을 추가합니다.
6. 통과하면 phase를 completed로 처리하고 다음 phase로 이동합니다.

## Guard 모드

기본 guard는 soft입니다. 위험 명령은 항상 차단하지만, 테스트 파일 누락이나
검증 실패는 경고로 남기고 흐름을 막지 않습니다. 프로젝트 구조와 검증 명령이
안정되면 `.codex/project-profile.json`의 `guardMode`를 `hard`로 바꿔 차단
모드로 전환합니다.

```json
{
  "guardMode": "soft"
}
```

## 템플릿 자체 테스트

`docs/COMMANDS.md`와 `.codex/project-profile.json`의 `dev`, `lint`, `test`,
`build` 명령은 이 템플릿을 복사한 대상 프로젝트에서 채웁니다. 템플릿 레포
자체의 Python 스크립트 테스트를 실행할 때만 dev 의존성을 설치합니다.

```bash
python3 -m pip install -r requirements-dev.txt
python3 -m pytest scripts
```

## 명령 관리

`docs/COMMANDS.md`가 실행 명령의 단일 출처입니다. `scripts/checks.py`는 먼저
`.codex/project-profile.json`의 명령을 보고, 없으면 `docs/COMMANDS.md`, 그 다음
프로젝트 manifest를 감지합니다.

지원하는 감지 대상:

- Spring Boot: `gradlew`, `build.gradle`, `pom.xml`, `mvnw`
- Python: `pyproject.toml`, `uv.lock`, `pytest`, `ruff`
- Node: `package.json`, `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`

## ADR 규칙

- ADR 1~3개는 `docs/ADR.md`에 기록합니다.
- 4번째 ADR이 생기면 `docs/adr/0001-title.md` 형식으로 분리합니다.
- 분리 후 `docs/ADR.md`는 ADR 인덱스와 운영 규칙만 유지합니다.
