"""
core/options.py
"""

import argparse
from enum import Enum


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


class CmdOptions(argparse.ArgumentParser, metaclass=Singleton):
    args = None

    def __init__(self, *args, **kwargs):
        # Call the base class initializer
        super().__init__(*args, **kwargs)

    def add_common_args(self):
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

    def parse(self):
        self.args = self.parse_args()
        self.args.output_format = (
            outputFormat.TEXT
            if self.args.output_format == "text"
            else outputFormat.JSON if self.args.output_format == "json" else outputFormat.CSV
        )
        return self.args

    # def add_custom_argument(self, name, **kwargs):
    #     """Add a custom argument with some predefined settings."""
    #     print(f"Adding custom argument: {name}")
    #     self.add_argument(name, **kwargs)
