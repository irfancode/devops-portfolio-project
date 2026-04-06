#!/usr/bin/env python3
"""
AWS S3 Automation Script
Demonstrates: boto3 usage, S3 operations, error handling, logging
Interview talking point: Cloud SDK automation, infrastructure scripting
"""

import os
import sys
import logging
import boto3
from botocore.exceptions import ClientError, NoCredentialsError

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class S3Manager:
    def __init__(self, region='us-east-1'):
        try:
            self.s3 = boto3.client('s3', region_name=region)
            self.resource = boto3.resource('s3', region_name=region)
            logger.info(f"Connected to S3 in region: {region}")
        except NoCredentialsError:
            logger.error("AWS credentials not found. Configure with 'aws configure'")
            sys.exit(1)

    def list_buckets(self):
        """List all S3 buckets in the account."""
        try:
            response = self.s3.list_buckets()
            buckets = response['Buckets']
            logger.info(f"Found {len(buckets)} buckets:")
            for bucket in buckets:
                logger.info(f"  - {bucket['Name']} (Created: {bucket['CreationDate']})")
            return buckets
        except ClientError as e:
            logger.error(f"Failed to list buckets: {e}")
            return []

    def create_bucket(self, bucket_name, region='us-east-1'):
        """Create a new S3 bucket with encryption and versioning."""
        try:
            if region == 'us-east-1':
                self.s3.create_bucket(Bucket=bucket_name)
            else:
                self.s3.create_bucket(
                    Bucket=bucket_name,
                    CreateBucketConfiguration={'LocationConstraint': region}
                )

            self.s3.put_bucket_encryption(
                Bucket=bucket_name,
                ServerSideEncryptionConfiguration={
                    'Rules': [{
                        'ApplyServerSideEncryptionByDefault': {'SSEAlgorithm': 'AES256'}
                    }]
                }
            )

            self.s3.put_bucket_versioning(
                Bucket=bucket_name,
                VersioningConfiguration={'Status': 'Enabled'}
            )

            logger.info(f"Created bucket: {bucket_name} with encryption and versioning")
            return True
        except ClientError as e:
            logger.error(f"Failed to create bucket: {e}")
            return False

    def upload_file(self, file_path, bucket_name, object_name=None):
        """Upload a file to S3 with progress tracking."""
        if object_name is None:
            object_name = os.path.basename(file_path)

        try:
            self.s3.upload_file(
                file_path, bucket_name, object_name,
                ExtraArgs={'ServerSideEncryption': 'AES256'}
            )
            logger.info(f"Uploaded {file_path} -> s3://{bucket_name}/{object_name}")
            return True
        except ClientError as e:
            logger.error(f"Failed to upload file: {e}")
            return False

    def download_file(self, bucket_name, object_name, download_path):
        """Download a file from S3."""
        try:
            self.s3.download_file(bucket_name, object_name, download_path)
            logger.info(f"Downloaded s3://{bucket_name}/{object_name} -> {download_path}")
            return True
        except ClientError as e:
            logger.error(f"Failed to download file: {e}")
            return False

    def list_objects(self, bucket_name, prefix=''):
        """List objects in a bucket with optional prefix filter."""
        try:
            response = self.s3.list_objects_v2(Bucket=bucket_name, Prefix=prefix)
            objects = response.get('Contents', [])
            logger.info(f"Found {len(objects)} objects in s3://{bucket_name}/{prefix}:")
            for obj in objects:
                size_mb = obj['Size'] / (1024 * 1024)
                logger.info(f"  - {obj['Key']} ({size_mb:.2f} MB, LastModified: {obj['LastModified']})")
            return objects
        except ClientError as e:
            logger.error(f"Failed to list objects: {e}")
            return []

    def delete_object(self, bucket_name, object_name):
        """Delete an object from S3."""
        try:
            self.s3.delete_object(Bucket=bucket_name, Key=object_name)
            logger.info(f"Deleted s3://{bucket_name}/{object_name}")
            return True
        except ClientError as e:
            logger.error(f"Failed to delete object: {e}")
            return False

    def get_bucket_size(self, bucket_name):
        """Calculate total size of a bucket."""
        try:
            response = self.s3.list_objects_v2(Bucket=bucket_name)
            total_size = sum(obj['Size'] for obj in response.get('Contents', []))
            size_gb = total_size / (1024 ** 3)
            logger.info(f"Bucket {bucket_name} size: {size_gb:.2f} GB")
            return total_size
        except ClientError as e:
            logger.error(f"Failed to get bucket size: {e}")
            return 0

    def set_lifecycle_policy(self, bucket_name):
        """Set lifecycle policy for cost optimization."""
        lifecycle_policy = {
            'Rules': [
                {
                    'ID': 'MoveToIA',
                    'Status': 'Enabled',
                    'Filter': {'Prefix': ''},
                    'Transitions': [
                        {'Days': 30, 'StorageClass': 'STANDARD_IA'},
                        {'Days': 90, 'StorageClass': 'GLACIER'}
                    ],
                    'Expiration': {'Days': 365},
                    'NoncurrentVersionExpiration': {'NoncurrentDays': 30}
                }
            ]
        }

        try:
            self.s3.put_bucket_lifecycle_configuration(
                Bucket=bucket_name,
                LifecycleConfiguration=lifecycle_policy
            )
            logger.info(f"Set lifecycle policy on {bucket_name}")
            return True
        except ClientError as e:
            logger.error(f"Failed to set lifecycle policy: {e}")
            return False


def main():
    manager = S3Manager()

    print("\n" + "=" * 60)
    print("AWS S3 Automation Script")
    print("=" * 60)

    print("\n[1] Listing all buckets...")
    manager.list_buckets()

    print("\n[2] Creating test bucket...")
    bucket_name = f"devops-portfolio-test-{os.getpid()}"
    manager.create_bucket(bucket_name)

    print("\n[3] Uploading test file...")
    test_file = "/tmp/test-upload.txt"
    with open(test_file, 'w') as f:
        f.write("DevOps Portfolio Test File\n" * 100)
    manager.upload_file(test_file, bucket_name, "test/test-upload.txt")

    print("\n[4] Listing objects...")
    manager.list_objects(bucket_name)

    print("\n[5] Setting lifecycle policy...")
    manager.set_lifecycle_policy(bucket_name)

    print("\n[6] Getting bucket size...")
    manager.get_bucket_size(bucket_name)

    print("\n[7] Downloading file...")
    manager.download_file(bucket_name, "test/test-upload.txt", "/tmp/test-download.txt")

    print("\n[8] Cleaning up...")
    manager.delete_object(bucket_name, "test/test-upload.txt")
    os.remove(test_file)

    print("\n" + "=" * 60)
    print("Script completed successfully!")
    print("=" * 60)


if __name__ == "__main__":
    main()
