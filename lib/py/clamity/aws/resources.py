"""
Lowest level AWS resources with a standardized interface.
"""

from abc import ABC, abstractmethod
from typing import Optional

import sys
import boto3
import deepdiff
from enum import Enum

from . import session

import clamity.core.utils as cUtils


def _parseTagList(tagList: list) -> dict:
    """[ { 'Key': 'xyz', 'Value' : 'abc'}, ... ] -> {'xyz': 'abc', ...}"""
    return {kv["Key"]: kv["Value"] for kv in tagList}


def _assembleTagList(tagDict: dict) -> list:
    """{'xyz': 'abc', ...} -> [ {'Key': 'xyz', 'Value': 'abc'}, ... ]"""
    return [{"Key": key, "Value": value} for key, value in tagDict.items()]


# Printing resource data
def _printLineFormatData(fieldOrder, fieldProps: dict) -> dict:
    """create a format string and hyphen separators for use with line printing"""
    fmtString = ""
    i = 0
    separators = []  # underscores under header
    for col in fieldOrder:
        alignment = ">" if "align-right" in fieldProps[col] else ""
        fmtString += "{" + str(i) + ":" + alignment + str(fieldProps[col]["width"]) + "s}  "
        separators.append("-" * fieldProps[col]["width"])
        i += 1
    return {"formatString": fmtString, "separators": separators}


def _printTableHeader(displayFields: list, displayFieldProps: dict) -> None:
    """print line headers and separator for tabular listing"""
    lineFormat = _printLineFormatData(displayFields, displayFieldProps)
    print(lineFormat["formatString"].format(*displayFields))
    print(lineFormat["formatString"].format(*lineFormat["separators"]))


def _printTableLine(obj: any, displayFields: list, displayFieldProps: dict, truncate=True) -> None:
    """Print resource on a line for tabular listing"""
    lineFormat = _printLineFormatData(displayFields, displayFieldProps)
    orderedData = [
        (
            (getattr(obj, field) or "-")
            if not truncate
            else cUtils.shortenWithElipses((getattr(obj, field) or "-"), displayFieldProps[field]["width"])
        )
        for field in displayFields
    ]
    print(lineFormat["formatString"].format(*orderedData))


_resourceCacheData = {}


