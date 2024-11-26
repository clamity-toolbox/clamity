#!/usr/bin/env python3

# desc: secrets store operations

# import argparse
import os

# from clamity.aws import manager as aws  # aws resource manager
from clamity import aws
from clamity.aws.session import outputFormat


def secrets_schema():
    """returns the secrets schema"""
    schema = os.environ["CLAMITY_secrets_schema"] if "CLAMITY_secrets_schema" in os.environ else None
    if not schema:
        print("CLAMITY_secrets_schema not set. Maybe try 'clamity set default secrets_schema /path/to/shared/secrets' ?")
        exit(1)
    elif not os.path.exists(schema):
        print(f"Secrets schema {schema} not found")
        exit(1)


# response = boto3.client('secretsmanager').create_secret(
# 	Name='test/TheFirst',
# 	# ClientRequestToken='string',
# 	Description='my first secret',
# 	# KmsKeyId='aws/secretsmanager',  # default
# 	# SecretBinary=b'bytes',
# 	SecretString='SUPERSPECIALSECRET',
# 	# AddReplicaRegions=[
# 	# 	{
# 	# 		'Region': 'string',
# 	# 		'KmsKeyId': 'string'
# 	# 	},
# 	# ],
# 	# ForceOverwriteReplicaSecret=True|False
# 	Tags=[
# 		{
# 			'Key': 'Name',
# 			'Value': 'TheFirst'
# 		},
# 	]
# )


# rm = aws.resourceManager()
# secret = aws.resourceFactory("secret")
# aws.resources.vpcs().fetch().findOne("vpc-010df66204a575562").print(output=outputFormat.JSON)
aws.resources.vpcs().fetch().print(output=outputFormat.TABLE)
# print(aws.resources.vpcs().fetch().findFirst("vpc-010df66204a575562").name)
# ss = aws.session.sessionSettings().printOptions()
