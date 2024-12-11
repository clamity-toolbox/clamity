#!/usr/bin/env python3

# desc: list resources

"""
List AWS resources

synopsis:

    Get a simple listing of reources or detailed information for a number of
    differet AWS resources.
"""


# import os
# import clamity.core.utils as cUtils
# from typing import Optional, Self, Callable
import sys
from clamity.core.options import CmdOptions
from clamity import aws


Usage = """
    clamity show help
    clamity show { secret | subnet | vpc | route-table | igw | natgw | eip | sg }
"""

ActionsAndSupplemental = """
resources:

    AWS resource

examples:
    Need some examples here.
"""

options = CmdOptions().parser(description=__doc__, usage=Usage, epilog=ActionsAndSupplemental)
options.add_args(["common", "aws"])
options.add_argument(
    "resource",
    choices=["help", "secret", "vpc", "subnet", "route-table", "igw", "natgw", "eip", "sg"],
    help="resource to list",
)

if len(sys.argv) == 1:
    options.print_usage()
    exit(1)

opts = options.parse(help="resource")

if opts.resource == "help":
    options.print_help()
    exit(1)

resourceMap = {
    "secret": aws.resources.secrets,
    "vpc": aws.resources.vpcs,
    "subnet": aws.resources.subnets,
    "route-table": aws.resources.route_tables,
    "igw": aws.resources.igws,
    "natgw": aws.resources.natgws,
    "eip": aws.resources.eips,
    "sg": aws.resources.security_groups,
}
resourceMap[opts.resource]().fetch().print()

exit(0)
