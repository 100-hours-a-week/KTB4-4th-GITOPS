# RBAC 범위

| 대상 | 범위 | 원칙 |
| --- | --- | --- |
| FE 배포 주체 | `frontend` Namespace | FE Workload만 변경 |
| BE·AI 배포 주체 | `backend` Namespace | 담당 Workload만 변경 |
| 플랫폼 팀 | 플랫폼 설정과 Cluster 관리 | Namespace, Ingress, NetworkPolicy 등 공통 리소스 관리 |

실제 GitHub 사용자와 Kubernetes 인증 주체의 매핑이 정해지면 Role·RoleBinding을 작성합니다. 사용자 이름이나 그룹을 추정해 권한을 부여하지 않습니다. Argo CD의 배포 권한도 AppProject 및 저장소 권한과 함께 설계합니다.