class resourceCache:

    def __init__(self, resourceClassName: str) -> None:
        global _resourceCacheData
        self._resourceClassName = resourceClassName
        if resourceClassName not in _resourceCacheData:
            _resourceCacheData[resourceClassName] = {}
        self._data = _resourceCacheData

    @property
    def data(self) -> None:
        return self._data

    def replace(self, newData: dict, region: str):
        self.data[region] = newData

    def regionalData(self, region=str) -> dict:
        return self.data[region]

    def hasRegionalDataFor(self, region=str) -> bool:
        return bool(region in self._data)

    # def get(self, category: str, **kwargs) -> Optional[any]:
    #     region = kwargs["region"] if "region" in kwargs else "default"
    #     botoClientOpts = {"region_name": kwargs["region"]} if "region" in kwargs else {}
    #     try:
    #         if "force" in kwargs and kwargs["force"]:  # re-populate cache
    #             raise KeyError
    #         if "TransitGatewayRouteTableId" in kwargs:
    #             return self.data[category][region][kwargs["TransitGatewayRouteTableId"]]
    #         elif self.data[category][region]:
    #             return self.data[category][region]
    #     except KeyError:
    #         if category not in self.data:
    #             self.data[category] = {region: {}}
    #         if category == "vpcs":
    #             self.data[category][region] = boto3.resource("ec2", **botoClientOpts).vpcs.all()
    #         elif category == "subnets":
    #             self.data[category][region] = boto3.resource("ec2", **botoClientOpts).subnets.all()
    #         elif category == "route_tables":
    #             self.data[category][region] = boto3.resource("ec2", **botoClientOpts).route_tables.all()
    #         elif category == "security_groups":
    #             self.data[category][region] = boto3.resource("ec2", **botoClientOpts).security_groups.all()
    #         elif category == "eips":
    #             self.data[category][region] = boto3.resource("ec2", **botoClientOpts).vpc_addresses.all()
    #         elif category == "igws":
    #             self.data[category][region] = boto3.resource("ec2", **botoClientOpts).internet_gateways.all()
    #         elif category == "natgws":
    #             self.data[category][region] = boto3.client("ec2", **botoClientOpts).describe_nat_gateways()
    #         elif category == "tgws":
    #             self.data[category][region] = boto3.client("ec2", **botoClientOpts).describe_transit_gateways()
    #         elif category == "tgw_route_tables":
    #             self.data[category][region] = boto3.client("ec2", **botoClientOpts).describe_transit_gateway_route_tables()
    #         elif category == "tgw_attachments":
    #             self.data[category][region] = boto3.client("ec2", **botoClientOpts).describe_transit_gateway_attachments()
    #         elif category == "tgw_vpc_attachments":
    #             self.data[category][region] = boto3.client(
    #                 "ec2", **botoClientOpts
    #             ).describe_transit_gateway_vpc_attachments()
    #         elif category == "tgw_peering_attachments":
    #             self.data[category][region] = boto3.client(
    #                 "ec2", **botoClientOpts
    #             ).describe_transit_gateway_peering_attachments()
    #         elif category == "tgw_routes":
    #             # tgw routes can only be fetched by tgw route table ID
    #             self.data[category][region][kwargs["TransitGatewayRouteTableId"]] = boto3.client(
    #                 "ec2", **botoClientOpts
    #             ).search_transit_gateway_routes(
    #                 TransitGatewayRouteTableId=kwargs["TransitGatewayRouteTableId"],
    #                 Filters=[{"Name": "type", "Values": ["static", "propagated"]}],
    #             )
    #             return self.data[category][region][kwargs["TransitGatewayRouteTableId"]]
    #         elif category == "tgw_route_table_associations":
    #             # tgw rtbl associations can only be fetched by tgw route table ID
    #             self.data[category][region][kwargs["TransitGatewayRouteTableId"]] = boto3.client(
    #                 "ec2", **botoClientOpts
    #             ).get_transit_gateway_route_table_associations(
    #                 TransitGatewayRouteTableId=kwargs["TransitGatewayRouteTableId"]
    #             )
    #             return self.data[category][region][kwargs["TransitGatewayRouteTableId"]]
    #         elif category == "secrets":
    #             self.data[category][region] = boto3.client("secrets", **botoClientOpts).list_secrets()

    #     return self.data[category][region] if region in self.data[category] else None


class resourceType(Enum):
    UNKNOWN = 0
    VPC = 1
    SUBNET = 2
    SECRET = 3


# One AWS resource (abstract)
class _resource(ABC):
    isDefunct = False  # True if destroy() is called
    exists = False
    _describeData = {}
    _newData = {}

    # these should be implemented as attributes - no better way to abstract them?
    @property
    @abstractmethod
    def resourceType(self) -> resourceType:
        pass

    @property
    @abstractmethod
    def _displayFields(self) -> list:
        pass

    @property
    @abstractmethod
    def _displayFieldProps(self) -> dict:
        pass

    def __init__(self, **kwargs) -> None:
        self._session = session.sessionSettings()
        if "_describeData" in kwargs:
            self.exists = True
            self._describeData = kwargs["_describeData"]

    @property
    @abstractmethod
    def id(self) -> Optional[str]:
        pass

    @property
    def name(self) -> Optional[str]:
        return (
            self._describeData["Name"]
            if "Name" in self._describeData
            else self.tags["Name"] if "Name" in self.tags else None
        )

    @property
    def isDirty(self) -> bool:
        return True if self._describeData and self._newData and deepdiff(self._describeData, self._newData) else False

    @property
    def tags(self) -> dict:
        if self.exists:
            return _parseTagList(self._describeData["Tags"] if "Tags" in self._describeData else {})
        return _parseTagList(self._newData["Tags"] if "Tags" in self._newData else {})

    # @tags.setter
    # def tags(self, newTags: dict) -> None:
    #     if self.exists:
    #         self._newData["Tags"] = _assembleTagList(newTags)
    #         self.dirty = True

    def updateTags(self, newTags: dict) -> None:
        changes = _assembleTagList(deepdiff(self.tags, {**self.tags, **newTags}))
        print(changes)

    # @abstractmethod
    # def update(self) -> bool:
    #     pass

    # @abstractmethod
    # def create(self) -> bool:
    #     pass

    # @abstractmethod
    # def destroy(self) -> bool:
    #     pass

    # @property
    # def raw_data(self) -> dict:
    #     return self._describeData

    def print(self, **kwargs) -> None:
        output = kwargs["output"] if "output" in kwargs else self._session.output
        truncate = kwargs["truncate"] if "truncate" in kwargs else True
        header = kwargs["header"] if "header" in kwargs else True
        if output == session.outputFormat.JSON:
            cUtils.dumpJson(self._describeData)
        else:
            if header:
                _printTableHeader(self._displayFields, self._displayFieldProps)
            _printTableLine(self, self._displayFields, self._displayFieldProps, truncate=truncate)


