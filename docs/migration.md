# 기존 WSL 코드에서 모듈 구조로 전환

## 이번 변경

- VPC는 기존 `module.vpc` 주소를 유지하고 내부 파일을 역할별로 분리했습니다.
- 루트 EKS 리소스 13개는 `module.eks`로 이동했습니다.
- 루트 RDS 리소스 3개는 `module.rds`로 이동했습니다.
- 총 16개의 `moved` 블록이 이전 주소와 새 주소를 연결합니다.
- 리소스 이름, CIDR, 태그, 노드 수, DB 설정, 애드온 의존 관계를 보존했습니다.
- 루트 output은 network / eks / postgres로 정리했습니다.
- DB 보안 그룹 허용 목록은 빈 값이 기본이며, 현재 주석 처리되어 있던 규칙과 같은 동작입니다.

`moved`는 같은 state 안에서 주소를 옮기는 선언입니다. AWS에 있지만 현재 state에 없는 리소스를 등록하지는 않습니다.
주소 이동은 검토한 plan을 apply할 때 state에 기록됩니다. 코드 변경만으로 원격 state는 바뀌지 않습니다.
검토 전에 `state mv`, `state rm`, `import`, `apply`를 자동 실행하지 않습니다.

## 기준 plan의 기존 변경

2026-09-09 리팩터링 전 코드를 `plan -refresh=false -lock=false`로 확인했을 때 이미 `17 to add, 0 to change, 0 to destroy`였습니다.
public 서브넷, 노드 그룹, 일부 애드온 등이 생성 대상으로 포함되어 있습니다.
이것만으로 기존 AWS 리소스가 삭제되었거나 다른 state에 있다고 단정할 수는 없습니다.
실제 반영 전에는 현재 AWS 목록·선택한 계정·backend·workspace와 state를 대조해야 합니다.
`-refresh=false` 비교는 저장된 state를 기준으로 리팩터링 차이를 확인하는 검사이며 실시간 AWS drift 검사가 아닙니다.

검사 도중 원격 state serial이 16에서 18로 바뀌고 관리 중인 리소스 인스턴스가 17개에서 6개로 줄었습니다.
따라서 서로 다른 시점의 원격 plan을 직접 비교하지 않고, 첫 plan에 포함된 동일 state를 임시 로컬 backend 두 곳에 복제하여 비교했습니다.
비교 결과는 `verification.json`에 기록합니다. 이 코드 작업에서는 원격 state에 쓰거나 AWS 리소스를 생성·삭제하지 않았습니다.

작업 중 사용자가 원본 rds.tf의 deletion_protection을 true에서 false로 수정한 것을 확인해 최종 환경값에도 반영했습니다.
최종 비교는 이 최신 원본과 새 구조를 같은 초기 state로 비교합니다. 따라서 기존 기준 plan과 달리 DB 삭제 보호 변경 1개가 포함될 수 있으며, 구조 이동이 추가한 변경은 아닙니다.

## 반영 순서

1. 원본 코드 백업과 현재 미커밋 변경을 보존합니다. 두 사람이 같은 state를 동시에 적용하지 않도록 작업 시간을 조정합니다.
2. 기존 `.git`, `.terraform`, lock 파일과 backend 설정을 유지한 채 새 소스를 넣습니다.
3. `terraform init -lockfile=readonly -backend-config=backend-infra.hcl`로 새 로컬 모듈을 등록합니다. `-upgrade`나 `-migrate-state`는 필요 없습니다.
4. `terraform fmt -check -recursive`와 `terraform validate`를 실행합니다.
5. `terraform workspace show`, `terraform state list`로 대상 확인 후 일반 `terraform plan -out=review.tfplan`을 실행합니다.
6. 이동 메시지와 AWS 리소스 변경을 구분해 검토합니다. 이전에 존재하는 리소스가 생성 대상으로 나오면 실제 위치를 먼저 확인합니다.
7. 검토를 마친 plan만 apply합니다. 이때 주소 이동도 함께 저장됩니다.

## 되돌리기

원격 state에 새 구조를 apply하기 전이라면 백업한 코드를 복원하고 init/plan으로 확인할 수 있습니다.
apply한 뒤에는 state가 새 주소를 사용합니다. 이전 코드만 덮어쓰지 말고 역방향 주소 이동을 설계해 별도로 검토하세요.
state 백업으로 현재 state를 무조건 덮어쓰는 방식은 이후 변경을 잃을 수 있습니다.

리팩터링 이후에도 `moved.tf`를 유지하면 오래된 state를 사용하는 환경이 같은 이동 경로를 따라갈 수 있습니다.
