import sys
import boto3
from typing import Optional

# from enum import Enum

# from . import manager

import clamity.core.utils as cUtils


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
    _default_region: Optional[str] = None

    def __init__(self) -> None:
        self._default_region = boto3.session.Session().region_name

    @property
    def default_region(self) -> Optional[str]:
        return self._default_region

    @default_region.setter
    def default_region(self, region: str) -> None:
        # FIXME: need to validate the region
        self._default_region = region

    @property
    def options(self) -> dict:
        return {"debug": self.debug, "verbose": self.verbose, "region_name": self.default_region}

    def botoRequestOptions(self, **kwargs) -> dict:
        request_region = kwargs["region"] if "region" in kwargs else self._default_region
        if not request_region:
            print("could not determine region", file=sys.stderr)
            exit(1)
        return {"region_name": request_region}

    def printOptions(self, **kwargs) -> None:
        cUtils.dumpJson(self.options, **kwargs)
