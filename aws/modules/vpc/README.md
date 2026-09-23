# VPC 모듈

입력: VPC CIDR, AZ 두 개 또는 빈 목록, public/app/db 서브넷 CIDR.
출력: VPC ID, public/app/db 서브넷 ID, 선택한 AZ.

- `main.tf`: VPC와 AZ 선택
- `subnets.tf`: 두 AZ의 public·app·db 서브넷
- `gateways.tf`: IGW, Regional NAT, AZ별 EIP
- `routes.tf`: public 기본 route table, NAT를 향하는 app route, 인터넷 기본 경로 없는 DB route
- `variables.tf` / `outputs.tf`: 모듈 외부 인터페이스

기존 리소스 주소와 각 리소스의 태그를 그대로 유지합니다. 태그 이름을 바꾸려면 해당 리소스의 tags를 수정하고 별도 plan으로 검토합니다.
Regional NAT를 zonal NAT로 변경하지 않았으며, 네트워크 방식 전환은 이 리팩터링의 범위가 아닙니다.
public 서브넷은 VPC 기본 route table을 사용합니다. 기존 네트워크를 가져오는 환경은 기본 route table의 state 등록 상태도 확인해야 합니다.

호출은 루트 main.tf에서 하고 provider 설정은 루트에서 상속합니다. 이 디렉터리에서 별도 apply하지 않습니다.
