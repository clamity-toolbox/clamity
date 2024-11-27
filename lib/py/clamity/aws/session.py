import sys
import boto3
from enum import Enum
from typing import Optional

import boto3.session

import clamity.core.utils as cUtils


class outputFormat(Enum):
    JSON = 1
    TEXT = 2


class Singleton(type):
    _instances = {}

    def __call__(self, *args, **kwargs):
        if self not in self._instances:
            instance = super().__call__(*args, **kwargs)
            # time.sleep(1)  # thread safe
            self._instances[self] = instance
        return self._instances[self]


class sessionSettings(metaclass=Singleton):
    debug: bool = False
    verbose: bool = False
    _output: outputFormat = outputFormat.JSON

    @property
    def default_region(self) -> Optional[str]:
        return boto3.session.Session().region_name

    @default_region.setter
    def default_region(self, region: str) -> None:
        boto3.setup_default_session(region_name=region)

    @property
    def output(self) -> outputFormat:
        return self._output

    @output.setter
    def output(self, fmt: outputFormat) -> None:
        if not isinstance(fmt, outputFormat):
            print("warn: ignored output assignment; must be of type 'outputFormat'")
        else:
            self._output = fmt

    @property
    def options(self) -> dict:
        return {"debug": self.debug, "verbose": self.verbose, "region_name": self.default_region, "output": self.output}

    def botoRequestOptions(self, **kwargs) -> dict:
        request_region = kwargs["region"] if "region" in kwargs else self.default_region
        if not request_region:
            print("could not determine region", file=sys.stderr)
            exit(1)
        return {"region_name": request_region}

    def printOptions(self, **kwargs) -> None:
        cUtils.dumpJson(
            {"debug": self.debug, "verbose": self.verbose, "region_name": self.default_region, "output": f"{self.output}"},
            **kwargs,
        )
