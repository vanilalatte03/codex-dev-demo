# Commands

이 파일은 프로젝트 실행 명령의 단일 출처입니다. Plan Mode에서 기술 스택을
확정한 뒤 실제 명령으로 채웁니다. 비어 있는 명령은 실행하지 않습니다.

## 활성 명령

| 이름 | 명령 | 필수 | 설명 |
| --- | --- | --- | --- |
| dev |  | no | 개발 서버 또는 watch 실행 |
| lint |  | no | 정적 분석과 포맷 검사 |
| test |  | yes | 자동 테스트 |
| build |  | yes | 배포 가능한 빌드 또는 패키징 |
| review | `python3 scripts/doctor.py` | no | 템플릿과 프로젝트 운영 상태 점검 |
| phase | `python3 scripts/execute.py <phase-name>` | no | Harness phase 실행 |

## 기술별 예시

```bash
# Spring Boot - Gradle
./gradlew test
./gradlew build

# Spring Boot - Maven
./mvnw test
./mvnw package

# Python
uv run pytest
uv run ruff check .
python -m pytest

# Node
npm run lint
npm test
npm run build
pnpm test
yarn test
```
