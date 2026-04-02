#!/bin/bash
set -euo pipefail

VERSION="${1:-1.12.0}"
ZIP="terraform_${VERSION}_linux_amd64.zip"

curl -fsSL "https://releases.hashicorp.com/terraform/${VERSION}/${ZIP}" -o "/tmp/${ZIP}"
unzip -o "/tmp/${ZIP}" -d ~/bin
rm "/tmp/${ZIP}"

terraform version
