# from typing import Optional
from . import resources as r

# import boto3
# import clamity.core.utils as cUtils


class resourceManager:
    def __init__(self) -> None:
        self.region = "default"

    def dumpCache(self) -> None:
        r.resourceCache().dump()

    @property
    def vpcs(self) -> r.vpcs:
        if not hasattr(self, "_vpcs"):
            self._vpcs = r.vpcs()
        return self._vpcs

    # @property
    # def subnets(self) -> r.subnets:
    #     if not hasattr(self, "_subnets"):
    #         self._subnets = r.subnets()
    #     return self._subnets

    # @property
    # def route_tables(self) -> r.route_tables:
    #     if not hasattr(self, "_route_tables"):
    #         self._route_tables = r.route_tables()
    #     return self._route_tables

    # @property
    # def security_groups(self) -> r.security_groups:
    #     if not hasattr(self, "_security_groups"):
    #         self._security_groups = r.security_groups()
    #     return self._security_groups

    # @property
    # def eips(self) -> r.eips:
    #     if not hasattr(self, "_eips"):
    #         self._eips = r.eips()
    #     return self._eips

    # @property
    # def igws(self) -> r.igws:
    #     if not hasattr(self, "_igws"):
    #         self._igws = r.igws()
    #     return self._igws

    # @property
    # def natgws(self) -> r.natgws:
    #     if not hasattr(self, "_natgws"):
    #         self._natgws = r.natgws()
    #     return self._natgws

    # @property
    # def tgws(self) -> r.tgws:
    #     if not hasattr(self, "_tgws"):
    #         self._tgws = r.tgws()
    #     return self._tgws

    # @property
    # def tgw_route_tables(self) -> r.tgw_route_tables:
    #     if not hasattr(self, "_tgw_route_tables"):
    #         self._tgw_route_tables = r.tgw_route_tables()
    #     return self._tgw_route_tables

    # @property
    # def tgw_attachments(self) -> r.tgw_attachments:
    #     if not hasattr(self, "_tgw_attachments"):
    #         self._tgw_attachments = r.tgw_attachments()
    #     return self._tgw_attachments

    # @property
    # def secrets(self) -> r.secret:
    #     if not hasattr(self, "_secrets"):
    #         self._secrets = r.secrets()
    #     return self._secrets


# def resourceFactory(resourceType: str, **kwargs) -> Optional[r.resource]:
#     props = {"region": "default", "resourceType": resourceType}
#     if resourceType == "secret":
#         print("making a secret")
#     else:
#         print(f"don't know how to a {resourceType}")
#         exit(1)
