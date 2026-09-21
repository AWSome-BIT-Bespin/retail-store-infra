# PostgreSQL RDS 모듈

입력: VPC ID, DB 서브넷 ID, DB 버전·사양·이름, 백업·삭제 정책, 앱 SG ID 목록.
출력: DB host/port/database, DB SG ID, 관리자 Secret ARN.

- `main.tf`: DB subnet group와 PostgreSQL 인스턴스
- `security.tf`: DB SG와 허용된 앱 SG별 TCP 5432 규칙

인터넷 공개를 끄고 저장 공간을 암호화합니다. 관리자 비밀번호는 RDS가 Secrets Manager에서 관리하며 Terraform 변수로 전달하지 않습니다.
빈 client_security_group_ids는 앱 접속을 허용하지 않습니다. 이 모듈은 앱 IAM 역할, SQL 사용자, 스키마 마이그레이션을 생성하지 않습니다.
외부 앱의 DB 연결 설정 및 Secret 연동은 루트 docs/ownership.md를 따릅니다.

Multi-AZ DB instance의 대기 DB는 읽기 분산용 replica가 아닙니다. 서브넷 두 개는 생성 위치 후보이며 Multi-AZ 활성화와 별개입니다.
deletion_protection=true이면 삭제가 차단됩니다. skip_final_snapshot=false이면 중복되지 않는 final_snapshot_identifier도 지정하세요.
