
from setuptools import setup

setup(name='clamity',
	  version='0.1',
	  description='Clamity - A Development & Operations Toolbox',
	  url='http://github.com/jimmyjayp/clamity',
	  author='James Price',
	  author_email='jimmyjayp@gmail.com',
	  license='MIT',
	  packages=['clamity'],
      install_requires = [
          'boto3'
	  ],
	  zip_safe=False)
