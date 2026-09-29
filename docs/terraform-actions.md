# 팀에서 Terraform 실행하기

사용하는 workflow는 Plan, Apply, Destroy 세 개입니다. 모두 main에서 수동 실행하고
dev / stg / prod를 선택합니다. Python 보조 파일, 공통 실행 workflow, 암호화 Secret은 필요 없습니다.

| 환경 | EKS / RDS | State key |
| --- | --- | --- |
| dev | 기존 retail-infra-* | dev/terraform.tfstate |
| stg | retail-stg-* | stg/terraform.tfstate |
| prod | 새 retail-prod-* | prod/terraform.tfstate |

## 사용 순서

1. 변경 코드를 검토하고 main에 반영합니다.
2. Actions → Terraform Plan → 환경과 작업(apply 또는 destroy)을 선택합니다.
3. Plan 로그에서 변경·삭제 대상을 검토합니다.
4. Terraform Apply 또는 Terraform Destroy에서 같은 환경을 선택합니다.
5. 팀장이 Review deployments에서 승인하면 job이 시작됩니다.
6. 승인 후 실행 커밋으로 새 plan을 만들고, 같은 job에서 그 plan을 적용합니다.

승인은 **실행 요청**에 대한 승인입니다. 앞선 Plan 결과를 저장·전달하거나 그 결과와 동일함을
검증하지 않습니다. 코드나 AWS 상태가 바뀌면 실행 결과도 달라질 수 있으므로 Plan 확인 후
같은 커밋으로 실행하고, 중간에 변경이 생기면 Plan부터 다시 확인합니다.
변경 중에는 같은 환경에 로컬 Terraform 명령을 동시에 실행하지 않습니다.

Destroy 확인 문구는 `DESTROY dev INCLUDING RDS`, `DESTROY stg INCLUDING RDS`,
`DESTROY prod INCLUDING RDS` 중 선택한 환경에 맞는 값입니다.
현재 세 환경의 RDS 설정은 삭제 보호가 꺼져 있고 최종 스냅샷을 생략합니다.
실제 삭제 전 DB 보존 범위와 Kubernetes가 생성한 외부 리소스를 확인합니다.

## GitHub에 등록할 값

Repository Variables:

- `AWS_PLAN_ROLE_ARN_DEV`: dev Plan Role ARN
- `AWS_PLAN_ROLE_ARN_STG`: stg Plan Role ARN; 생략하면 기존 `AWS_PLAN_ROLE_ARN` 사용
- `AWS_PLAN_ROLE_ARN_PROD`: prod Plan Role ARN

환경별 Cart 테이블·Secret·SSM Parameter ARN은 `live/aws/<환경>/terragrunt.hcl`의
`cart_table_arn`, `eso_secret_arns`, `eso_parameter_arns`에 설정합니다. 로컬과 Actions는
같은 HCL 입력을 사용하므로 `PROD_*` 환경변수나 GitHub Variables를 따로 등록하지 않습니다.
Secret 내용 대신 리소스 ARN만 입력합니다. 이 root는 해당 데이터 리소스를 생성하지 않습니다.
현재 prod의 이 ARN들은 dev/stg와 같으므로, 데이터를 분리하려면 prod 전용 리소스를 준비하고
prod HCL의 ARN을 교체합니다.

Environment Variables:

| GitHub Environment | 변수 |
| --- | --- |
| aws-dev-apply / aws-dev-destroy | AWS_APPLY_ROLE_ARN = dev 변경 Role ARN |
| aws-stg-apply / aws-stg-destroy | AWS_APPLY_ROLE_ARN = stg 변경 Role ARN |
| aws-prod-apply / aws-prod-destroy | AWS_APPLY_ROLE_ARN = prod 변경 Role ARN |

Plan Role과 변경 Role을 분리하고, 각 Role에 필요한 AWS 작업 권한과 state 접근 권한을 설정합니다.
변경 Role의 OIDC 신뢰 정책 예시는 `docs/iam/<환경>-execution-trust.json`에 있습니다.
이 코드는 IAM Role을 생성하거나 권한을 설정하지 않습니다.

여섯 Environment의 Required reviewers는 yheelearncode, Prevent self-review는 켜기,
관리자 승인 우회는 끄기, 허용 브랜치는 main으로 유지합니다.
승인 규칙은 GitHub 설정에서 관리합니다. 팀장 본인이 실행하려면 다른 승인자를 추가해야 합니다.
기존 `TF_PLAN_PASSPHRASE` Secret은 이 버전에서 사용하지 않습니다.

동일 환경의 세 workflow는 같은 concurrency 그룹을 사용하고 S3 state 잠금을 유지합니다.
승인 대기 중에도 다른 실행이 대기할 수 있습니다.
기존 dev state 위치를 확인한 뒤 첫 Apply를 진행하세요. State 자동 이전은 하지 않습니다.

공식 참고: [GitHub 승인](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/review-deployments),
[Terraform 저장된 plan 적용](https://developer.hashicorp.com/terraform/cli/commands/apply#saved-plan-mode).
