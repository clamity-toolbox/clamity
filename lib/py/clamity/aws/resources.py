"""
Lowest level AWS resources with a standardized interface.
"""

from abc import ABC, abstractmethod
from typing import Optional, Self, Callable
from enum import Enum
import sys
import json
import deepdiff
import clamity.core.utils as cUtils
import clamity.core.options as cOptions
from . import session


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


def _checkHttpResponse(response: dict) -> bool:
    if response.get("ResponseMetadata", {}).get("HTTPStatusCode") != 200:
        print("unexpected response code", file=sys.stderr)
        cUtils.dumpJson(response, outputStream=sys.stderr)
        return False
    return True


_resourceCacheData = {}


class resourceCache:

    def __init__(self, resourceClassName: str) -> None:
        global _resourceCacheData
        self._resourceClassName = resourceClassName
        if resourceClassName not in _resourceCacheData:
            _resourceCacheData[resourceClassName] = {}
        self._data = _resourceCacheData[resourceClassName]

    @property
    def data(self) -> None:
        return self._data

    def replace(self, newData: dict, region: str):
        self.data[region] = newData

    def regionalData(self, region=str, **kwargs) -> dict:
        r = kwargs["region"] if "region" in kwargs else region
        return self.data[r]

    def hasRegionalDataFor(self, region=str, **kwargs) -> bool:
        r = kwargs["region"] if "region" in kwargs else region
        return bool(r in self._data)

    #         if category not in self.data:
    #             self.data[category] = {region: {}}
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


class resourceType(Enum):
    UNKNOWN = 0
    VPC = 1
    SUBNET = 2
    SECRET = 3
    ROUTE = 4
    ROUTE_TABLE = 5
    IGW = 6
    EIP = 7
    TGW = 8
    TGW_ROUTE = 9
    TGW_ROUTE_TABLE = 10
    SECURITY_GROUP = 11
    EC2_INSTANCE = 12
    NATGW = 13


# One AWS resource (abstract)
class _resource(ABC):
    session = session.sessionSettings()
    options = cOptions.CmdOptions()
    _props = {}  # allow for prototyping properties when creating new instance

    # these should be attributes -  is there a better way to abstract them?
    @property
    @abstractmethod
    def resourceType(self) -> resourceType:
        pass

    @property
    @abstractmethod
    def _displayFieldOrder(self) -> list:
        pass

    @property
    @abstractmethod
    def _displayFieldProps(self) -> dict:
        pass

    def __init__(self, **kwargs) -> None:
        self._defunct = False  # True if destroy() is called
        self._exists = False
        self._describeData = {}
        self._newData = {}
        self._region = self.get_region(**kwargs)
        if "_describeData" in kwargs:  # loaded from AWS
            self._exists = True
            # self._region = kwargs["region"]
            self._describeData = kwargs["_describeData"]
        elif kwargs.get("props"):  # creating something new (_might_ exist)
            # cUtils.dumpJson?(kwargs["props"])
            for p, v in kwargs["props"].items():
                if p not in self._props:  # validate property is allowed
                    print(f"property {p} not allowed", file=sys.stder)
                    exit(1)
                elif not isinstance(v, self._props[p]):  # validate property is correct type
                    # print(">>", p, self._props[p])
                    print(f"property '{p}' type mismatch. Should be {self._props[p]}")
                    exit(1)
                self._newData[p] = v
            # verify that the resource doesn't already exist
            if not self.verifyNewResource(kwargs["props"]):
                print("resource already exists on AWS")
                exit(1)

    @property
    def isDefunct(self) -> bool:
        if self.options.args.debug and self._defunct:
            print(f"debug: reporting defunct resource {self.id}", file=sys.stderr)
        return self._defunct

    @property
    def exists(self) -> bool:
        return self._exists

    # Classes overload this method to ensure a request for new resource with
    # props isn't going to duplicate an existing resource.
    # The overloading function should load and adjust the resource as needed if
    # before returning True or return False to abort.
    @property
    def verifyNewResource(self, props: dict) -> bool:
        return self._exists

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
    def region(self) -> Optional[str]:
        return self._region

    def get_region(self, **kwargs) -> Optional[str]:
        return kwargs["region"] if "region" in kwargs else self.session.default_region

    @property
    def isDirty(self) -> bool:
        return True if self._describeData and self._newData and deepdiff(self._describeData, self._newData) else False

    @property
    def tags(self) -> dict:
        if self.exists:
            return _parseTagList(self._describeData["Tags"] if "Tags" in self._describeData else {})
        return _parseTagList(self._newData["Tags"] if "Tags" in self._newData else {})

    def updateTags(self, newTags: dict) -> None:
        changes = _assembleTagList(deepdiff(self.tags, {**self.tags, **newTags}))
        print(changes)
        # call boto tag change here

    @abstractmethod
    def create(self, **kwargs) -> Optional[Self]:
        pass

    @abstractmethod
    def update(self, **kwargs) -> Optional[Self]:
        pass

    @abstractmethod
    def destroy(self, **kwargs) -> bool:
        pass

    @abstractmethod
    def refresh(self, **kwargs) -> Self:
        pass

    def print(self, **kwargs) -> None:
        output = kwargs["output"] if "output" in kwargs else self.options.args.output_format
        truncate = kwargs["truncate"] if "truncate" in kwargs else self.options.args.truncate
        header = kwargs["header"] if "header" in kwargs else self.options.args.header
        if output == cOptions.outputFormat.JSON:
            cUtils.dumpJson(self._describeData)
        else:
            if header:
                _printTableHeader(self._displayFieldOrder, self._displayFieldProps)
            _printTableLine(self, self._displayFieldOrder, self._displayFieldProps, truncate=truncate)

    def _describeDataProp(self, propName: str) -> Optional[str]:
        """fetch data based on factors such as existance, defunct-ness, etc..."""
        return (
            self._describeData[propName] if self.exists and not self.isDefunct and self._describeData.get(propName) else None
        )


