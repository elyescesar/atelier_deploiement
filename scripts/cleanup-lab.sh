#!/usr/bin/env bash
set -uo pipefail

PROJECT="${PROJECT_NAME:-ecommerce-devops-lab}"
REGION="${AWS_REGION:-us-east-1}"
LAB_CIDR="10.0.0.0/16"

log() { echo "[cleanup] $*"; }

terminate_lab_instances() {
  local ids
  ids=$(aws ec2 describe-instances --region "$REGION" \
    --filters "Name=tag:Name,Values=${PROJECT}-web-*" \
              "Name=instance-state-name,Values=pending,running,stopping,stopped,stopping" \
    --query 'Reservations[].Instances[].InstanceId' --output text 2>/dev/null || true)
  if [ -n "$ids" ] && [ "$ids" != "None" ]; then
    log "Terminating instances: $ids"
    aws ec2 terminate-instances --region "$REGION" --instance-ids $ids || true
    aws ec2 wait instance-terminated --region "$REGION" --instance-ids $ids 2>/dev/null || sleep 60
  fi

  for vpc_id in $(list_lab_vpc_ids); do
    ids=$(aws ec2 describe-instances --region "$REGION" \
      --filters "Name=vpc-id,Values=$vpc_id" \
                "Name=instance-state-name,Values=pending,running,stopping,stopped" \
      --query 'Reservations[].Instances[].InstanceId' --output text 2>/dev/null || true)
    if [ -n "$ids" ] && [ "$ids" != "None" ]; then
      log "Terminating instances in $vpc_id: $ids"
      aws ec2 terminate-instances --region "$REGION" --instance-ids $ids || true
      aws ec2 wait instance-terminated --region "$REGION" --instance-ids $ids 2>/dev/null || sleep 60
    fi
  done
}

delete_load_balancers() {
  local arns
  arns=$(aws elbv2 describe-load-balancers --region "$REGION" \
    --query "LoadBalancers[?contains(LoadBalancerName, '${PROJECT}') || contains(LoadBalancerName, 'ecom')].LoadBalancerArn" \
    --output text 2>/dev/null || true)
  for arn in $arns; do
    [ -z "$arn" ] || [ "$arn" = "None" ] && continue
    log "Deleting load balancer $arn"
    for listener in $(aws elbv2 describe-listeners --region "$REGION" --load-balancer-arn "$arn" \
      --query 'Listeners[].ListenerArn' --output text 2>/dev/null); do
      aws elbv2 delete-listener --region "$REGION" --listener-arn "$listener" || true
    done
    aws elbv2 delete-load-balancer --region "$REGION" --load-balancer-arn "$arn" || true
  done
  sleep 30

  local tgs
  tgs=$(aws elbv2 describe-target-groups --region "$REGION" \
    --query "TargetGroups[?contains(TargetGroupName, '${PROJECT}') || contains(TargetGroupName, 'ecom')].TargetGroupArn" \
    --output text 2>/dev/null || true)
  for tg in $tgs; do
    [ -z "$tg" ] || [ "$tg" = "None" ] && continue
    log "Deleting target group $tg"
    aws elbv2 delete-target-group --region "$REGION" --target-group-arn "$tg" || true
  done
}

list_lab_vpc_ids() {
  aws ec2 describe-vpcs --region "$REGION" \
    --query "Vpcs[?CidrBlock=='${LAB_CIDR}' || Tags[?Key=='Name' && contains(Value, '${PROJECT}')]].VpcId" \
    --output text 2>/dev/null | tr '\t' '\n' | sort -u
}

delete_vpc() {
  local vpc_id="$1"
  log "Deleting VPC $vpc_id"

  for eni in $(aws ec2 describe-network-interfaces --region "$REGION" \
    --filters "Name=vpc-id,Values=$vpc_id" \
    --query 'NetworkInterfaces[?Status==`available`].NetworkInterfaceId' --output text 2>/dev/null); do
    [ -z "$eni" ] || [ "$eni" = "None" ] && continue
    aws ec2 delete-network-interface --region "$REGION" --network-interface-id "$eni" || true
  done

  for nat in $(aws ec2 describe-nat-gateways --region "$REGION" \
    --filter "Name=vpc-id,Values=$vpc_id" \
    --query 'NatGateways[?State!=`deleted` && State!=`deleting`].NatGatewayId' --output text 2>/dev/null); do
    [ -z "$nat" ] || [ "$nat" = "None" ] && continue
    aws ec2 delete-nat-gateway --region "$REGION" --nat-gateway-id "$nat" || true
  done
  sleep 30

  for igw in $(aws ec2 describe-internet-gateways --region "$REGION" \
    --filters "Name=attachment.vpc-id,Values=$vpc_id" \
    --query 'InternetGateways[].InternetGatewayId' --output text 2>/dev/null); do
    aws ec2 detach-internet-gateway --region "$REGION" --internet-gateway-id "$igw" --vpc-id "$vpc_id" || true
    aws ec2 delete-internet-gateway --region "$REGION" --internet-gateway-id "$igw" || true
  done

  for subnet in $(aws ec2 describe-subnets --region "$REGION" \
    --filters "Name=vpc-id,Values=$vpc_id" --query 'Subnets[].SubnetId' --output text 2>/dev/null); do
    aws ec2 delete-subnet --region "$REGION" --subnet-id "$subnet" || true
  done

  for rt in $(aws ec2 describe-route-tables --region "$REGION" \
    --filters "Name=vpc-id,Values=$vpc_id" \
    --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text 2>/dev/null); do
    aws ec2 delete-route-table --region "$REGION" --route-table-id "$rt" || true
  done

  for _ in 1 2 3 4 5; do
    local remaining
    remaining=$(aws ec2 describe-security-groups --region "$REGION" \
      --filters "Name=vpc-id,Values=$vpc_id" \
      --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text 2>/dev/null || true)
    [ -z "$remaining" ] || [ "$remaining" = "None" ] && break
    for sg in $remaining; do
      aws ec2 delete-security-group --region "$REGION" --group-id "$sg" || true
    done
    sleep 5
  done

  aws ec2 delete-vpc --region "$REGION" --vpc-id "$vpc_id" && log "Deleted VPC $vpc_id" || log "VPC $vpc_id not deleted yet"
}

log "Cleaning ${PROJECT} in ${REGION}..."
terminate_lab_instances
delete_load_balancers

for vpc_id in $(list_lab_vpc_ids); do
  [ -z "$vpc_id" ] || [ "$vpc_id" = "None" ] && continue
  delete_vpc "$vpc_id"
done

for _ in 1 2 3; do
  remaining=$(list_lab_vpc_ids | wc -l)
  [ "$remaining" -eq 0 ] && break
  log "Retry pass, VPCs left: $remaining"
  terminate_lab_instances
  delete_load_balancers
  for vpc_id in $(list_lab_vpc_ids); do
    delete_vpc "$vpc_id"
  done
done

log "Remaining lab VPCs:"
list_lab_vpc_ids || log "none"
