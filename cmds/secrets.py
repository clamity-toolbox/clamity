#!/usr/bin/env python3

# desc: secrets store operations

import argparse
import os
import clamity

secretsSchema = os.environ['CLAMITY_secrets_schema'] if 'CLAMITY_secrets_schema' in os.environ else None
if not secretsSchema:
	print(f"CLAMITY_secrets_schema not set. Maybe try 'clamity set default secrets_schema /path/to/shared/secrets' ?")
	exit(1)
elif not os.path.exists(secretsSchema):
	print(f"Secrets schema {secretsSchema} not found")
	exit(1)

print("hi there")
