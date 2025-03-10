#!/usr/bin/env python3

# desc: secrets store operations

"""
Manage data in the secrets store (AWS secretsmanager)

synopsis:

    CLI for managing data in AWS secrets manager. Also provides an integration with a
    secrets schema to ensure data is stored in standard locations for tying into CI/CD
    pipelines.

"""

import sys
import os
from clamity.core.options import CmdOptions
import clamity.core.utils as cUtils
from clamity import aws

Usage = """
    clamity secrets { list | help }
    clamity secrets write --name secret/path/and/name --desc "useful desc" --value "supersecret"
    clamity secrets write --name secret/path/and/name --desc "useful desc" \\
                          --type <known-type> --value '{"prop1": "val", "prop2": "val2", ...}'
    clamity secrets { read | details | delete } --name secret/path/and/name
    clamity secrets update --name secret/path/and/name [--desc "updated desc"] [[--type <known-type>] --value "secret-data"]
"""

ActionsAndSupplemental = """
actions:

    delete   Delete secrets from the secrets store
    details  Display the AWS API response (in JSON) for secret details
    help     Full help
    list     List the secrets
    read     Return the value of a secret
    update   Update a secret's description or value
    write    Add new secrets to the secrets store

standard storage conventions:

    Secret names follow conventions to integration with IAM policies and CI/CD
    pipelines (such as terraform). They're categorized accordingly. A search
    path is typically used in development to accomodate developers who have
    more restricted write capabilities. The search path defaults to ['devs/', ''].
    Developers can write to 'certs/devs/...', 'secrets/devs/...', etc... but
    can read from the larger scope of 'certs/...', 'secrets/...'.

    TLS Certificates:
        certs/[search-path]<domainName>/{key|crt|ca}

    Secrets for services:
        services/[search-path]<serviceName>/<app-env>/<secretName>

    SSH Keys for services:
        services/[search-path]<serviceName>/<app-env>/ssh-keys/<keyName>/{public|private}

    Providers:
        providers/[search-path]<providerName>/<app-env>/<provider-specific-organization>

    Individual users' secrets:
        users/<aws-user-id>/<anything>

    Individual users' ssh keys:
        users/<aws-user-id>/ssh-keys/<keyName>/{public|private}

examples:
    Need some examples here.
"""


def secrets_schema():
    """returns the secrets schema"""
    schema = os.environ["CLAMITY_secrets_schema"] if "CLAMITY_secrets_schema" in os.environ else None
    if not schema:
        print("CLAMITY_secrets_schema not set. Maybe try 'clamity set default secrets_schema /path/to/shared/secrets' ?")
        exit(1)
    elif not os.path.exists(schema):
        print(f"Secrets schema {schema} not found")
        exit(1)


knownKeyTypes = ["ssh_key", "rds_mysql"]  # see resources.py:secretType
options = CmdOptions().parser(description=__doc__, usage=Usage, epilog=ActionsAndSupplemental)
options.add_args(["common", "aws"])
options.add_argument(
    "action",
    choices=["list", "types", "delete", "update", "write", "read", "details", "restore", "help"],
    help="action to take",
)
options.add_argument("--desc", type=str, help="useful description of the secret (possibly a URL)")
options.add_argument("--name", type=str, help="secret's path and name (secret store key)")
options.add_argument("--value", type=str, help="the secret's value")
options.add_argument("--type", type=str, choices=knownKeyTypes, help="add secret validation")

if len(sys.argv) == 1:
    options.print_usage()
    exit(1)

opts = options.parse(help="action")

match opts.action:
    case "list":
        aws.resources.secrets().fetch().print()

    case "write":
        if not opts.desc or not opts.value or not opts.name:
            print("--name, --value and --desc are required when adding a secret", file=sys.stderr)
            exit(1)
        if not opts.type:
            secretType = aws.resources.secretType.SIMPLE
        else:
            keyTypes = {
                "ssh_key": aws.resources.secretType.SSH_KEY,
                "rds_mysql": aws.resources.secretType.RDS_MYSQL,
            }
            if opts.type not in keyTypes:
                print("Unknown secret type (try 'clamity secrets types')", file=sys.stderr)
                exit(1)
            secretType = keyTypes[opts.type]
        s = aws.resources.resourceFactory.new(
            aws.resources.resourceType.SECRET,
            props={
                "name": opts.name,
                "desc": opts.desc,
                "value": opts.value,
                "type": secretType,
            },
        )
        s.create()

    case "update":
        if (not opts.desc and not opts.value) or not opts.name:
            print("--name and --value or --desc required when adding a secret", file=sys.stderr)
            exit(1)
        exit(0 if aws.resources.secrets().fetch().findOne(opts.name).update(desc=opts.desc, value=opts.value) else 1)

    case "restore":
        if not opts.name:
            print("--name required", file=sys.stderr)
            exit(1)
        exit(0 if aws.resources.secret().restore(opts.name) else 1)

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

    case "types":
        print("Known secret types:")
        print('ssh_key: {"public": "ssh-rsa 2345hwduhasdf....", "private": "---BEGIN..."}')
        print(
            'rds_mysql: {"username":"admin","password":"SUPER_DUPER_PASSWORD","engine":"mysql","host":"ecs-test.random.us-east-2.rds.amazonaws.com","port":3306,"dbname":"testdb","dbInstanceIdentifier":"ecs-test"}'  # noqa
        )

    case _:
        options.print_usage()
        exit(1)

exit(0)
