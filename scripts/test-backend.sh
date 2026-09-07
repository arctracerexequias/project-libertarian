#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
modules=(admin-service api-gateway communication-service dispatch-service identity-service marketplace-service payment-service shared-contracts load-tester)
patterns=()
for module in "${modules[@]}"; do patterns+=("./$module/..."); done
go test -race "${patterns[@]}"
go vet "${patterns[@]}"
