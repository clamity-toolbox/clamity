import sys
import boto3
from typing import Optional
import boto3.session
import clamity.core.options as cOptions


class sessionSettings(metaclass=cOptions.Singleton):
    options = cOptions.CmdOptions()
    _set_default_from_arg = False

    @property
    def default_region(self) -> Optional[str]:
        if not self._set_default_from_arg and self.options.args.aws_region:
            self.default_region = self.options.args.aws_region
            self._set_default_from_arg = True
        return boto3._get_default_session().region_name  # this should not be private

    @default_region.setter
    def default_region(self, region: str) -> None:
        boto3.setup_default_session(region_name=region)

    def botoRequestOptions(self, **kwargs) -> dict:
        request_region = kwargs["region"] if "region" in kwargs else self.default_region
        if not request_region:
            print(
                "Could not determine region. Are you logged in (aws sso login --profile <prof>)? Is your profile set (export AWS_PROFILE=<prof>)?",  # noqa
                file=sys.stderr,
            )
            exit(1)
        return {"region_name": request_region}

    def client(self, client: str, region: str):
        if region != self.default_region:
            self.default_region = region
        return boto3.client(client, **self.botoRequestOptions(region=region))
