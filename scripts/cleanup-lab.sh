#!/usr/bin/env bash
set -euo pipefail

PROJECT="${PROJECT_NAME:-ecommerce-devops-lab}"
REGION="${AWS_REGION:-us-east-1}"

echo "Cleaning orphaned ${PROJECT} resources in ${REGION}..."

terminate_instances() {
  local ids
  ids=$(aws ec2 describe-instances \
    --region "$REGION" \
    --filters "Name=tag:Name,Values=${PROJECT}-web-*" \
              "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text 2>/dev/null || true)
  if [ -n "$ids" ] && [ "$ids" != "None" ]; then
    echo "Terminating instances: $ids"
    aws ec2 terminate-instances --region "$REGION" --instance-ids $ids
    aws ec2 wait instance-terminated --region "$REGION" --instance-ids $ids
  fi
}

delete_load_balancers() {
  local arns
  arns=$(aws elbv2 describe-load-balancers --region "$REGION" \
    --query "LoadBalancers[?contains(LoadBalancerName, 'ecom') || contains(LoadBalancerName, '${PROJECT}')].LoadBalancerArn" \
    --output text 2>/dev/null || true)
  for arn in $arns; do
    [ -z "$arn" ] || [ "$arn" = "None" ] && continue
    for listener in $(aws elbv2 describe-listeners --region "$REGION" --load-balancer-arn "$arn" \
      --query 'Listeners[].ListenerArn' --output text 2>/dev/null); do
      aws elbv2 delete-listener --region "$REGION" --listener-arn "$listener" || true
    done
    echo "Deleting load balancer $arn"
    aws elbv2 delete-load-balancer --region "$REGION" --load-balancer-arn "$arn" || true
    aws elbv2 wait load-balancers-deleted --region "$REGION" --load-balancer-arns "$arn" 2>/dev/null || sleep 30
  done

  local tgs
  tgs=$(aws elbv2 describe-target-groups --region "$REGION" \
    --query "TargetGroups[?contains(TargetGroupName, 'ecom') || contains(TargetGroupName, '${PROJECT}')].TargetGroupArn" \
    --output text 2>/dev/null || true)
  for tg in $tgs; do
    [ -z "$tg" ] || [ "$tg" = "None" ] && continue
    echo "Deleting target group $tg"
    aws elbv2 delete-target-group --region "$REGION" --target-group-arn "$tg" || true
  done
}

delete_vpc() {
  local vpc_id="$1"
  echo "Cleaning VPC $vpc_id"

  for eni in $(aws ec2 describe-network-interfaces --region "$REGION" \
    --filters "Name=vpc-id,Values=$vpc_id" \
    --query 'NetworkInterfaces[?Status==`available`].NetworkInterfaceId' --output text 2>/dev/null); do
    [ -z "$eni" ] || [ "$eni" = "None" ] && continue
    aws ec2 delete-network-interface --region "$REGION" --network-interface-id "$eni" || true
  done

  for igw in $(aws ec2 describe-internet-gateways --region "$REGION" \
    --filters "Name=attachment.vpc-id,Values=$vpc_id" \
    --query 'InternetGateways[].InternetGatewayId' --output text 2>/dev/null); do
    aws ec2 detach-internet-gateway --region "$REGION" --internet-gateway-id "$igw" --vpc-id "$vpc_id" || true
    aws ec2 delete-internet-gateway --region "$REGION" --internet-gateway-id "$igw" || true
  done

  for subnet in $(aws ec2 describe-subnets --region "$REGION" \
    --filters "Name=vpc-id,Values=$vpc_id" \
    --query 'Subnets[].SubnetId' --output text 2>/dev/null); do
    aws ec2 delete-subnet --region "$REGION" --subnet-id "$subnet" || true
  done

  for rt in $(aws ec2 describe-route-tables --region "$REGION" \
    --filters "Name=vpc-id,Values=$vpc_id" \
    --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text 2>/dev/null); do
    aws ec2 delete-route-table --region "$REGION" --route-table-id "$rt" || true
  done

  for sg in $(aws ec2 describe-security-groups --region "$REGION" \
    --filters "Name=vpc-id,Values=$vpc_id" \
    --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text 2>/dev/null); do
    aws ec2 delete-security-group --region "$REGION" --group-id "$sg" || true
  done

  aws ec2 delete-vpc --region "$REGION" --vpc-id "$vpc_id" || true
}

terminate_instances
delete_load_balancers

VPC_IDS=$(aws ec2 describe-vpcs --region "$REGION" \
  --filters "Name=tag:Name,Values=${PROJECT}-vpc" \
  --query 'Vpcs[].VpcId' --output text 2>/dev/null || true)

for vpc_id in $VPC_IDS; do
  [ -z "$vpc_id" ] || [ "$vpc_id" = "None" ] && continue
  delete_vpc "$vpc_id"
done

echo "Cleanup finished."