# Collection of AWS resource (abstract)
class _resources(ABC):
    session = session.sessionSettings()
    options = cOptions.CmdOptions()

    def __init__(self, **kwargs) -> None:
        self._resourceCache = resourceCache(self.__class__.__name__)
        self._resourcesList = []
        self._region = self.get_region(**kwargs)

    def __iter__(self):
        return iter(self._resourcesList)

    def __getitem__(self, item):
        return self._resourcesList[item]

    def __len__(self):
        return len(self._resourcesList)

    def _fetch(self, cacheKey: str, new_resource: _resource, botoFunc: Callable, botoFuncOpts: dict = {}, **kwargs) -> Self:
        self._region = kwargs["region"] if "region" in kwargs else self.session.default_region
        if not self._resourceCache.hasRegionalDataFor(self.region):
            response: dict = botoFunc(**botoFuncOpts)
            if not _checkHttpResponse(response):
                return self
            self._resourceCache.replace(response.get(cacheKey) or [], self.region)
            # cUtils.dumpJson(response)
            # exit(1)
        r: _resource
        for r in self._resourceCache.regionalData(self.region):
            self._resourcesList.append(new_resource(_describeData=r, region=self.region))
        return self

    @abstractmethod
    def fetch(self, filter: dict = {}, **kwargs) -> Self:
        pass

    def findOne(self, nameOrIdToFind: str) -> Optional[_resource]:
        resourceL = [r for r in self._resourcesList if r.id == nameOrIdToFind or r.name == nameOrIdToFind]
        if len(resourceL) > 1:
            print(f"warn: findOne() returned {len(resourceL)} resources matching '{nameOrIdToFind}'", file=sys.stderr)
        elif not len(resourceL):
            print(f"error: findOne() found nothing matching '{nameOrIdToFind}'", file=sys.stderr)
            exit(1)
        return resourceL[0] if len(resourceL) > 0 else None

    @property
    def isEmpty(self) -> bool:
        return bool(not len(self._resourcesList))

    @property
    def resourceIdsByName(self) -> dict:
        return {r.name: r.id for r in self._resourcesList if r.name}

    @property
    def region(self) -> Optional[str]:
        return self._region

    def get_region(self, **kwargs) -> Optional[str]:
        return kwargs["region"] if "region" in kwargs else self.session.default_region

    def print(self, **kwargs) -> None:
        output = kwargs["output"] if "output" in kwargs else self.options.args.output_format
        truncate = kwargs["truncate"] if "truncate" in kwargs else self.options.args.truncate
        header = kwargs["header"] if "header" in kwargs else self.options.args.header
        if not len(self._resourcesList):
            print("no data")
            return
        d = []
        r: _resource
        for r in sorted(self._resourcesList, key=lambda x: f"{x.name} {x.id}", reverse=False):
            if header and output == cOptions.outputFormat.TEXT:
                _printTableHeader(r._displayFieldOrder, r._displayFieldProps)  # bad - private vars
                header = False
            if output == cOptions.outputFormat.JSON:
                d.append(r._describeData)  # bad - private vars
            else:
                r.print(truncate=truncate, header=False, output=output)
        if output == cOptions.outputFormat.JSON:
            cUtils.dumpJson(d)


