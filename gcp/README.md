# GCP Terraform 구성 및 기존 리소스 관리

문서 기준일: **2026-10-17**. 아래 설명은 [`main`의 코드 기준 커밋 `b035df9`](https://github.com/AWSome-BIT-Bespin/retail-store-infra/tree/b035df919eb381d79945f77e4ae1073390bae09d/gcp)을 대조한 결과다. 클라우드의 현재 실행 상태를 조회한 결과는 아니다.

이 디렉터리는 `kdt4-3`의 기존 DR 환경을 Terraform으로 관리하기 위해 정리한 독립 root module이다. 최초 문서는 2026-09-18 콘솔 관측을 바탕으로 작성했으며, 이후 변경된 `.tf` 파일을 기준으로 이 README를 갱신했다. Terraform 작업은 PC의 WSL에서 진행한 것으로 확인됐다. 실행 위치와 state 저장 위치는 별개이며, 현재 코드의 backend는 **GCS**다.

프로젝트 종료 후 GCP 리소스를 사용할 수 없는 상태에서 문서를 정리했다. 아래 연결·import·plan 절차는 환경과 권한을 다시 사용할 수 있을 때의 참고 절차이며, 이번 문서 수정에서 실행한 클라우드 작업이 아니다.

## 관리 범위와 파일 기준

현재 root module에는 **관리 대상 resource 17개와 data source 1개**가 선언돼 있다. 네트워크, GKE, Bastion, 관련 서비스 계정·IAM과 PSA 연결을 다룬다. Cloud SQL 인스턴스·DMS·Artifact Registry·GCS 버킷 생성·애플리케이션 배포는 포함하지 않는다.

| 파일 | 현재 역할 |
|---|---|
| [`versions.tf`](versions.tf) | Terraform `>= 1.5.0, < 2.0.0`, Google provider `8.3.0`, 프로젝트·리전·존 지정 |
| [`.terraform.lock.hcl`](.terraform.lock.hcl) | 이 GCP root module의 provider 버전·체크섬 기록. 저장소 루트의 AWS lock 파일과 구분 |
| [`backend.tf`](backend.tf) | GCS state bucket과 prefix 지정 |
| [`network.tf`](network.tf) | VPC, GKE 서브넷, Router·NAT, 수동 SSH 방화벽 2개 |
| [`private-services.tf`](private-services.tf) | Private Service Access(PSA, 관리형 서비스와의 사설 연결) 예약 범위·연결·피어링 경로 설정 |
| [`iam.tf`](iam.tf) | GKE 노드·운영용 서비스 계정 2개와 프로젝트 IAM 역할 연결 2개 |
| [`gke.tf`](gke.tf) | GKE 클러스터와 별도 노드 풀 |
| [`compute.tf`](compute.tf) | Bastion, 기존 공유 스냅샷 정책 조회와 디스크 연결 |
| [`outputs.tf`](outputs.tf) | 클러스터 이름, Bastion 내부 IP, IAP SSH·GKE 인증정보 조회 명령 출력 |

현재 값은 `.tf` 파일에 직접 선언돼 있으며 **`variable` 블록은 없다**. 같은 디렉터리에 남은 아래 파일은 현재 코드와 구분해서 읽어야 한다.

| 파일·과거 안내 | 현재 해석 |
|---|---|
| [`terraform.tfvars`](terraform.tfvars) | 이전 모듈용 예시 값 11개가 남아 있다. 현재 코드가 선언한 입력 변수가 아니므로 프로젝트·CIDR·노드 설정을 바꾸는 입력으로 사용할 수 없다. 자동 로딩 시 미선언 변수 경고가 발생한다. |
| [`import-existing.sh`](import-existing.sh) | 현재 코드에 없는 `google_compute_subnetwork.admin` 가져오기가 포함돼 있다. 일괄 실행하면 일부 state 등록 후 중단될 수 있으므로 그대로 실행하지 않는다. |
| `imports.tf` | 현재 디렉터리에 없다. 이 이름의 파일은 Terraform 실행의 필수 파일이 아니다. 과거의 “19개 자동 import” 안내는 현재 구성에 적용되지 않는다. |
| [`COPY_PASTE.md`](COPY_PASTE.md) | 관리 서브넷·관리 VM 등 이전 구성이 포함된 복사본이다. 현재 `.tf` 파일을 덮어쓰는 용도로 사용하지 않는다. |
| [`backend.tf.example`](backend.tf.example), [`backend.hcl.example`](backend.hcl.example) | backend를 정하기 전의 예시다. 이미 존재하는 `backend.tf`를 덮어쓸 필요가 없다. |
| [`validation.json`](validation.json) | 최초 작성 당시의 검사 기록이다. `imports: 19`, `fmt: pass` 등을 현재 코드의 검증 결과로 인용하지 않는다. |

## State 저장소와 실행 위치

Terraform state는 **코드의 resource 주소와 실제 클라우드 객체를 연결하는 관리 기록**이다. 주문 DB 백업과는 용도가 다르다.

| 항목 | 현재 코드 |
|---|---|
| Backend | `gcs` |
| Bucket | `kdt4-3-retail-dr-tfstate` |
| Prefix | `retail-store/gcp/dr` |
| 실행 디렉터리 | 이 저장소의 `gcp/` |
| 입력 위치 | 개별 `.tf` 파일의 선언값. 현재 `terraform.tfvars`는 유효한 입력 정의와 연결되지 않음 |

WSL에서 Terraform을 실행해도 state는 위 GCS backend에 저장할 수 있다. Bucket은 이 구성에서 생성하지 않으므로 backend 초기화 전에 존재하고 접근 가능해야 한다. [GCS backend 공식 문서](https://developer.hashicorp.com/terraform/language/backend/gcs)

기존 state의 실제 내용·workspace·관리 소유 관계는 별도로 확인해야 한다. 다른 state가 이미 관리하는 자원을 새 state에 중복 등록하지 않는다. 기존 로컬 state나 module 주소가 있다면 먼저 보관·대조하고, 주소 이동 또는 backend 이전 여부를 결정한다. 이 README의 절차만으로 state 이전이 완료됐다고 간주하지 않는다.

## 코드에 선언된 구성

아래 값은 코드의 목표 설정이다. 과거 콘솔 관측값이나 종료 후 자원의 실행 상태와 구분한다.

| 항목 | 현재 선언 |
|---|---|
| 프로젝트 / 리전 / 존 | `kdt4-3` / `asia-northeast3` / `asia-northeast3-a` |
| VPC | `retail-dr-vpc`, 사용자 정의 서브넷, `GLOBAL` 라우팅. MTU는 현재 코드에서 명시하지 않음 |
| 서브넷 | `retail-dr-gke-subnet`, `10.20.0.0/20`, Private Google Access 켜짐 |
| Pod 보조 범위 | `gke-retail-dr-gke-pods-89de90ed`, `10.90.0.0/17`; 기존 GKE 생성 internal range 참조 |
| Service 범위 | 명시적 범위 지정 없음. `gke.tf` 주석은 당시 GKE 관리 범위 `34.118.224.0/20`을 기록 |
| Router / NAT | `retail-dr-router-real` / `retail-dr-nat`, 자동 외부 IP 할당 |
| NAT 대상 | GKE 서브넷 기본 IP 범위와 위 Pod 보조 범위. 동적 포트 할당·endpoint-independent mapping·로그 꺼짐 |
| PSA | `google-managed-services-retail-dr-vpc`, `10.40.0.0/16`, custom routes import/export 켜짐 |
| GKE | `retail-dr-gke`, Zonal Standard, `VPC_NATIVE`, `LEGACY_DATAPATH`, `REGULAR` 채널 |
| Kubernetes 버전 | 특정 버전 고정 없음. 과거 관측 버전을 현재 버전으로 표시하지 않음 |
| 노드 풀 | `retail-dr-pool`, **`node_count = 2`**, 노드 풀 자동 확장 블록 없음 |
| 클러스터 생성 시 기본 풀 | `initial_node_count = 1`, `remove_default_node_pool = true`. 별도 노드 풀의 2대 설정과 구분 |
| 노드 사양 | `n2d-standard-2`, `COS_CONTAINERD`, `pd-balanced` 50GB, AMD SEV |
| 노드 관리·업그레이드 | 자동 복구·업그레이드 켜짐, `SURGE`, `max_surge = 1`, `max_unavailable = 0` |
| GKE 접근 | 클러스터·노드 풀 모두 `enable_private_nodes = false`, `enable_private_endpoint = false`, IP endpoint 켜짐, DNS endpoint 외부 접근 꺼짐 |
| GKE 추가 설정 | Authorized Networks·Workload Identity pool 선언 없음. Network Policy addon 꺼짐 |
| GKE 노드 서비스 계정 | `retail-dr-gke-node@kdt4-3.iam.gserviceaccount.com`, `roles/container.defaultNodeServiceAccount` |
| Bastion | `retail-dr-bastion`, `e2-medium`, Debian 13 이미지, `pd-balanced` 10GB, GKE 서브넷 사용, 외부 IP 없음 |
| Bastion 서비스 계정 | `retail-dr-ops@kdt4-3.iam.gserviceaccount.com`, 코드의 프로젝트 역할은 `roles/container.developer` |
| Bastion 메타데이터 | `enable-osconfig = TRUE`, Ops Agent label, `enable-oslogin` 명시 없음 |
| 스냅샷 | 기존 공유 정책 `default-schedule-1`을 data source로 조회해 Bastion 디스크에 연결. 정책의 일정·보존 기간은 이 코드가 관리하지 않음 |

현재 코드의 관리 접속용 VM은 **Bastion `retail-dr-bastion`**이며, **GKE 서브넷 `retail-dr-gke-subnet`**에 연결돼 있다. 별도 관리 서브넷 `retail-dr-admin-subnet`과 관리 VM `retail-dr-admin` resource는 선언돼 있지 않다. 예전 README의 관리 서브넷·관리 VM, 노드 1대, 사용하지 않는 보조 CIDR 설명을 현재 구성으로 적용하면 안 된다. 코드에서 resource가 없다는 사실만으로 실제 자원의 삭제 여부를 판단하지 않는다.

노드 수 2는 종료 후 비용 절감을 위해 노드를 0으로 내렸던 실행 상태와 별개다. 해당 상태에서 계획을 생성하면 노드 수 복구 등 변경이 표시될 수 있으므로 `No changes`를 미리 보장하지 않는다.

## 관리 대상 resource 주소

아래 목록은 실제 `.tf` 파일의 resource 선언 17개다. 가져오기 완료 개수나 현재 state 목록을 뜻하지 않는다.

| 파일 | Resource 주소 |
|---|---|
| `network.tf` | `google_compute_network.retail` |
| `network.tf` | `google_compute_subnetwork.gke` |
| `network.tf` | `google_compute_router.nat` |
| `network.tf` | `google_compute_router_nat.retail` |
| `network.tf` | `google_compute_firewall.iap_ssh` |
| `network.tf` | `google_compute_firewall.bastion_ssh_existing` |
| `private-services.tf` | `google_compute_global_address.private_services` |
| `private-services.tf` | `google_service_networking_connection.private_services` |
| `private-services.tf` | `google_compute_network_peering_routes_config.private_services` |
| `iam.tf` | `google_service_account.gke_node` |
| `iam.tf` | `google_project_iam_member.gke_node` |
| `iam.tf` | `google_service_account.ops` |
| `iam.tf` | `google_project_iam_member.ops` |
| `gke.tf` | `google_container_cluster.retail` |
| `gke.tf` | `google_container_node_pool.retail` |
| `compute.tf` | `google_compute_instance.bastion` |
| `compute.tf` | `google_compute_disk_resource_policy_attachment.bastion` |

`data.google_compute_resource_policy.shared_snapshot`은 기존 정책 조회용 data source다. 정책 자체를 별도 관리 resource로 가져오지 않는다.

## 클라우드 연결 없이 구성 검사

실행 위치는 저장소 루트의 터미널이다. Terraform과 provider 다운로드에 필요한 네트워크가 필요하다. `-backend=false`는 GCS backend 연결을 생략한다. 이 검사는 실제 계정 권한, 자원 존재, state 정합성이나 배포 성공을 검증하지 않는다. [Terraform validate 공식 문서](https://developer.hashicorp.com/terraform/cli/commands/validate)

```bash
terraform -chdir=gcp init -backend=false -input=false -lockfile=readonly
terraform -chdir=gcp fmt -check
terraform -chdir=gcp validate -json
```

2026-10-16에 별도 checkout에서 확인한 결과는 다음과 같다. 실행 환경은 Windows의 Terraform **1.15.8**, 선택한 Google provider는 **8.3.0**이다.

| 검사 | 결과 |
|---|---|
| Backend 비활성 초기화 | 완료. 미선언 변수 및 lock 파일 갱신 필요 경고가 표시됨 |
| `fmt -check` | 종료 코드 3. `compute.tf`, `gke.tf`, `network.tf`에 서식 차이가 있음 |
| `validate -json` | **검증 완료로 판정하지 않음.** 오류 1개: 내려받은 provider 패키지가 보관된 lock 파일의 체크섬과 일치하지 않음. 미선언 변수 경고도 표시됨 |
| 실제 GCP·GCS 조회, import, plan, apply | 이번 문서 수정에서 미실행 |

체크섬 불일치가 해소되기 전에는 구성의 유효성 검사가 통과했다고 설명하지 않는다. 실행 플랫폼과 신뢰할 수 있는 provider 배포본·lock 파일을 대조해 원인을 확인해야 하며, 검증을 통과시키기 위해 체크섬을 무조건 교체하지 않는다. 이번 변경은 README만 수정하며 `.tf`, `terraform.tfvars`, lock 파일과 기존 검사 기록은 변경하지 않는다.

최초 `validation.json`은 Terraform 1.16.0 / Google provider 8.3.0에서 오류 0·경고 0을 기록한 과거 산출물이다. 위 현재 checkout 검사와 구분하며, 과거 기록을 팀 전체의 이후 Terraform 실행 여부에 대한 증거로 확대하지 않는다.

## 기존 환경에서 작업을 이어갈 때

**전제조건:** GCP 프로젝트와 자원·GCS state bucket이 존재하고, 해당 state 및 대상 자원을 조회·관리할 권한이 있어야 한다. 현재는 리소스를 사용할 수 없으므로 이 절차를 새로 실행하지 않았다. 저장소 root module과 과거 WSL module 구성의 resource 주소가 다를 수 있으므로 같은 디렉터리에 합치지 않는다.

1. 기존 작업 디렉터리·state의 소유 관계, backend bucket/prefix와 workspace를 확인한다. 기존 state가 있다면 새 state에 같은 객체를 다시 가져오지 않는다.
2. 로컬 검사에서 드러난 체크섬·입력 파일 문제를 먼저 검토한다. 다음 인증은 브라우저 콘솔 로그인과 별개인 Terraform용 ADC(Application Default Credentials) 설정이다. 아래 명령은 PC의 WSL에서 실행하는 예시다.

```bash
# 저장소 루트에서 실행. 기존 자원과 state에 대한 접근 권한 필요.
gcloud auth application-default login
gcloud auth application-default set-quota-project kdt4-3

# backend.tf에 선언된 GCS에 연결한다. 새 checkout을 전제로 한다.
terraform -chdir=gcp init -input=false -lockfile=readonly
terraform -chdir=gcp workspace show
terraform -chdir=gcp state list
```

3. 기존 state의 주소와 위 17개 선언을 대조한다. 다른 workspace나 module 주소로 관리 중인 경우 먼저 이동 계획을 정한다. 임의로 state를 삭제하거나 초기화하지 않는다.
4. 기존 실자원은 있지만 어느 state에도 연결돼 있지 않은 항목만 resource별로 검토해 import한다. **현재 `import-existing.sh`는 일괄 실행하지 않는다.** 아래는 VPC 한 개에 대한 형식 예시이며, 이미 관리 중이거나 실제 자원이 없으면 실행 대상이 아니다.

```bash
# state에 기록하는 작업이다. 현재 주소와 실제 자원 ID를 확인한 경우에만 실행.
terraform -chdir=gcp import \
  google_compute_network.retail \
  projects/kdt4-3/global/networks/retail-dr-vpc
```

Import는 기존 객체와 resource 주소를 state에 연결한다. 각 객체는 하나의 관리 주소에 연결해야 한다. 다른 유형의 import ID는 Google provider 8.3.0의 해당 resource 문서와 실제 자원을 대조한다. [Terraform import 공식 문서](https://developer.hashicorp.com/terraform/cli/import/usage)

5. state와 실제 자원을 확인한 뒤 계획을 검토한다. 아래 명령은 실제 GCP API와 backend에 접근하며, plan 파일에는 민감한 값이 포함될 수 있으므로 Git에 올리지 않는다.

```bash
# WSL, 저장소 루트. 계획 파일의 로컬 접근 권한을 제한한다.
umask 077
terraform -chdir=gcp plan -input=false -lock-timeout=5m \
  -detailed-exitcode -out=review.tfplan
```

`-detailed-exitcode`의 0은 변경 없음, 1은 오류, 2는 변경 있음이다. 생성·수정·교체·삭제 대상과 이유를 검토한다. 현재 디렉터리에는 import 블록이 없으므로 plan이 자동으로 17개를 가져오지는 않는다. state 연결 전의 생성 계획을 그대로 적용하면 기존 환경 인수가 되지 않는다.

실제 적용은 검토한 변경 범위와 팀의 운영 절차에 따라 별도로 진행하고, 적용 후에는 계획 결과뿐 아니라 서비스 연결·동작도 확인한다. 이번 README 수정은 이러한 실행 결과를 새로 확보한 작업이 아니다.

## 코드 해석 시 함께 확인할 사항

- **Bastion 태그와 SSH 규칙:** `compute.tf`의 실제 태그 문자열은 `retail-dr-basion`이고, `allow-iap-ssh-bastion`의 대상 태그는 `retail-dr-bastion`이다. 코드상 두 값은 일치하지 않는다. 해당 방화벽의 출발지는 `0.0.0.0/0`이므로 태그만 고치면 허용 범위의 의미가 달라질 수 있다. 별도 `allow-iap-ssh`는 IAP 대역 `35.235.240.0/20`의 TCP 22를 태그 제한 없이 허용한다. 현재 코드의 Bastion에는 외부 IP가 없으며, 넓은 방화벽 규칙만으로 인터넷에서 직접 접속 가능하다고 판단하지 않는다.
- **사설 노드와 NAT:** Cloud NAT가 선언돼 있지만 클러스터·노드 풀의 Private Nodes는 모두 꺼져 있다. NAT 존재를 사설 노드 구성 완료의 증거로 삼지 않는다. 사설 노드 전환은 별도 코드·통신 경로 검토가 필요한 작업이다.
- **IAM 범위:** 여기서 관리하는 프로젝트 역할 연결은 `iam.tf`의 두 항목이다. 실제 계정에 추가된 모든 역할이나 Artifact Registry 저장소별 IAM을 코드가 전부 관리한다고 가정하지 않는다. Bastion의 `container.developer`만으로 VPC/IAM 전체 변경 권한이 생기지는 않는다.
- **업그레이드와 용량:** 별도 노드 풀의 목표는 2대이며, surge 설정은 업그레이드 중 추가 노드를 허용한다. 종료 후 축소 상태와 코드의 목표 용량을 구분해 계획을 검토한다.
- **관측·소프트웨어:** Ops Agent label과 `enable-osconfig` 설정만으로 VM 내부 도구 설치나 외부 대시보드·알림 구성이 모두 재현되지는 않는다. kubectl·gcloud·Terraform 설치와 수동 파일은 별도 관리 범위다.

### 삭제 보호 설정

삭제 보호는 설정마다 적용 대상과 범위가 다르다. 현재 저장소에 선언된 값은 다음과 같다.

| 설정 | 현재 코드 | 의미 |
|---|---|---|
| `lifecycle.prevent_destroy` | 명시된 항목 모두 `false` | 해당 lifecycle 규칙으로 Terraform의 삭제·교체 계획을 차단하지 않음 |
| GKE 클러스터 `deletion_protection` | [`gke.tf`](gke.tf): `true` | Google provider가 Terraform을 통한 클러스터 삭제를 막도록 선언. 실제 삭제 판단에는 state에 기록된 값도 관련됨 |
| Bastion VM `deletion_protection` | [`compute.tf`](compute.tf): `false` | Bastion VM의 삭제 보호를 끄도록 선언 |

이 표는 **코드의 설정값**이며, 현재 state나 실제 자원의 보호 상태를 확인한 결과가 아니다. GKE의 위 provider 설정을 콘솔·API를 통한 모든 삭제까지 막는 보호로 설명하지 않는다. 이번 문서 정리는 이 값을 변경하지 않는다. [Google provider 8.3.0 GKE 문서](https://registry.terraform.io/providers/hashicorp/google/8.3.0/docs/resources/container_cluster)

참고로 `prevent_destroy = true`를 사용하는 경우에도 해당 규칙이 구성에 남아 있을 때 삭제·교체 계획을 제한한다. resource 구성을 통째로 제거하면 이 규칙만으로 삭제를 막지 못한다. [Terraform lifecycle 공식 문서](https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle#prevent_destroy)

## 전체 환경 재구축과의 경계

이 코드는 기존 환경의 관리 주소와 일부 기존 객체를 전제로 한다. 빈 프로젝트에 그대로 적용해 전체 DR 서비스를 재구축하는 템플릿으로 검증된 것은 아니다.

- `network.tf`는 기존 GKE 생성 internal range를 직접 참조한다. 다른 프로젝트에서는 Pod 범위의 생성·소유 방식을 먼저 정해야 한다.
- GCS state bucket, 활성화된 API, 공유 스냅샷 정책 `default-schedule-1`은 사전에 준비돼 있어야 한다. 해당 정책의 일정·보존 설정과 `code-server` 등 다른 사용처는 이 구성의 소유 범위가 아니다.
- GKE가 생성하는 워커 VM·MIG·관리형 방화벽·NAT 자동 외부 IP를 독립 resource로 중복 관리하지 않는다.
- 브라우저 SSH가 주입하는 공개키 본문을 코드에 복사하지 않으며, Bastion은 `metadata["ssh-keys"]`만 변경 비교에서 제외한다. GKE 생성 관련 속성과 노드 풀 `placement_policy`의 제외 항목은 `gke.tf`를 따른다.
- Cloud SQL·DMS·DB 데이터 복구, Artifact Registry 이미지 게시, Secret 입력, Helm·Argo CD 배포와 서비스 검증은 각각의 자료·저장소와 연결해야 한다. 이 Terraform 코드만으로 그 작업까지 완료되는 것은 아니다.
- 프로젝트의 다른 VPC나 VM, 프로젝트 전체 IAM 정책, 공용 OS 정책은 이 root module의 관리 대상이 아니다.

전체 재구축이 필요하면 위 선행 자원과 별도 구성의 순서·연결·검증 방법을 먼저 정리한다. 기존 서비스 실행·배포 이력과 빈 환경 재구축 시험 결과는 구분해 기록한다.

## 과거 관측 자료와 참고 링크

최초 콘솔 관측과 당시 설명은 [2026-10-16 수정 전 README](https://github.com/AWSome-BIT-Bespin/retail-store-infra/blob/7822aefa5f51fda1a183f289820fc7b39c3f02e6/gcp/README.md)에 보존돼 있다. 당시 값에는 관리 서브넷·관리 VM, 노드 1대, Kubernetes `1.35.7-gke.1222000`, 공유 스냅샷 정책의 일정 등이 포함돼 있으므로 현재 코드의 선언값과 구분한다.

다음 콘솔 링크는 과거 프로젝트의 자원 위치를 설명하기 위한 것으로, 현재 자원이 존재하거나 접근 가능하다는 의미가 아니다.

- [VPC](https://console.cloud.google.com/networking/networks/details/retail-dr-vpc?project=kdt4-3)
- [GKE 상세](https://console.cloud.google.com/kubernetes/clusters/details/asia-northeast3-a/retail-dr-gke/details?project=kdt4-3)
- [노드 풀](https://console.cloud.google.com/kubernetes/nodepool/asia-northeast3-a/retail-dr-gke/retail-dr-pool?project=kdt4-3)
- [Bastion](https://console.cloud.google.com/compute/instancesDetail/zones/asia-northeast3-a/instances/retail-dr-bastion?project=kdt4-3)
- [Cloud NAT](https://console.cloud.google.com/net-services/nat/details/asia-northeast3/retail-dr-router-real/retail-dr-nat?project=kdt4-3)
- [프로젝트 IAM](https://console.cloud.google.com/iam-admin/iam?project=kdt4-3)
- [Terraform plan](https://developer.hashicorp.com/terraform/cli/commands/plan)
- [Google provider 8.3.0 PSA resource](https://registry.terraform.io/providers/hashicorp/google/8.3.0/docs/resources/service_networking_connection)
- [Google provider 8.3.0 Peering routes resource](https://registry.terraform.io/providers/hashicorp/google/8.3.0/docs/resources/compute_network_peering_routes_config)
