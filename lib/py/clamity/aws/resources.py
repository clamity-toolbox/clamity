"""
Lowest level AWS resources with a standardized interface.
"""

from abc import ABC, abstractmethod
from typing import Optional, Self
from enum import Enum
import sys
import boto3
import deepdiff
import clamity.core.utils as cUtils
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
    _defunct = False  # True if destroy() is called
    _exists = False
    _describeData = {}
    _newData = {}
    _props = {}  # allow for prototyping properties when creating new instance
    _region = None

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
        self._session = session.sessionSettings()
        if "_describeData" in kwargs:
            self._region = kwargs.get("region") or self._session.default_region
            self._exists = True
            self._describeData = kwargs["_describeData"]
        elif kwargs.get("props"):
            # cUtils.dumpJson?(kwargs["props"])
            for p, v in kwargs["props"].items():
                if p not in self._props:
                    print(f"property {p} not allowed", file=sys.stder)
                    exit(1)
                elif not isinstance(v, self._props[p]):
                    # print(">>", p, self._props[p])
                    print(f"property '{p}' type mismatch. Should be {self._props[p]}")
                    exit(1)
                self._newData[p] = v

    @property
    def isDefunct(self) -> bool:
        if self._session.debug and self._defunct:
            print(f"debug: reporting defunct resource {self.id}", file=sys.stderr)
        return self._defunct

    @property
    def exists(self) -> bool:
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
        output = kwargs["output"] if "output" in kwargs else self._session.output
        truncate = kwargs["truncate"] if "truncate" in kwargs else True
        header = kwargs["header"] if "header" in kwargs else True
        if output == session.outputFormat.JSON:
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
    _resourcesList = []
    _region = None

    def __init__(self, **kwargs) -> None:
        self._resourceCache = resourceCache(self.__class__.__name__)
        self._session = session.sessionSettings()

    def __iter__(self):
        return iter(self._resourcesList)

    def __getitem__(self, item):
        return self._resourcesList[item]

    def __len__(self):
        return len(self._resourcesList)

    @abstractmethod
    def fetch(self, filter: dict = {}, **kwargs) -> Self:
        pass

    def findOne(self, nameOrIdToFind: str) -> Optional[_resource]:
        resourceL = [r for r in self._resourcesList if r.id == nameOrIdToFind or r.name == nameOrIdToFind]
        if len(resourceL) > 1:
            print(f"warn: findOne() returned {len(resourceL)} resources matching '{nameOrIdToFind}'", sys.stdout)
        elif not len(resourceL):
            print(f"error: findOne() found nothing matching '{nameOrIdToFind}'", sys.stdout)
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

    def print(self, **kwargs) -> None:
        output = kwargs["output"] if "output" in kwargs else self._session.output
        truncate = kwargs["truncate"] if "truncate" in kwargs else True
        header = kwargs["header"] if "header" in kwargs else True
        if not len(self._resourcesList):
            print("no data")
            return
        d = []
        r: _resource
        for r in self._resourcesList:
            if header and output == session.outputFormat.TEXT:
                _printTableHeader(r._displayFieldOrder, r._displayFieldProps)  # bad - private vars
                header = False
            if output == session.outputFormat.JSON:
                d.append(r._describeData)  # bad - private vars
            else:
                r.print(truncate=truncate, header=False, output=output)
        if output == session.outputFormat.JSON:
            cUtils.dumpJson(d)


# ------------------------------------------------------------------------------------------------

# class security_group(resource):
#     resourceType = "security_group"


# class security_groups(resources):
#     resourceType = "security_groups"

#     def __init__(self):
#         super().__init__()
#         for r in self._resourceCache.get(self.resourceType):
#             self._resources.append(security_group(r))

# ---------------------------


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

# ---------------------------


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

# ---------------------------

# class igw(resource):
#     resourceType = "igw"


# class igws(resources):
#     resourceType = "igws"

#     def __init__(self):
#         super().__init__()
#         for r in self._resourceCache.get(self.resourceType):
#             self._resources.append(igw(r))

# ---------------------------

# class natgw(resource):
#     resourceType = "natgw"


# class natgws(resources):
#     resourceType = "natgws"

#     def __init__(self) -> None:
#         super().__init__()
#         for r in self._resourceCache.get(self.resourceType)["NatGateways"]:
#             self._resources.append(natgw(r, id=r["NatGatewayId"]))

# ---------------------------

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


# class subnet(resource):
#     resourceType = "subnet"


# class subnets(resources):
#     resourceType = "subnets"