# Collection of AWS resource (abstract)
class _resources(ABC):
    _resources = []

    def __init__(self, **kwargs) -> None:
        self._resourceCache = resourceCache(self.__class__.__name__)
        self._session = session.sessionSettings()

    def __iter__(self):
        return iter(self._resources)

    def __getitem__(self, item):
        return self._resources[item]

    def __len__(self):
        return len(self._resources)

    @abstractmethod
    def fetch(self, filter: dict = {}, **kwargs):  # returns self
        pass

    def findOne(self, nameOrIdToFind: str) -> Optional[_resource]:
        resourceL = [r for r in self._resources if r.id == nameOrIdToFind or r.name == nameOrIdToFind]
        if len(resourceL) > 1:
            print(f"warn: findOne() returned {len(resourceL)} resources matching {nameOrIdToFind}", sys.stdout)
        return resourceL[0] if len(resourceL) > 0 else None

    # def findSome(self, filter: dict) -> list:  # list of 'resource'
    #     pass

    @property
    def isEmpty(self) -> bool:
        return bool(not len(self._resources))

    @property
    def resourceIdsByName(self) -> dict:
        return {r.name: r.id for r in self._resources if r.name}

    def print(self, **kwargs) -> None:
        output = kwargs["output"] if "output" in kwargs else self._session.output
        truncate = kwargs["truncate"] if "truncate" in kwargs else True
        header = kwargs["header"] if "header" in kwargs else True
        if not len(self._resources):
            print("no data")
            return
        d = []
        for r in self._resources:
            if header and output == session.outputFormat.TABLE:
                _printTableHeader(r._displayFields, r._displayFieldProps)  # bad - private vars
                header = False
            if output == session.outputFormat.JSON:
                d.append(r._describeData)  # bad - private vars
            else:
                r.print(truncate=truncate, header=False, output=output)
        if output == session.outputFormat.JSON:
            cUtils.dumpJson(d)


# ------------------------------------------------------------------------------------------------
# class subnet(resource):
#     resourceType = "subnet"


# class subnets(resources):
#     resourceType = "subnets"

#     def __init__(self) -> None:
#         super().__init__()
#         for r in self._resourceCache.get(self.resourceType):
#             self._resources.append(subnet(r))


# class route(resource):
# 	resourceType = "route"

# class routes(resources):
# 	resourceType = "routes"


# class route_table(resource):
#     resourceType = "route_table"

#     def __init__(self, resource, **kwargs) -> None:
#         super().__init__(resource, **{**kwargs, "FirstClassProps": ["associations", "routes"]})


# class route_tables(resources):
#     resourceType = "route_tables"

#     def __init__(self) -> None:
#         super().__init__()
#         for r in self._resourceCache.get(self.resourceType):
#             self._resources.append(route_table(r))


# class security_group(resource):
#     resourceType = "security_group"


# class security_groups(resources):
#     resourceType = "security_groups"

#     def __init__(self):
#         super().__init__()
#         for r in self._resourceCache.get(self.resourceType):
#             self._resources.append(security_group(r))


# class eip(resource):
#     resourceType = "eip"

