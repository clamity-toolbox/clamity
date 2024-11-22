"""
Clamity - Development & Operations Toolbox

The Clamity toolbox includes this python module which provides a large number of
useful classes for wrapping any number of service (for example, working with ssh
keys), making common dev ops tasks easier for the end user.
"""

import sys
if sys.version_info.major + (sys.version_info.minor * .1) < 3.10:
	print("python 3.10 or greater is required for the devtools package")
	exit(1)

from . import core
from . import aws
