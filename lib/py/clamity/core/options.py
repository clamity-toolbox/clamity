"""
core/options.py
"""

import argparse
from enum import Enum
from typing import Self


class outputFormat(Enum):
    JSON = 1
    TEXT = 2
    CSV = 3


class Singleton(type):
    _instances = {}

    def __call__(self, *args, **kwargs):
        if self not in self._instances:
            instance = super().__call__(*args, **kwargs)
            # time.sleep(1)  # thread safe
            self._instances[self] = instance
        return self._instances[self]


class CmdOptions(metaclass=Singleton):
    def __init__(self, *args, **kwargs) -> None:
        super().__init__(*args, **kwargs)

    def parser(self, *args, **kwargs) -> Self:
        self._argparser = argparse.ArgumentParser(*args, **{**kwargs, **{"formatter_class": argparse.RawTextHelpFormatter}})
        return self

    def add_mutually_exclusive_group(self, *args, **kwargs) -> argparse.ArgumentParser:
        return self._argparser.add_mutually_exclusive_group(*args, **kwargs)

    def add_argument(self, *args, **kwargs) -> None:
        self._argparser.add_argument(*args, **kwargs)

    def add_common_args(self) -> None:
        self.add_argument("-d", "--debug", action="store_true", default=False, help="debug output")
        self.add_argument("-v", "--verbose", action="store_true", default=False, help="verbose output")
        self.add_argument("-q", "--quiet", action="store_true", default=False, help="surpress output")
        self.add_argument("-n", "--dryrun", action="store_true", default=False, help="dryrun - won't mutate")
        self.add_argument(
            "-y", "--yes", action="store_true", default=False, help="disable interactive prompts in the affirmative"
        )
        self.add_argument(
            "-of",
            "--output-format",
            type=str,
            default="text",
            choices=["json", "text", "csv"],
            help="json, text (default) or csv",
        )
        self.add_argument("--no-truncate", action="store_true", default=False, help="don't truncate column widths")
        self.add_argument("--no-header", action="store_true", default=False, help="don't display column headers")

    def add_aws_args(self) -> None:
        self.add_argument("--aws-region", type=str, help="AWS region (eg. us-east-1)")

    def add_args(self, arg_groups: list) -> None:
        for ag in arg_groups:
            getattr(self, f"add_{ag}_args")()
        return

    def print_usage(self) -> None:
        self._argparser.print_usage()

    def print_help(self) -> None:
        self._argparser.print_help()

    def parse(self, **kwargs):
        self.args = self._argparser.parse_args()
        self.args.output_format = (
            outputFormat.TEXT
            if self.args.output_format == "text"
            else outputFormat.JSON if self.args.output_format == "json" else outputFormat.CSV
        )
        if "help" in kwargs and getattr(self.args, kwargs["help"]) == "help":
            self.print_help()
            exit(1)
        self.args.truncate = not self.args.no_truncate

        self.args.header = not self.args.no_header
        return self.args

    # def add_custom_argument(self, name, **kwargs):
    #     """Add a custom argument with some predefined settings."""
    #     print(f"Adding custom argument: {name}")
    #     self.add_argument(name, **kwargs)
