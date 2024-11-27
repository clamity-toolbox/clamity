"""Utility functions"""

import sys
from datetime import datetime, timezone
import json


def dumpJson(d: any, outputStream=sys.stdout) -> None:
    """Dump a dictionary as JSON with sorted keys"""

    def jsonDateTimeHandler(x):
        if isinstance(x, datetime) or isinstance(x, datetime.date):
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


def shortenWithElipses(s: str, length: int) -> str:
    """if s > len chars, truncate to len - 3 and add elipses (...)"""
    return s if len(s) <= length else s[: length - 3] + "..."


def convertToUtcStandardFormat(dt: datetime) -> str:
    """Converts a naive datetime object to UTC."""
    # if timezone-aware else convert naive datetime to UTC
    return (dt.astimezone(timezone.utc) if dt.tzinfo is not None else dt.replace(tzinfo=timezone.utc)).strftime(
        "%Y-%m-%d.%H:%M:%S.UTC"
    )
