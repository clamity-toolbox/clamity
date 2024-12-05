#!/usr/bin/env python3

# desc: secrets store operations

import sys
import os
from clamity.core.options import CmdOptions
import clamity.core.utils as cUtils
from clamity import aws


def secrets_schema():
    """returns the secrets schema"""
    schema = os.environ["CLAMITY_secrets_schema"] if "CLAMITY_secrets_schema" in os.environ else None
    if not schema:
        print("CLAMITY_secrets_schema not set. Maybe try 'clamity set default secrets_schema /path/to/shared/secrets' ?")
        exit(1)
    elif not os.path.exists(schema):
        print(f"Secrets schema {schema} not found")
        exit(1)


argparser = CmdOptions(description="Work with the secrets store")
argparser.add_common_args()
argparser.add_argument("action", choices=["list", "delete", "update", "add", "read", "details"], help="work to perform")
argparser.add_argument("--desc", type=str, help="secret description")
argparser.add_argument("--value", type=str, help="secret value (the secret itself)")
argparser.add_argument("--name", type=str, help="secret path and name (secret store key)")


if len(sys.argv) == 1:
    argparser.print_usage()
    exit(1)

opts = argparser.parse()

match opts.action:
    case "list":
        aws.resources.secrets().fetch().print()

    case "add":
        if not opts.desc or not opts.value or not opts.name:
            print("--name, --value and --desc are required when adding a secret", file=sys.stderr)
            exit(1)
        s = aws.resources.resourceFactory.new(
            aws.resources.resourceType.SECRET,
            props={
                "name": opts.name,
                "desc": opts.desc,
                "value": opts.value,
                "type": aws.resources.secretType.SIMPLE,
            },
        )
        s.create()

    case "update":
        if (not opts.desc and not opts.value) or not opts.name:
            print("--name and --value or --desc required when adding a secret", file=sys.stderr)
            exit(1)
        exit(0 if aws.resources.secrets().fetch().findOne(opts.name).update(desc=opts.desc, value=opts.value) else 1)

    case "delete":
        if not opts.name:
            print("--name required", file=sys.stderr)
            exit(1)
        exit(0 if aws.resources.secrets().fetch().findOne(opts.name).destroy() else 1)

    case "read":
        if not opts.name:
            print("--name required", file=sys.stderr)
            exit(1)
        print(aws.resources.secrets().fetch().findOne(opts.name).value)

    case "details":
        if not opts.name:
            print("--name required", file=sys.stderr)
            exit(1)
        cUtils.dumpJson(
            {
                "details": aws.resources.secrets().fetch().findOne(opts.name).details,
                "secetDetails": aws.resources.secrets().fetch().findOne(opts.name).valueDetails,
            }
        )

    case "_":
        argparser.print_usage()
        exit(1)

exit(0)
