# ServiceAccount 범위

ServiceAccount는 팀이나 Deployment 수가 아니라 필요한 권한과 외부 신원에 따라 나눕니다. 현재 애플리케이션 코드를 기준으로 다음 신원을 사용합니다.

| ServiceAccount | Namespace | 사용할 Workload | 판단 |
| --- | --- | --- | --- |
| `frontend` | `frontend` | Frontend | Backend와 Namespace가 다름. 현재 런타임 AWS SDK 호출은 확인되지 않음 |
| `auth-api` | `backend` | Auth API | Deployment별 실행 신원 분리. 추가 Kubernetes·AWS 권한 없음 |
| `recommendation-api` | `backend` | Recommendation API | Deployment별 실행 신원 분리. 추가 Kubernetes·AWS 권한 없음 |
| `social-api` | `backend` | Social API | Deployment별 실행 신원 분리. 추가 Kubernetes·AWS 권한 없음 |
| `ai-api` | `backend` | AI API | Deployment별 실행 신원 분리. 추가 Kubernetes·AWS 권한 없음 |
| `ai-fastapi` | `backend` | AI FastAPI | V3 GCP Workload Identity Federation의 독립 신원 |

Backend API는 Kubernetes API를 직접 사용하지 않으므로 ServiceAccount Token 자동 마운트를 끄고, Role·RoleBinding을 연결하지 않습니다. AWS 권한이 필요해지면 해당 ServiceAccount에만 EKS Pod Identity를 연결합니다.

AI Worker가 별도 AWS·Kubernetes API 권한을 필요로 하면 `ai-worker` ServiceAccount를 추가합니다. AI 상품 카탈로그 Batch의 S3 권한은 배포 방식이 확정될 때 별도 ServiceAccount로 검토합니다. Helm은 Deployment별 `serviceAccount.name` 변경을 지원합니다.

이 파일의 ServiceAccount 생성은 GitOps가 담당합니다. AWS IAM Role·Policy와 EKS Pod Identity Association은 CLOUD 저장소의 Terraform에서 관리합니다. ServiceAccount를 만들었다고 AWS 권한이 자동 부여되지는 않습니다. GCP WIF를 사용하는 `ai-fastapi`는 기존 Token 구성을 유지합니다.
