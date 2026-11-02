# ServiceAccount 범위

ServiceAccount는 팀이나 Deployment 수가 아니라 필요한 권한과 외부 신원에 따라 나눕니다. 현재 애플리케이션 코드를 기준으로 다음 신원을 사용합니다.

| ServiceAccount | Namespace | 사용할 Workload | 판단 |
| --- | --- | --- | --- |
| `frontend` | `frontend` | Frontend | Backend와 Namespace가 다름. 현재 런타임 AWS SDK 호출은 확인되지 않음 |
| `backend-api` | `backend` | Auth·Recommendation·Social·AI API, 초기 AI Worker | 같은 Spring Image이며 도메인별 AWS 권한 차이는 확인되지 않음 |
| `ai-fastapi` | `backend` | AI FastAPI | V3 GCP Workload Identity Federation의 독립 신원 |

AI Worker가 별도 AWS·Kubernetes API 권한을 필요로 하거나 Secret 접근 범위를 분리해야 하면 `ai-worker` ServiceAccount를 추가합니다. AI 상품 카탈로그 Batch의 S3 권한은 배포 방식이 확정될 때 별도 ServiceAccount로 검토합니다. Helm은 Deployment별 `serviceAccount.name` 변경을 지원합니다.

이 파일의 ServiceAccount 생성은 GitOps가 담당합니다. AWS IAM Role·Policy와 EKS Pod Identity Association은 CLOUD 저장소의 Terraform에서 관리합니다. ServiceAccount를 만들었다고 AWS 권한이 자동 부여되지는 않습니다. Kubernetes API 토큰 자동 마운트 제한은 Pod Identity와 GCP WIF 구성이 확인된 뒤 Workload별로 적용합니다.
