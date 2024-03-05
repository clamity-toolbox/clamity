"""
Clamity - Development & Operations Toolbox

The Clamity toolbox includes this python module which provides
a large number of useful classes for accessing many functions
and processes of the platform.

"""

import sys
if sys.version_info.major + (sys.version_info.minor * .1) < 3.10:
	print("python 3.10 or greater is required for the devtools package")
	exit(1)

from . import core
from . import aws
