#!/usr/bin/env python3

# desc: secrets store operations

import argparse
import sys
import os
from clamity import core
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


argparser = argparse.ArgumentParser(description="work with secrets")
# common args
argparser.add_argument("-d", "--debug", action="store_true", default=False, help="debug output")
argparser.add_argument("-v", "--verbose", action="store_true", default=False, help="verbose output")
argparser.add_argument("-q", "--quiet", action="store_true", default=False, help="surpress output")
argparser.add_argument("-n", "--dryrun", action="store_true", default=False, help="dryrun - won't mutate")
argparser.add_argument(
    "-y", "--yes", action="store_true", default=False, help="disable interactive prompts in the affirmative"
)
argparser.add_argument(
    "-of", "--output-format", type=str, default="json", choices=["json", "text", "csv"], help="json, text or csv"
)
# secrets specific
argparser.add_argument("--add", type=str, help="secret prefix/name to add")
argparser.add_argument("--desc", type=str, help="secret description")
argparser.add_argument("--value", type=str, help="secret value (the secret itself)")
argparser.add_argument("--list", action="store_true", default=False, help="list secrets")
argparser.add_argument("--details", type=str, help="details of named secret (json)")
argparser.add_argument("--value-details", type=str, help="value details of named secret (json)")
argparser.add_argument("--delete", type=str, help="delete the named secret")
argparser.add_argument("--update", type=str, help="rotate secret or update its description")

if len(sys.argv) == 1:
    argparser.print_usage()
    exit(1)
args = argparser.parse_args()

ss = aws.session.sessionSettings()
if args.output_format == "text":
    ss.output = aws.session.outputFormat.TEXT


if args.list:
    aws.resources.secrets().fetch().print()

elif args.add:
    if not args.desc or not args.value:
        print("--value and --desc are required when adding a secret", file=sys.stderr)
        exit(1)
    s = aws.resources.resourceFactory.new(
        aws.resources.resourceType.SECRET,
        props={
            "name": args.add,
            "desc": args.desc,
            "value": args.value,
            "type": aws.resources.secretType.SIMPLE,
        },
    )
    s.create()

elif args.update:
    if not args.desc and not args.value:
        print("--desc and/or --value required")
        exit(1)
    exit(0 if aws.resources.secrets().fetch().findOne(args.update).update(desc=args.desc, value=args.value) else 1)

elif args.details:
    core.utils.dumpJson(aws.resources.secrets().fetch().findOne(args.details).details)

elif args.delete:
    exit(0 if aws.resources.secrets().fetch().findOne(args.delete).destroy() else 1)

elif args.value_details:
    core.utils.dumpJson(aws.resources.secrets().fetch().findOne(args.value_details).valueDetails)

elif args.value:
    print(aws.resources.secrets().fetch().findOne(args.value).value)

else:
    argparser.print_usage()
    exit(1)

exit(0)
