#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get -o Acquire::Retries=5 update
apt-get -o Acquire::Retries=5 install -y ca-certificates curl gnupg git
install -d -m 0755 /usr/share/keyrings

curl --fail --silent --show-error --retry 5 https://packages.cloud.google.com/apt/doc/apt-key.gpg |
  gpg --batch --yes --dearmor -o /usr/share/keyrings/google-cloud.gpg
printf '%s\n' 'deb [signed-by=/usr/share/keyrings/google-cloud.gpg] https://packages.cloud.google.com/apt cloud-sdk main' > /etc/apt/sources.list.d/google-cloud-sdk.list

curl --fail --silent --show-error --retry 5 https://apt.releases.hashicorp.com/gpg |
  gpg --batch --yes --dearmor -o /usr/share/keyrings/hashicorp.gpg
printf '%s\n' 'deb [arch=amd64 signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com bookworm main' > /etc/apt/sources.list.d/hashicorp.list

apt-get -o Acquire::Retries=5 update
apt-get -o Acquire::Retries=5 install -y terraform google-cloud-cli google-cloud-cli-gke-gcloud-auth-plugin kubectl