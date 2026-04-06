#!/usr/bin/env python3
"""
EC2 Instance Monitor & Cost Optimizer
Demonstrates: AWS EC2 SDK, CloudWatch metrics, cost analysis, reporting
Interview talking point: Cloud cost optimization, monitoring automation
"""

import os
import sys
import json
import logging
from datetime import datetime, timedelta

import boto3
from botocore.exceptions import ClientError

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class EC2CostOptimizer:
    INSTANCE_PRICING = {
        't3.micro': 0.0104,
        't3.small': 0.0208,
        't3.medium': 0.0416,
        't3.large': 0.0832,
        'm5.large': 0.096,
        'm5.xlarge': 0.192,
        'c5.large': 0.085,
        'c5.xlarge': 0.17,
    }

    def __init__(self, region='us-east-1'):
        self.ec2 = boto3.client('ec2', region_name=region)
        self.cloudwatch = boto3.client('cloudwatch', region_name=region)
        self.region = region

    def get_running_instances(self):
        """Get all running EC2 instances."""
        try:
            response = self.ec2.describe_instances(
                Filters=[{'Name': 'instance-state-name', 'Values': ['running']}]
            )
            instances = []
            for reservation in response['Reservations']:
                for instance in reservation['Instances']:
                    tags = {t['Key']: t['Value'] for t in instance.get('Tags', [])}
                    instances.append({
                        'instance_id': instance['InstanceId'],
                        'instance_type': instance['InstanceType'],
                        'launch_time': instance['LaunchTime'],
                        'private_ip': instance.get('PrivateIpAddress', 'N/A'),
                        'public_ip': instance.get('PublicIpAddress', 'N/A'),
                        'availability_zone': instance['Placement']['AvailabilityZone'],
                        'tags': tags,
                        'name': tags.get('Name', 'Unnamed')
                    })
            logger.info(f"Found {len(instances)} running instances")
            return instances
        except ClientError as e:
            logger.error(f"Failed to get instances: {e}")
            return []

    def get_cpu_utilization(self, instance_id, hours=24):
        """Get average CPU utilization for an instance."""
        try:
            response = self.cloudwatch.get_metric_statistics(
                Namespace='AWS/EC2',
                MetricName='CPUUtilization',
                Dimensions=[{'Name': 'InstanceId', 'Value': instance_id}],
                StartTime=datetime.utcnow() - timedelta(hours=hours),
                EndTime=datetime.utcnow(),
                Period=3600,
                Statistics=['Average']
            )
            datapoints = response['Datapoints']
            if not datapoints:
                return None
            avg_cpu = sum(dp['Average'] for dp in datapoints) / len(datapoints)
            return avg_cpu
        except ClientError as e:
            logger.error(f"Failed to get CPU metrics: {e}")
            return None

    def get_network_io(self, instance_id, hours=24):
        """Get network I/O metrics."""
        try:
            metrics = {}
            for metric_name in ['NetworkIn', 'NetworkOut']:
                response = self.cloudwatch.get_metric_statistics(
                    Namespace='AWS/EC2',
                    MetricName=metric_name,
                    Dimensions=[{'Name': 'InstanceId', 'Value': instance_id}],
                    StartTime=datetime.utcnow() - timedelta(hours=hours),
                    EndTime=datetime.utcnow(),
                    Period=3600,
                    Statistics=['Average']
                )
                datapoints = response['Datapoints']
                if datapoints:
                    avg = sum(dp['Average'] for dp in datapoints) / len(datapoints)
                    metrics[metric_name] = avg / (1024 * 1024)  # Convert to MB
            return metrics
        except ClientError as e:
            logger.error(f"Failed to get network metrics: {e}")
            return {}

    def analyze_underutilized(self, instances, cpu_threshold=10):
        """Identify underutilized instances for rightsizing."""
        recommendations = []
        for instance in instances:
            avg_cpu = self.get_cpu_utilization(instance['instance_id'])
            if avg_cpu is None:
                continue

            current_cost = self.INSTANCE_PRICING.get(instance['instance_type'], 0)
            monthly_cost = current_cost * 730  # Hours per month

            status = 'healthy'
            recommendation = None
            potential_savings = 0

            if avg_cpu < cpu_threshold:
                status = 'underutilized'
                recommendation = 'Consider stopping or downsizing'
                potential_savings = monthly_cost * 0.5
            elif avg_cpu > 80:
                status = 'overutilized'
                recommendation = 'Consider upsizing for performance'
                potential_savings = 0

            recommendations.append({
                'instance_id': instance['instance_id'],
                'name': instance['name'],
                'instance_type': instance['instance_type'],
                'avg_cpu': round(avg_cpu, 2),
                'monthly_cost': round(monthly_cost, 2),
                'status': status,
                'recommendation': recommendation,
                'potential_savings': round(potential_savings, 2)
            })

        return recommendations

    def generate_cost_report(self):
        """Generate a comprehensive cost optimization report."""
        instances = self.get_running_instances()
        if not instances:
            logger.info("No running instances found")
            return

        print("\n" + "=" * 80)
        print("EC2 COST OPTIMIZATION REPORT")
        print(f"Region: {self.region} | Generated: {datetime.utcnow().strftime('%Y-%m-%d %H:%M UTC')}")
        print("=" * 80)

        print(f"\n{'Instance ID':<15} {'Name':<20} {'Type':<12} {'CPU%':<8} {'Monthly $':<12} {'Status':<15}")
        print("-" * 80)

        total_monthly = 0
        total_savings = 0
        underutilized_count = 0

        recommendations = self.analyze_underutilized(instances)

        for rec in recommendations:
            total_monthly += rec['monthly_cost']
            total_savings += rec['potential_savings']
            if rec['status'] == 'underutilized':
                underutilized_count += 1

            print(f"{rec['instance_id']:<15} {rec['name']:<20} {rec['instance_type']:<12} "
                  f"{rec['avg_cpu']:<8} ${rec['monthly_cost']:<11.2f} {rec['status']:<15}")

        print("-" * 80)
        print(f"\nSUMMARY:")
        print(f"  Total Instances: {len(recommendations)}")
        print(f"  Underutilized: {underutilized_count}")
        print(f"  Total Monthly Cost: ${total_monthly:.2f}")
        print(f"  Potential Monthly Savings: ${total_savings:.2f}")
        print(f"  Savings Percentage: {(total_savings/total_monthly*100) if total_monthly > 0 else 0:.1f}%")
        print("=" * 80)

        return recommendations


def main():
    optimizer = EC2CostOptimizer()
    optimizer.generate_cost_report()


if __name__ == "__main__":
    main()
