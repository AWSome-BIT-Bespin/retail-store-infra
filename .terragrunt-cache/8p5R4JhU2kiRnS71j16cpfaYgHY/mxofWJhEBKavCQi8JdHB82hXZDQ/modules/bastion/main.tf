data "aws_ami" "amzn-linux-2023-ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

data "aws_ssm_parameter" "bastion_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}



# 4. Public A에 관리용 EC2 생성
resource "aws_instance" "bastion" {
  ami           = data.aws_ssm_parameter.bastion_ami.value
  instance_type = "t3.large"

  subnet_id                   = var.private_app_subnet_ids[0]
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  key_name                    = var.bastion_key_name
  iam_instance_profile = aws_iam_instance_profile.bastion.name

  depends_on = [
    aws_vpc_security_group_egress_rule.bastion_outbound,
  ]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = {
    Name      = "retail-bastion"
    ManagedBy = "Terraform"
  }
  lifecycle{
  ignore_changes = [ami]
  # prevent_destroy = true
}
    user_data = <<-USERDATA
    #!/bin/bash
    set -Eeuo pipefail

    export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    exec > >(tee -a /var/log/bastion-bootstrap.log) 2>&1

    # SSM Agent: 없으면 설치하고, 부팅 시 자동 실행
    if ! rpm -q amazon-ssm-agent >/dev/null 2>&1; then
      dnf install -y \
        https://s3.ap-northeast-2.amazonaws.com/amazon-ssm-ap-northeast-2/latest/linux_amd64/amazon-ssm-agent.rpm
    fi
    systemctl enable --now amazon-ssm-agent

    # 관리 도구와 설치 의존성
    dnf install -y git jq tar gzip unzip openssl
    if ! command -v curl >/dev/null 2>&1; then
      dnf install -y curl-minimal
    fi

    BOOTSTRAP_DIR="$(mktemp -d)"
    trap 'rm -rf -- "$BOOTSTRAP_DIR"' EXIT
    cd "$BOOTSTRAP_DIR"

    # AL2023에 기본 제공되는 AWS CLI가 없다면 설치
    if ! command -v aws >/dev/null 2>&1; then
      curl -fsSL --retry 3 \
        https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip \
        -o awscliv2.zip
      unzip -q awscliv2.zip
      ./aws/install
    fi

    # kubectl 설치 및 체크섬 검증
    KUBECTL_VERSION="v1.36.2"

    curl -fsSL --retry 3 \
      "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl" \
      -o kubectl

    curl -fsSL --retry 3 \
      "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl.sha256" \
      -o kubectl.sha256

    printf '%s  kubectl\n' "$(cat kubectl.sha256)" | sha256sum -c -
    install -m 0755 kubectl /usr/local/bin/kubectl

    # Helm 3 설치: 공식 설치 스크립트에서 체크섬 검증
    curl -fsSL --retry 3 \
      https://raw.githubusercontent.com/helm/helm/v3.21.4/scripts/get-helm-3 \
      -o get-helm-3

    DESIRED_VERSION=v3.21.4 USE_SUDO=false bash get-helm-3

    # 설치 결과 확인
    aws --version
    kubectl version --client
    helm version --short
    systemctl is-active amazon-ssm-agent
  USERDATA

}


output "bastion_instance_id" {
  value = aws_instance.bastion.id
}

output "bastion_private_ip" {
  value = aws_instance.bastion.private_ip
}