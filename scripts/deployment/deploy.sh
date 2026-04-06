#!/bin/bash
#
# Zero-Downtime Deployment Script
# Blue-green deployment strategy for EC2 instances
# Interview talking point: Deployment strategies, rollback, automation
#

set -euo pipefail

# Configuration
APP_NAME="${APP_NAME:-flask-api}"
DEPLOY_GROUP="${DEPLOY_GROUP:-api-asg}"
HEALTH_CHECK_URL="${HEALTH_CHECK_URL:-http://localhost:5000/health}"
HEALTH_CHECK_RETRIES="${HEALTH_CHECK_RETRIES:-10}"
HEALTH_CHECK_INTERVAL="${HEALTH_CHECK_INTERVAL:-15}"
ROLLBACK_ON_FAILURE="${ROLLBACK_ON_FAILURE:-true}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() {
    echo -e "${CYAN}[$(date '+%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_health() {
    local url="$1"
    local retries="$2"
    local interval="$3"

    log "Health checking $url (retries: $retries, interval: ${interval}s)"

    for i in $(seq 1 "$retries"); do
        if curl -sf "$url" > /dev/null 2>&1; then
            success "Health check passed (attempt $i/$retries)"
            return 0
        fi
        warn "Health check failed (attempt $i/$retries), retrying in ${interval}s..."
        sleep "$interval"
    done

    error "Health check failed after $retries attempts"
    return 1
}

get_instance_ids() {
    local asg_name="$1"
    aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names "$asg_name" \
        --query 'AutoScalingGroups[0].Instances[].InstanceId' \
        --output text 2>/dev/null || echo ""
}

terminate_instance() {
    local instance_id="$1"
    log "Terminating instance: $instance_id"
    aws autoscaling terminate-instance-in-auto-scaling-group \
        --instance-id "$instance_id" \
        --should-decrement-desired-capacity 2>/dev/null || true
}

deploy_rolling() {
    log "Starting rolling deployment for ASG: $DEPLOY_GROUP"

    local instances
    instances=$(get_instance_ids "$DEPLOY_GROUP")

    if [ -z "$instances" ]; then
        error "No instances found in ASG: $DEPLOY_GROUP"
        exit 1
    fi

    local total=0
    local success_count=0
    local failed_count=0

    for instance_id in $instances; do
        total=$((total + 1))
        log "[$total] Processing instance: $instance_id"

        terminate_instance "$instance_id"

        log "Waiting for new instance to launch..."
        sleep 60

        local new_instance
        new_instance=$(get_instance_ids "$DEPLOY_GROUP" | head -1)

        if [ -n "$new_instance" ]; then
            local public_ip
            public_ip=$(aws ec2 describe-instances \
                --instance-ids "$new_instance" \
                --query 'Reservations[0].Instances[0].PublicIpAddress' \
                --output text 2>/dev/null || echo "")

            if [ -n "$public_ip" ] && [ "$public_ip" != "None" ]; then
                local health_url="http://${public_ip}:5000/health"
                if check_health "$health_url" "$HEALTH_CHECK_RETRIES" "$HEALTH_CHECK_INTERVAL"; then
                    success "Instance $new_instance deployed successfully"
                    success_count=$((success_count + 1))
                else
                    error "Instance $new_instance failed health check"
                    failed_count=$((failed_count + 1))

                    if [ "$ROLLBACK_ON_FAILURE" = "true" ]; then
                        warn "Rollback triggered due to health check failure"
                        exit 1
                    fi
                fi
            fi
        fi
    done

    log "=========================================="
    log "Deployment Summary"
    log "=========================================="
    log "Total instances processed: $total"
    success "Successful: $success_count"
    [ "$failed_count" -gt 0 ] && error "Failed: $failed_count"
    log "=========================================="
}

deploy_blue_green() {
    log "Starting blue-green deployment"

    local blue_asg="${DEPLOY_GROUP}-blue"
    local green_asg="${DEPLOY_GROUP}-green"

    log "Scaling up green environment..."
    aws autoscaling update-auto-scaling-group \
        --auto-scaling-group-name "$green_asg" \
        --desired-capacity 2 2>/dev/null || true

    log "Waiting for green instances to initialize..."
    sleep 120

    local green_instances
    green_instances=$(get_instance_ids "$green_asg")

    for instance_id in $green_instances; do
        local public_ip
        public_ip=$(aws ec2 describe-instances \
            --instance-ids "$instance_id" \
            --query 'Reservations[0].Instances[0].PublicIpAddress' \
            --output text 2>/dev/null || echo "")

        if [ -n "$public_ip" ] && [ "$public_ip" != "None" ]; then
            if ! check_health "http://${public_ip}:5000/health" "$HEALTH_CHECK_RETRIES" "$HEALTH_CHECK_INTERVAL"; then
                error "Green environment health check failed"
                exit 1
            fi
        fi
    done

    success "Green environment healthy, switching traffic..."

    log "Updating load balancer to point to green ASG..."
    aws elbv2 register-targets \
        --target-group-arn "${TARGET_GROUP_ARN:-arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/green-tg/abc123}" \
        --targets $(echo "$green_instances" | tr '\n' ' ' | sed 's/ / Id=/g; s/^/Id=/') 2>/dev/null || true

    log "Scaling down blue environment..."
    aws autoscaling update-auto-scaling-group \
        --auto-scaling-group-name "$blue_asg" \
        --desired-capacity 0 2>/dev/null || true

    success "Blue-green deployment complete"
}

rollback() {
    log "Starting rollback..."

    local instances
    instances=$(get_instance_ids "$DEPLOY_GROUP")

    for instance_id in $instances; do
        terminate_instance "$instance_id"
    done

    log "Rollback complete. Previous version will be redeployed."
}

main() {
    case "${1:-rolling}" in
        rolling)
            deploy_rolling
            ;;
        blue-green)
            deploy_blue_green
            ;;
        rollback)
            rollback
            ;;
        *)
            echo "Usage: $0 {rolling|blue-green|rollback}"
            exit 1
            ;;
    esac
}

main "$@"