#     def __init__(self, resource, **kwargs) -> None:
#         super().__init__(resource, **{**kwargs, "FirstClassProps": ["public_ip", "domain"]})


# class eips(resources):
#     resourceType = "eips"

#     def __init__(self) -> None:
#         super().__init__()
#         for r in self._resourceCache.get(self.resourceType):
#             self._resources.append(eip(r, id=r.allocation_id))


# class igw(resource):
#     resourceType = "igw"


# class igws(resources):
#     resourceType = "igws"

#     def __init__(self):
#         super().__init__()
#         for r in self._resourceCache.get(self.resourceType):
#             self._resources.append(igw(r))


# class natgw(resource):
#     resourceType = "natgw"


# class natgws(resources):
#     resourceType = "natgws"

#     def __init__(self) -> None:
#         super().__init__()
#         for r in self._resourceCache.get(self.resourceType)["NatGateways"]:
#             self._resources.append(natgw(r, id=r["NatGatewayId"]))


# class tgw(resource):
#     resourceType = "tgw"

#     @property
#     def arn(self):
#         return self._boto_resource["TransitGatewayArn"]


# class tgws(resources):
#     resourceType = "tgws"

#     def __init__(self) -> None:
#         super().__init__()
#         for r in self._resourceCache.get(self.resourceType)["TransitGateways"]:
#             self._resources.append(tgw(r, id=r["TransitGatewayId"]))


# class tgw_attachment(resource):
#     resourceType = "tgw_attachment"

#     def __init__(self, data) -> None:
#         super().__init__(data, id=data["TransitGatewayAttachmentId"])

#     @property
#     def resourceId(self) -> str:
#         return self._boto_resource["ResourceId"]

#     @property
#     def attachedResourceType(self) -> str:
#         return self._boto_resource["ResourceType"]

#     @property
#     def isVpcAttachment(self) -> bool:
#         return self.attachedResourceType == "vpc"

#     @property
#     def isPeeringAttachment(self) -> bool:
#         return self.attachedResourceType == "peering"


# class tgw_attachments(resources):
#     resourceType = "tgw_attachments"

#     def __init__(self, data: Optional[any] = None) -> None:
#         super().__init__()
#         if data is None:
#             data = self._resourceCache.get(self.resourceType)["TransitGatewayAttachments"]
#         for a in data:
#             self._resources.append(tgw_attachment(a))

#     def findSome(self, search: Optional[str] = None, **kwargs) -> list:
#         if "vpcId" in kwargs:
#             return [r for r in self._resources if r.isVpcAttachment and r.resourceId == kwargs["vpcId"]]
#         if search:
#             return [r for r in self._resources if r.id == search or r.name == search]
#         print("no search key provided")
#         exit(1)


# class tgw_route(resource):
#     resourceType = "tgw_route"

#     def __init__(self, resource, **kwargs) -> None:
#         super().__init__(resource, **kwargs)
#         # super().__init__(resource, **{**kwargs, 'FirstClassProps': ['Type']})

#     @property
#     def state(self) -> str:
#         return self._boto_resource["State"]

#     @property
#     def isBlackhole(self) -> bool:
#         return self.state == "blackhole"

#     @property
#     def destinationCidr(self) -> str:
#         return self._boto_resource["DestinationCidrBlock"]

#     @property
#     def attachments(self) -> dict:
#         if hasattr(self, "_attachments"):
#             return self._attachments
#         self._attachments = tgw_attachments(
#             self._boto_resource["TransitGatewayAttachments"] if "TransitGatewayAttachments" in self._boto_resource else []
#         )
#         return self._attachments

#     @property
#     def routeType(self) -> str:
#         return self._boto_resource["Type"]


# class tgw_routes(resources):
#     resourceType = "tgw_routes"

#     def __init__(self, tgwRouteTableId: str) -> None:
#         super().__init__()
#         counter = 0
#         # id is made up (and made unique) to support the resource base class
#         for r in self._resourceCache.get(self.resourceType, TransitGatewayRouteTableId=tgwRouteTableId)["Routes"]:
#             self._resources.append(tgw_route(r, id=f"{r['DestinationCidrBlock']}:{counter}"))
#             counter += 1


