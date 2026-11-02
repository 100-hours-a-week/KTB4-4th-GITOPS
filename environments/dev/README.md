# Dev Values 초안

이 파일들은 11/2 구조 초안이며 아직 EKS에 적용하지 않습니다. Image 주소·Digest, Secret 이름, Probe 경로와 자원 요청량을 확인한 뒤 각 Workload의 `enabled: true`를 설정합니다.

Dev는 2 AZ입니다. Production의 Replica 3개·3 AZ 분산 설정을 그대로 복사하지 않습니다.

Backend API 네 개는 같은 Spring Image를 사용하므로 렌더링 시 `backend-image.yaml`을 먼저, 각 API Values를 뒤에 전달합니다. AI FastAPI는 별도 Image입니다. `ai-worker`는 Stream 소비 코드가 준비되기 전까지 비활성화합니다.

예시:

```bash
helm template auth-api charts/application \
  -f environments/dev/backend-image.yaml \
  -f environments/dev/auth-api.yaml \
  --set enabled=true \
  --set image.repository=example.invalid/needu-backend \
  --set image.tag=dev
```

위 `example.invalid` 주소는 렌더링 확인 전용이며 실제 배포에 사용할 수 없습니다.
