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
import argparse

Usage = """
    clamity secrets { list | help }
    clamity secrets add --name secret/path/and/name --desc "useful desc" --value "supersecret"
    clamity secrets { read | details | delete } --name secret/path/and/name
    clamity secrets update --name secret/path/and/name [--desc "updated desc"] [--value "newsecret"]
"""

ActionsAndSupplemental = """
actions:

    add      Add new secrets to the secrets store
    delete   Delete secrets from the secrets store
    details  Display the AWS API response (in JSON) for secret details
    help     Full help
    list     List the secrets
    read     Return the value of a secret
    update   Update a secret's description or value

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


options = CmdOptions().parser(
    description=__doc__,
    usage=Usage,
    epilog=ActionsAndSupplemental,
    formatter_class=argparse.RawTextHelpFormatter,
)
options.add_common_args()
options.add_argument("action", choices=["list", "delete", "update", "add", "read", "details", "help"], help="action to take")
options.add_argument("--desc", type=str, help="useful description of the secret (possibly a URL)")
options.add_argument("--value", type=str, help="the secret's value")
options.add_argument("--name", type=str, help="secret's path and name (secret store key)")

if len(sys.argv) == 1:
    options.print_usage()
    exit(1)

opts = options.parse(help="action")

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
        options.print_usage()
        exit(1)

exit(0)