# class tgw_route_table_association(resource):
#     resourceType = "tgw_route_table_association"

#     def __init__(self, resource, **kwargs) -> None:
#         super().__init__(resource, **kwargs)

#     @property
#     def resourceId(self) -> str:
#         return self._boto_resource["ResourceId"]

#     @property
#     def attachedResourceType(self) -> str:
#         return self._boto_resource["ResourceType"]

#     @property
#     def state(self) -> str:
#         return self._boto_resource["State"]

#     @property
#     def isVpcAttachment(self) -> bool:
#         return self.attachedResourceType == "vpc"

#     @property
#     def isPeeringAttachment(self) -> bool:
#         return self.attachedResourceType == "peering"


# class tgw_route_table_associations(resources):
#     resourceType = "tgw_route_table_associations"

#     def __init__(self, tgwRouteTableId: str) -> None:
#         super().__init__()
#         for r in self._resourceCache.get(self.resourceType, TransitGatewayRouteTableId=tgwRouteTableId)["Associations"]:
#             self._resources.append(tgw_route_table_association(r, id=f"{r['TransitGatewayAttachmentId']}"))


# class tgw_route_table(resource):
#     resourceType = "tgw_route_table"

#     @property
#     def arn(self) -> str:
#         return self._boto_resource["TransitGatewayArn"]

#     @property
#     def routes(self) -> tgw_routes:
#         if not hasattr(self, "_routes"):
#             self._routes = tgw_routes(self.id)
#         return self._routes

#     @property
#     def associations(self) -> tgw_route_table_associations:
#         if not hasattr(self, "_associations"):
#             self._associations = tgw_route_table_associations(self.id)
#         return self._associations


# class tgw_route_tables(resources):
#     resourceType = "tgw_route_tables"

#     def __init__(self) -> None:
#         super().__init__()
#         for r in self._resourceCache.get(self.resourceType)["TransitGatewayRouteTables"]:
#             self._resources.append(tgw_route_table(r, id=r["TransitGatewayRouteTableId"]))


class vpc(_resource):
    resourceType = resourceType.VPC
    _displayFields = ["name", "vpcId", "cidrBlock"]
    _displayFieldProps = {"cidrBlock": {"width": 18}, "name": {"width": 25}, "vpcId": {"width": 21}}

    @property
    def id(self) -> Optional[str]:
        return None if not self.exists else self._describeData["VpcId"]

    @property
    def vpcId(self) -> str:
        return self.id

    @property
    def cidrBlock(self) -> Optional[str]:
        return None if not self.exists else self._describeData["CidrBlock"]

    # @property
    # def tgwAttachments(self) -> tgw_attachments:
    #     if not hasattr(self, "_tgwAttachments"):
    #         self._tgwAttachments = tgw_attachments().findSome(vpcId=self.id)
    #     return self._tgwAttachments


class vpcs(_resources):

    def fetch(self, filter={}, **kwargs):
        boto_opts = self._session.botoRequestOptions(**kwargs)
        if not self._resourceCache.hasRegionalDataFor(boto_opts["region_name"]):
            d = boto3.client("ec2", **boto_opts).describe_vpcs()
            self._resourceCache.replace(d["Vpcs"] if "Vpcs" in d else [], boto_opts["region_name"])
        for r in self._resourceCache.regionalData(boto_opts["region_name"]):
            self._resources.append(vpc(_describeData=r))
        return self


# Secrets Manager
# class secret(resource):
#     resourceType = "secret"

#     def __init__(self, resource, **kwargs) -> None:
#         super().__init__(resource, **{**kwargs, "FirstClassProps": ["associations", "routes"]})


# class secrets(resources):
#     resourceType = "secrets"

#     def __init__(self) -> None:
#         super().__init__()
#         for r in self._resourceCache.get(self.resourceType):
#             cUtils.dumpJson(r)
#             self._resources.append(subnet(r))


class resourceFactory:

    @staticmethod
    def new(r: resourceType) -> _resource:
        if r == resourceType.VPC:
            return vpc()
        print("resourceFactory doesn't know how to create a", r, file=sys.stderr)
        exit(1)