# ------------------------------------------------------------------------------------------------

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


# ---------------------------


class security_group(_resource):
    resourceType = resourceType.SECURITY_GROUP
    _displayFieldOrder = ["name", "sgId", "desc"]
    _displayFieldProps = {"desc": {"width": 50}, "name": {"width": 25}, "sgId": {"width": 20}}

    @property
    def id(self) -> Optional[str]:
        return self._describeDataProp("GroupId")

    @property
    def name(self) -> Optional[str]:
        return self._describeData.get("GroupName") or super().name

    @property
    def sgId(self) -> Optional[str]:
        return self.id

    @property
    def desc(self) -> Optional[str]:
        return self._describeDataProp("Description")

    def refresh(self, **kwargs) -> Self:
        pass

    def update(self, **kwargs) -> bool:
        pass

    def create(self, **kwargs) -> bool:
        pass

    def destroy(self) -> bool:
        pass


class security_groups(_resources):

    def fetch(self, filter={}, **kwargs) -> Self:
        return self._fetch(
            "SecurityGroups",
            security_group,
            self.session.client("ec2", self.get_region(**kwargs)).describe_security_groups,
            {},
            **kwargs,
        )


class eip(_resource):
    resourceType = resourceType.EIP
    _displayFieldOrder = ["name", "id", "eip"]
    _displayFieldProps = {"name": {"width": 30}, "eip": {"width": 15}, "id": {"width": 26}}

    @property
    def id(self) -> Optional[str]:
        return self._describeDataProp("AllocationId")

    @property
    def allocationId(self) -> Optional[str]:
        return self.id

    @property
    def eip(self) -> str:
        return self._describeDataProp("PublicIp")

    def refresh(self, **kwargs) -> Self:
        pass

    def update(self, **kwargs) -> bool:
        pass

    def create(self, **kwargs) -> bool:
        pass

    def destroy(self) -> bool:
        pass


class eips(_resources):

    def fetch(self, filter={}, **kwargs) -> Self:
        return self._fetch(
            "Addresses",
            eip,
            self.session.client("ec2", self.get_region(**kwargs)).describe_addresses,
            {},
            **kwargs,
        )


# ---------------------------


class natgw(_resource):
    resourceType = resourceType.NATGW
    _displayFieldOrder = ["name", "natGwId"]
    _displayFieldProps = {"name": {"width": 30}, "natGwId": {"width": 24}}

    @property
    def id(self) -> Optional[str]:
        return self._describeDataProp("NatGatewayId")

    @property
    def natGwId(self) -> str:
        return self.id

    def refresh(self, **kwargs) -> Self:
        pass

    def update(self, **kwargs) -> bool:
        pass

    def create(self, **kwargs) -> bool:
        pass

    def destroy(self) -> bool:
        pass


