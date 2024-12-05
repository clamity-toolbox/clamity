import sys
import boto3
from typing import Optional
import boto3.session

import clamity.core.utils as cUtils
import clamity.core.options as cOptions


class sessionSettings(metaclass=cOptions.Singleton):
    debug: bool = False
    verbose: bool = False

    @property
    def default_region(self) -> Optional[str]:
        return boto3.session.Session().region_name

    @default_region.setter
    def default_region(self, region: str) -> None:
        boto3.setup_default_session(region_name=region)

    @property
    def options(self) -> dict:
        return {"debug": self.debug, "verbose": self.verbose, "region_name": self.default_region}

    def botoRequestOptions(self, **kwargs) -> dict:
        request_region = kwargs["region"] if "region" in kwargs else self.default_region
        if not request_region:
            print("could not determine region", file=sys.stderr)
            exit(1)
        return {"region_name": request_region}

    def printOptions(self, **kwargs) -> None:
        cUtils.dumpJson(
            {"debug": self.debug, "verbose": self.verbose, "region_name": self.default_region},
            **kwargs,
        )
