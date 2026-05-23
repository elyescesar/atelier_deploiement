#!/usr/bin/env bash
set -euo pipefail

PROJECT="${PROJECT_NAME:-ecommerce-devops-lab}"
REGION="${AWS_REGION:-us-east-1}"

echo "Cleaning ${PROJECT} resources in ${REGION}..."

for id in $(aws ec2 describe-instances --region "$REGION" \
  --filters "Name=tag:Name,Values=${PROJECT}-web-*" \
            "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[].Instances[].InstanceId' --output text 2>/dev/null || true); do
  [ -z "$id" ] || [ "$id" = "None" ] && continue
  aws ec2 terminate-instances --region "$REGION" --instance-ids $id
done

for arn in $(aws elbv2 describe-load-balancers --region "$REGION" \
  --query "LoadBalancers[?contains(LoadBalancerName, '${PROJECT}')].LoadBalancerArn" \
  --output text 2>/dev/null || true); do
  [ -z "$arn" ] || [ "$arn" = "None" ] && continue
  for listener in $(aws elbv2 describe-listeners --region "$REGION" --load-balancer-arn "$arn" \
    --query 'Listeners[].ListenerArn' --output text 2>/dev/null); do
    aws elbv2 delete-listener --region "$REGION" --listener-arn "$listener" || true
  done
  aws elbv2 delete-load-balancer --region "$REGION" --load-balancer-arn "$arn" || true
done

for tg in $(aws elbv2 describe-target-groups --region "$REGION" \
  --query "TargetGroups[?contains(TargetGroupName, '${PROJECT}')].TargetGroupArn" \
  --output text 2>/dev/null || true); do
  [ -z "$tg" ] || [ "$tg" = "None" ] && continue
  aws elbv2 delete-target-group --region "$REGION" --target-group-arn "$tg" || true
done

for vpc_id in $(aws ec2 describe-vpcs --region "$REGION" \
  --filters "Name=tag:Name,Values=${PROJECT}-vpc" \
  --query 'Vpcs[].VpcId' --output text 2>/dev/null || true); do
  [ -z "$vpc_id" ] || [ "$vpc_id" = "None" ] && continue
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
  for sg in $(aws ec2 describe-security-groups --region "$REGION" \
    --filters "Name=vpc-id,Values=$vpc_id" \
    --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text 2>/dev/null); do
    aws ec2 delete-security-group --region "$REGION" --group-id "$sg" || true
  done
  aws ec2 delete-vpc --region "$REGION" --vpc-id "$vpc_id" || true
done

echo "Cleanup done."
