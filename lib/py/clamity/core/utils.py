"""Utility functions"""

import sys
import datetime
import json


def dumpJson(d: dict, outputStream=sys.stdout) -> None:
    """Dump a dictionary as JSON with sorted keys"""

    def jsonDateTimeHandler(x):
        if isinstance(x, datetime.datetime) or isinstance(x, datetime.date):
            return x.isoformat()
        return str(type(x))

    print(json.dumps(d, default=jsonDateTimeHandler, sort_keys=True, indent=4), file=outputStream)


def dumpObj(o: any, **kwargs) -> None:
    """Dump object properties as a JSON object (serializes)"""
    d = {}
    for p in dir(o):
        if not p.startswith("_"):
            d[p] = getattr(o, p)
    dumpJson(d, **kwargs)