class natgws(_resources):

    def fetch(self, filter={}, **kwargs) -> Self:
        return self._fetch(
            "NatGateways",
            natgw,
            self.session.client("ec2", self.get_region(**kwargs)).describe_nat_gateways,
            {},
            **kwargs,
        )


class igw(_resource):
    resourceType = resourceType.IGW
    _displayFieldOrder = ["name", "igwId"]
    _displayFieldProps = {"name": {"width": 30}, "igwId": {"width": 24}}

    @property
    def id(self) -> Optional[str]:
        return self._describeDataProp("InternetGatewayId")

    @property
    def igwId(self) -> str:
        return self.id

    def refresh(self, **kwargs) -> Self:
        pass

    def update(self, **kwargs) -> bool:
        pass

    def create(self, **kwargs) -> bool:
        pass

    def destroy(self) -> bool:
        pass


class igws(_resources):

    def fetch(self, filter={}, **kwargs) -> Self:
        return self._fetch(
            "InternetGateways",
            igw,
            self.session.client("ec2", self.get_region(**kwargs)).describe_internet_gateways,
            {},
            **kwargs,
        )


class route_table(_resource):
    resourceType = resourceType.ROUTE_TABLE
    _displayFieldOrder = ["name", "routeTableId"]
    _displayFieldProps = {"name": {"width": 30}, "routeTableId": {"width": 24}}

    @property
    def id(self) -> Optional[str]:
        return self._describeDataProp("RouteTableId")

    @property
    def routeTableId(self) -> str:
        return self.id

    def refresh(self, **kwargs) -> Self:
        pass

    def update(self, **kwargs) -> bool:
        pass

    def create(self, **kwargs) -> bool:
        pass

    def destroy(self) -> bool:
        pass


class route_tables(_resources):

    def fetch(self, filter={}, **kwargs) -> Self:
        return self._fetch(
            "RouteTables",
            route_table,
            self.session.client("ec2", self.get_region(**kwargs)).describe_route_tables,
            {},
            **kwargs,
        )


class subnet(_resource):
    resourceType = resourceType.SUBNET
    _displayFieldOrder = ["name", "subnetId"]
    _displayFieldProps = {"name": {"width": 30}, "subnetId": {"width": 24}}

    @property
    def id(self) -> Optional[str]:
        return self._describeDataProp("SubnetId")

    @property
    def subnetId(self) -> str:
        return self.id

    def refresh(self, **kwargs) -> Self:
        pass

    def update(self, **kwargs) -> bool:
        pass

    def create(self, **kwargs) -> bool:
        pass

    def destroy(self) -> bool:
        pass


class subnets(_resources):

    def fetch(self, filter={}, **kwargs) -> Self:
        return self._fetch(
            "Subnets", subnet, self.session.client("ec2", self.get_region(**kwargs)).describe_subnets, {}, **kwargs
        )


class vpc(_resource):
    resourceType = resourceType.VPC
    _displayFieldOrder = ["name", "vpcId", "cidrBlock"]
    _displayFieldProps = {"cidrBlock": {"width": 18}, "name": {"width": 25}, "vpcId": {"width": 21}}

    @property
    def id(self) -> Optional[str]:
        return self._describeDataProp("VpcId")

    @property
    def vpcId(self) -> str:
        return self.id

    @property
    def cidrBlock(self) -> Optional[str]:
        return self._describeDataProp("CidrBlock")

    def refresh(self, **kwargs) -> Self:
        pass

    def update(self, **kwargs) -> bool:
        pass

    def create(self, **kwargs) -> bool:
        pass

    def destroy(self) -> bool:
        pass

    # @property
    # def tgwAttachments(self) -> tgw_attachments:
    #     if not hasattr(self, "_tgwAttachments"):
    #         self._tgwAttachments = tgw_attachments().findSome(vpcId=self.id)
    #     return self._tgwAttachments


class vpcs(_resources):

    def fetch(self, filter={}, **kwargs) -> Self:
        return self._fetch("Vpcs", vpc, self.session.client("ec2", self.get_region(**kwargs)).describe_vpcs, {}, **kwargs)


# ---------------------------


