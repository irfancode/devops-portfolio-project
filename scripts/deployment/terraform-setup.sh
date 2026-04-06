#!/bin/bash
#
# Terraform Environment Setup Script
# Automates Terraform workspace initialization and state management
# Interview talking point: IaC automation, state management, CI/CD integration
#

set -euo pipefail

ENVIRONMENT="${1:-dev}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TF_DIR="$PROJECT_ROOT/terraform/environments/$ENVIRONMENT"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_prerequisites() {
    log "Checking prerequisites..."

    local missing=0
    for cmd in terraform aws; do
        if ! command -v "$cmd" &> /dev/null; then
            error "$cmd is not installed"
            missing=1
        fi
    done

    if [ "$missing" -eq 1 ]; then
        exit 1
    fi

    if [ ! -d "$TF_DIR" ]; then
        error "Environment directory not found: $TF_DIR"
        exit 1
    fi

    success "All prerequisites met"
}

init_terraform() {
    log "Initializing Terraform for environment: $ENVIRONMENT"
    cd "$TF_DIR"

    if [ ! -d ".terraform" ]; then
        terraform init
        success "Terraform initialized"
    else
        success "Terraform already initialized"
    fi
}

validate_terraform() {
    log "Validating Terraform configuration..."
    terraform validate
    terraform fmt -check -recursive || terraform fmt -recursive
    success "Configuration validated and formatted"
}

plan() {
    log "Running Terraform plan..."
    terraform plan -out=tfplan -input=false
    success "Plan generated: tfplan"
}

apply() {
    log "Applying Terraform changes..."
    terraform apply -input=false tfplan
    success "Infrastructure updated"
}

destroy() {
    warn "This will destroy all resources in the $ENVIRONMENT environment!"
    read -p "Are you sure? (yes/no): " confirm
    if [ "$confirm" = "yes" ]; then
        terraform destroy -auto-approve
        success "Infrastructure destroyed"
    else
        log "Destroy cancelled"
    fi
}

show_outputs() {
    log "Terraform outputs:"
    terraform output -json 2>/dev/null | python3 -m json.tool 2>/dev/null || terraform output
}

main() {
    local action="${2:-plan}"

    check_prerequisites
    init_terraform
    validate_terraform

    case "$action" in
        plan)
            plan
            ;;
        apply)
            plan
            apply
            show_outputs
            ;;
        destroy)
            destroy
            ;;
        output)
            show_outputs
            ;;
        *)
            echo "Usage: $0 <environment> <plan|apply|destroy|output>"
            echo "  Environments: dev, staging, prod"
            echo "  Actions: plan, apply, destroy, output"
            exit 1
            ;;
    esac
}

main "$@"
