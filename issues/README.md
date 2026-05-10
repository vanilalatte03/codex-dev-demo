# Phase Issues

phase 검증 또는 리뷰가 통과하지 못하면 이 디렉터리에 실패 기록을 남깁니다.

파일 경로:

```text
issues/{phase-name}/issue-N.md
```

권장 형식:

````markdown
# Issue N: <짧은 제목>

## 발생 위치
- Phase: <phase-name>
- Step: <step-number 또는 review>

## 재현 명령
```bash
<실패한 명령>
```

## 핵심 에러
<가장 중요한 에러 메시지 또는 관찰 결과>

## 수정 방향
- <fix step에서 처리할 작업>

## 완료 기준
- <수정 후 통과해야 할 명령 또는 리뷰 기준>
````