class secretType(Enum):
    SIMPLE = 1  # single value (string)
    SSH_KEY = 2  # { "private": "ssh-rsa 2345hwduhasdf....", "public": "---BEGIN...." }
    RDS_MYSQL = 3  # {"username":"admin","password":"SUPERDUPERPASSWORD","engine":"mysql","host":"ecs-test.random.us-east-2.rds.amazonaws.com","port":3306,"dbname":"testdb","dbInstanceIdentifier":"ecs-test"}  # noqa


class secret(_resource):
    resourceType = resourceType.SECRET
    _displayFieldOrder = ["name", "uniq", "last_changed", "desc"]
    _displayFieldProps = {"name": {"width": 65}, "uniq": {"width": 6}, "desc": {"width": 65}, "last_changed": {"width": 23}}
    _props = {"name": str, "desc": str, "value": str, "type": secretType}

    @property
    def id(self) -> Optional[str]:
        return self._describeDataProp("ARN")

    @property
    def desc(self) -> Optional[str]:
        return self._describeDataProp("Description")

    @property
    def arn(self) -> Optional[str]:
        return self.id

    @property
    def uniq(self) -> Optional[str]:
        return self.arn[-6:] if self.arn else None

    @property
    def last_changed(self) -> Optional[str]:
        lcd = self._describeDataProp("LastChangedDate")
        return None if not lcd else f"{cUtils.convertToUtcStandardFormat(lcd)}"

    def verifyNewResource(self, props: dict) -> bool:
        if not props.get("name"):
            print("name required to create a secret", file=sys.stderr)
            return False
        response = self.session.client("secretsmanager", self.region).describe_secret(SecretId=props["name"])
        # resource does exist in cloud, load it
        if _checkHttpResponse(response):
            print("Secret is pre-existing")
            self._exists = True
            self._describeData = response
            self._details = None
            self._newData.update(props)
        return True

    def refresh(self, **kwargs) -> Self:
        if hasattr(self, "_describeData"):
            self._details = None
            self._describeData = self.details
        if hasattr(self, "__secret_value"):
            self.__secret_value = None
            self.value
        return self

    def _validate(self, secretType: secretType, json_data: str) -> bool:
        try:
            data = json.loads(json_data)
        except json.JSONDecodeError as e:
            print(f"Failed to decode JSON from '{json_data}': {e}", file=sys.stderr)
            return False
        fail = False
        if secretType == secretType.SSH_KEY:
            if not data.get("private") and not data.get("public"):
                print("One or both of private public key(s) required for SSH_KEY type", file=sys.stderr)
        elif secretType == secretType.RDS_MYSQL:
            for i in ["username", "password", "engine", "host", "port", "dbname", "dbInstanceIdentifier"]:
                if not data.get(i) or data.get(i) is None or data.get(i) == "":
                    print(f"missing required field '{i}' for RDS_MYSQL type", file=sys.stderr)
                    fail = True
            if data["engine"] != "mysql":
                print("engine must be 'mysql' for RDS_MYSQL type", file=sys.stderr)
                fail = True
            if data["port"][0] != ":":
                print("port must be prefexed with a colon :", file=sys.stderr)
                fail = True
        # if secretType == secretType.SSH_KEY:
        #     try:
        #         if not data.get("private") or not data.get("public"):
        #             print("private and public keys required for SSH_KEY type", file=sys.stderr)
        #             return False
        #         if not cUtils.isPrivateKey(data["private"]) or not cUtils.isPublicKey(data["public"]):
        #             print("invalid private or public key", file=sys.stderr)
        #             return False
        #     except Exception as e:
        #         print("error validating SSH_KEY data", file=sys.stderr)
        #         print(e, file=sys.stderr)
        #         return False
        else:
            print("Unknown secret type", file=sys.stderr)
            fail = True
        return not fail

    def create(self, **kwargs) -> Optional[Self]:
        if self.isDefunct:
            print("resource is defunct.", file=sys.stderr)
            return None

        self._region = kwargs.get("region") or self.session.default_region
        if not self._newData.get("name") or not self._newData.get("desc") or not self._newData.get("value"):
            print("name, desc and data/value all required to create a simple secret", file=sys.stderr)
            return False

        if self._newData.get("type") != secretType.SIMPLE:
            if not self._validate(self._newData.get("type"), self._newData["value"]):
                print("data validation failed", file=sys.stderr)
                return None

        if self.exists:
            # Update instead of create
            return self.update(**{**kwargs, "value": self._newData.get("value"), "desc": self._newData.get("desc")})

        response = self.session.client("secretsmanager", self.region).create_secret(
            Name=self._newData["name"],
            Description=self._newData["desc"],
            SecretString=self._newData["value"],
            Tags=[
                {"Key": "Name", "Value": self._newData["name"]},
            ],
        )
        if response.get("ResponseMetadata") != 200:
            cUtils.dumpJson(response, outputStream=sys.stderr)
            return None
        self._exists = True
        return self.refresh()

    def update(self, **kwargs) -> Optional[Self]:
        if not self.exists or self.isDefunct:
            print("secret not yet created or is defunct", file=sys.stderr)
            return None
        if kwargs.get("value"):
            response = self.session.client("secretsmanager", self.region).put_secret_value(
                SecretId=self.arn,
                SecretString=kwargs["value"],
            )
            if not _checkHttpResponse(response):
                return None
            print(f"stored version {response['VersionId']}")
        if kwargs.get("desc"):
            response = self.session.client("secretsmanager", self.region).update_secret(
                SecretId=self.arn,
                Description=kwargs["desc"],
            )
            # cUtils.dumpJson(response)
            if not _checkHttpResponse(response):
                return None
        return self.refresh()

    def destroy(self) -> bool:
        if not self.exists or self.isDefunct:
            print("secret not yet created or is defunct", file=sys.stderr)
            return False
        response = self.session.client("secretsmanager", self.region).delete_secret(
            SecretId=self.arn, RecoveryWindowInDays=7
        )
        print(f"DeletionDate: {response['DeletionDate']}")
        self._exists = False
        self._defunct = True
        return True

    @property
    def details(self) -> dict:
        if not hasattr(self, "_details"):
            response = self.session.client("secretsmanager", self.region).describe_secret(SecretId=self.arn)
            if not _checkHttpResponse(response):
                return {}
            self._details = response
        return self._details

    @property
    def _value(self) -> dict:
        if not hasattr(self, "__secret_value"):
            response = self.session.client("secretsmanager", self.region).get_secret_value(SecretId=self.arn)
            if not _checkHttpResponse(response):
                return {}
            self.__secret_value = response
        return self.__secret_value

    @property
    def value(self) -> str:
        return self._value["SecretString"]

    @property
    def valueDetails(self) -> dict:
        return self._value


class secrets(_resources):

    def fetch(self, filter={}, **kwargs) -> Self:
        return self._fetch(
            "SecretList",
            secret,
            self.session.client("secretsmanager", self.get_region(**kwargs)).list_secrets,
            {"IncludePlannedDeletion": False, "SortOrder": "asc"},
            **kwargs,
        )

    def findOne(self, nameToFind: str) -> Optional[_resource]:
        resourceL = [r for r in self._resourcesList if r.id == nameToFind or r.name == nameToFind or nameToFind in r.arn]
        if len(resourceL) > 1:
            print(f"warn: findOne() returned {len(resourceL)} resources matching '{nameToFind}'", file=sys.stderr)
        elif not len(resourceL):
            print(f"error: findOne found nothing matching '{nameToFind}'", file=sys.stderr)
            exit(1)
        return resourceL[0] if len(resourceL) > 0 else None


# ---------------------------


class resourceFactory:

    @staticmethod
    def new(r: resourceType, **kwargs) -> _resource:
        if r == resourceType.SECRET:
            return secret(**kwargs)
        # elif r == resourceType.VPC:
        #     return secret(**kwargs)
        print("resourceFactory doesn't know how to create a", r, file=sys.stderr)
        exit(1)