#     def __init__(self) -> None:
#         super().__init__()
#         for r in self._resourceCache.get(self.resourceType):
#             self._resources.append(subnet(r))


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
        if not self._resourceCache.hasRegionalDataFor(self.region):
            response = boto3.client("ec2", **{"region_name": self.region}).describe_vpcs()
            if not _checkHttpResponse(response):
                return self
            self._resourceCache.replace(response["Vpcs"] if "Vpcs" in response else [], self.region)
        r: _resource
        for r in self._resourceCache.regionalData(self.region):
            self._resourcesList.append(vpc(_describeData=r), self.region)
        return self


# ---------------------------


class secretType(Enum):
    SIMPLE = 1


class secret(_resource):
    resourceType = resourceType.SECRET
    _displayFieldOrder = ["name", "uniq", "last_changed", "desc"]
    _displayFieldProps = {"name": {"width": 30}, "uniq": {"width": 6}, "desc": {"width": 50}, "last_changed": {"width": 23}}
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

    def refresh(self, **kwargs) -> Self:
        if hasattr(self, "_describeData"):
            self._details = None
            self._describeData = self.details
        if hasattr(self, "__value"):
            self.__value = None
            self.value
        return self

    def create(self, **kwargs) -> Optional[Self]:
        if self.exists or self.isDefunct:
            print("Cannot create resource if it exists or is defunct.", file=sys.stderr)
            return None
        if self._newData.get("type") == secretType.SIMPLE:
            if not self._newData.get("name") or not self._newData.get("desc") or not self._newData.get("value"):
                print("name, desc and value all required to create a simple secret", file=sys.stderr)
                return False
            response = boto3.client("secretsmanager", **{"region_name": self.region}).create_secret(
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
        else:
            print("don't know how to create type")
            return None
        return self.refresh()

    def update(self, **kwargs) -> Optional[Self]:
        if not self.exists or self.isDefunct:
            print("secret not yet created or is defunct", file=sys.stderr)
            return None
        if kwargs.get("value"):
            response = boto3.client("secretsmanager", **{"region_name": self.region}).put_secret_value(
                SecretId=self.arn,
                SecretString=kwargs["value"],
            )
            if not _checkHttpResponse(response):
                return None
            print(f"stored version {response['VersionId']}")
        if kwargs.get("desc"):
            response = boto3.client("secretsmanager", **{"region_name": self.region}).update_secret(
                SecretId=self.arn,
                Description=kwargs["desc"],
            )
            cUtils.dumpJson(response)
            if not _checkHttpResponse(response):
                return None
        return self.refresh()

    def destroy(self) -> bool:
        if not self.exists or self.isDefunct:
            print("secret not yet created or is defunct", file=sys.stderr)
            return False
        response = boto3.client("secretsmanager", **{"region_name": self.region}).delete_secret(
            SecretId=self.arn, RecoveryWindowInDays=7
        )
        print(f"DeletionDate: {response['DeletionDate']}")
        self._exists = False
        self._defunct = True
        return True

    @property
    def details(self) -> dict:
        if not hasattr(self, "_details"):
            response = boto3.client("secretsmanager", **{"region_name": self.region}).describe_secret(SecretId=self.arn)
            if not _checkHttpResponse(response):
                return {}
            self._details = response
        return self._details

    @property
    def _value(self) -> dict:
        if not hasattr(self, "__value"):
            response = boto3.client("secretsmanager", **{"region_name": self.region}).get_secret_value(SecretId=self.arn)
            if not _checkHttpResponse(response):
                return {}
            self.__value = response
        return self.__value

    @property
    def value(self) -> str:
        return self._value["SecretString"]

    @property
    def valueDetails(self) -> dict:
        return self._value


class secrets(_resources):

    def fetch(self, filter={}, **kwargs) -> Self:
        boto_opts = self._session.botoRequestOptions(**kwargs)
        if not self._resourceCache.hasRegionalDataFor(self.region):
            response = boto3.client("secretsmanager", **boto_opts).list_secrets(
                IncludePlannedDeletion=False,
                SortOrder="asc",
            )
            if not _checkHttpResponse(response):
                return self
            self._resourceCache.replace(response.get("SecretList") or [], self.region)
        r: _resource
        for r in self._resourceCache.regionalData(self.region):
            self._resourcesList.append(secret(_describeData=r))
        return self

    def findOne(self, nameToFind: str) -> Optional[_resource]:
        resourceL = [r for r in self._resourcesList if r.id == nameToFind or r.name == nameToFind or nameToFind in r.arn]
        if len(resourceL) > 1:
            print(f"warn: findOne() returned {len(resourceL)} resources matching '{nameToFind}'", sys.stdout)
        elif not len(resourceL):
            print(f"error: findOne found nothing matching '{nameToFind}'")
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
