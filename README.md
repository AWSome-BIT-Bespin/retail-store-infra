# retail-store-infra

현재 AWS에 있는 retail-vpc 네트워크를 표현한 Terraform 코드입니다.
코드 작성과 로컬 검증까지만 진행했으며, 기존 AWS 리소스의 import 및 apply는 실행하지 않았습니다.

## 대상 환경

- AWS 계정: 350606136784
- 리전: ap-northeast-2
- VPC: retail-vpc (`vpc-01d8242dcf61cada6`, `10.0.0.0/16`)
- Workspace: default
- S3 bucket: `retail-terraform-state-350606136784-ap-northeast-2-an`
- Dev state key: `infra/dev/terraform.tfstate` (`backend-dev.hcl`)
- 검증 환경: Terraform 1.16.1, AWS provider 6.62.0 (`.terraform.lock.hcl`)

이 코드는 현재 dev 리소스를 기준으로 작성했습니다.
`backend-infra.hcl`은 `infra/prod/terraform.tfstate`를 가리키지만,
backend 파일을 바꾸는 것만으로 리소스 이름, CIDR, 환경이 prod로 전환되지는 않습니다.
이 dev import 예제를 다른 state에 사용하지 마세요.

## 코드에 반영한 기존 구성

- Public 서브넷 2개는 VPC 기본 라우팅 테이블을 암묵적으로 사용합니다.
  기본 인터넷 경로는 IGW를 가리키며, 별도 public 라우팅 테이블과 명시적 서브넷 연결은 추가하지 않았습니다.
- NAT는 public-a 서브넷의 기존 Zonal NAT 1개와 기존 EIP를 표현합니다.
  AWS의 Name 태그 `retali-nat`도 그대로 유지합니다.
- APP 서브넷 2개는 `retail-Nat-rt`를 통해 같은 NAT를 사용합니다.
- DB 서브넷 2개는 기존 DB 라우팅 테이블을 사용하며 인터넷 기본 경로가 없습니다.
- 기존 IGW 태그와 public 서브넷의 `kubernetes.io/role/elb=1` 태그를 코드에 반영했습니다.
- EKS/eksctl/CloudFormation 리소스와 Bastion은 이번 네트워크 코드 작성 범위에 포함하지 않았습니다.

## 코드와 state의 차이

2026-09-05 확인 시 기존 dev state에는 관리 리소스 11개가 있습니다.
VPC, 서브넷 6개, IGW, DB 라우팅 테이블, DB 서브넷 연결 2개입니다.

수정한 코드는 관리 리소스 17개를 선언합니다.
아래 6개는 AWS에 존재하지만 현재 dev state에는 없어, 나중에 기존 리소스와 연결해야 합니다.

| Terraform 주소 | 기존 AWS 리소스 |
| --- | --- |
| `module.vpc.aws_default_route_table.public` | `rtb-020f70506bad49c48` (import ID는 VPC ID) |
| `module.vpc.aws_eip.nat` | `eipalloc-0e9db7d59e51e14a1` |
| `module.vpc.aws_nat_gateway.public` | `nat-0c185896a2915ee5c` |
| `module.vpc.aws_route_table.private_app` | `rtb-0040faf206ac1c8d3` |
| `module.vpc.aws_route_table_association.private_app_a` | app-a → `retail-Nat-rt` |
| `module.vpc.aws_route_table_association.private_app_b` | app-b → `retail-Nat-rt` |

`imports-dev.tf.example`에 해당 6개의 import 블록을 적었습니다.
확장자가 `.tf.example`이므로 Terraform은 이 파일을 자동으로 읽지 않습니다.

기존 리소스를 등록하기로 결정한 뒤에는 계정, backend, workspace 및 다른 state의 중복 관리 여부를 확인하고
현재 state를 안전한 위치에 백업합니다. 이후 이 예제를 프로젝트 루트의 `imports-dev.tf`로 복사해
`terraform plan`으로 실제 변경 내용을 검토할 수 있습니다.
이 설명은 후속 작업 안내이며, 이번에는 복사·plan·import·apply를 실행하지 않았습니다.

기존 리소스를 보존하는 것이 목적이므로 import 외 생성·수정·삭제가 나타나면 먼저 원인을 확인해야 합니다.
특히 `aws_default_route_table`은 import 없이 처음 관리 대상으로 채택하면 기존 경로를 지우고
코드의 경로를 다시 작성할 수 있습니다. 기존 기본 테이블을 import하기 전에 바로 apply하지 마세요.
코드 작성만으로 기존 NAT와 EIP가 state에 자동 등록되는 것도 아닙니다.

## 로컬 검증

이미 provider와 모듈이 설치된 프로젝트에서 다음 명령으로 형식과 구성의 유효성을 검사합니다.

```bash
terraform fmt -check -recursive
terraform validate -no-color
```

이 검사는 AWS 리소스 생성·변경·삭제를 실행하지 않습니다.
`validate` 통과는 실제 AWS와의 차이가 없다는 보장이 아니며, 그 차이는 후속 plan 검토가 필요합니다.

## 참고

- [기본 라우팅 테이블과 import](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_route_table)
- [NAT Gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway)
- [라우팅 테이블 연결의 import 형식](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association)
