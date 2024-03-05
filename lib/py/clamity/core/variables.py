"""
Structured Variables
"""

from typing import Optional
import os
import re
import json


class StructuredVariable:
	def __init__(self, var: str, varData: dict) -> None:
		self.name = var
		self._data = varData

	def _strIsFalse(self, data: str) -> bool:
		return True if re.search(r'^(0|no|n|false|f|off)$', data, re.IGNORECASE) else False

	def _strIsTrue(self, data: str) -> bool:
		return not self._isFalse(data)

	def _castTo(self, val: bool|str|int|float) -> bool|str|int|float:
		if self._data['type'] == 'bool':
			return self._strIsTrue(val) if type(val) is str else val if type(val) is 'bool' else bool(val)
		if self._data['type'] == 'number':
			if type(val) is str:
				return float(val) if '.' in val else int(val)
			return 0 if type(val) is bool else val
		if self._data['type'] == str:
			return val
		print(f"variable {self.name} declared as unknown type")
		raise TypeError

	@property
	def groups(self) -> list:
		return self._data['groups']

	@property
	def default(self) -> Optional[str]:
		eVar = self._data['envVar'] if 'envVar' in self._data and self._data['envVar'] else None
		eVal = os.environ[eVar] if eVar is not None and eVar in os.environ else None
		defaultVal = eVal or (self._data['default'] if 'default' in self._data else None)
		return self._castTo(defaultVal)

VariableCache = {}
class StructuredVariables:
	def __init__(self, varFiles: str|list, **kwargs) -> None:
		global VariableCache
		self._vars = VariableCache
		self._kwargs = kwargs
		self.addFiles(varFiles)

	def addFiles(self, varFiles: str|list) -> None:
		for vfile in [varFiles] if type(varFiles) is str else varFiles:
			with open(f"{os.environ['CLAMITY_ROOT']}/etc/variables/{vfile}", 'r') as f:
				newVars = json.load(f)['variables']
				implicitGroup = vfile.removesuffix('.json')
				for svar in newVars.keys():
					if 'groups' not in newVars[svar]:
						newVars[svar]['groups'] = []
					newVars[svar]['groups'] += [implicitGroup]
				self._vars.update(newVars)
		if hasattr(self, '_variablesByGroup'):
			delattr(self, '_variablesByGroup')

	@property
	def variablesByGroup(self) -> dict:
		"""returns { group: { var1: StructuredVariable, var2: ...}}"""
		if not hasattr(self, '_variablesByGroup'):
			self._variablesByGroup = {}
			for svar in self._vars.keys():
				for group in self._vars[svar]['grousp']:
					if group not in self._variablesByGroup:
						self._variablesByGroup[group] = {}
					self._variablesByGroup[group][svar] = StructuredVariable(svar, self._vars[svar])
		return self._variablesByGroup

	def variable(self, var: str) -> StructuredVariable:
		return self._vars[var] if var in self._vars else {}
