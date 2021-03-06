from importlib import import_module
import inspect
import pkgutil
from abc import *
import re
import collections
import operator

OPS = {
    '<': operator.lt,
    '<=': operator.le,
    '==': operator.eq,
    '!=': operator.ne,
    '>=': operator.ge,
    '>': operator.gt,
    'in': operator.contains
}


def fileStatSetup(setString):
    data = f'[ 권한 = {setString[0]}({setString[1]}), 소유자 = {setString[5]}({setString[6]}),' \
           f' 소유그룹 = {setString[7]}({setString[8]}) ]'

    return data


class Plugin(metaclass=ABCMeta):
    def __init__(self):
        self.code = None         # 항목코드
        self.codeScript = None   # 항목 수집 스크립트
        self.codeExcute = None  # 항목 실행 구문(쉘 스크립트) or 항목 코드 변수(배치 스크립트)
        self.description = None    # 항목 설명 (항목 구분, 항목명, 중요도, 판단기준 등)
        self.stat = {}           # 분석 결과 상태 저장

    # 각 모듈별 변수 값을 리턴해주는 함수
    def getCode(self):
        return self.code

    def getScript(self):
        return self.codeScript

    def getScriptExecute(self):
        return self.codeExcute

    def getDescription(self):
        return self.description

    @abstractmethod
    def analysisFunc(self, sysInfo, infoDict, fileDict):
        pass

    def processCheck(self, sysInfo, getValue):
        keyValue = f'{getValue}_PS'
        self.stat.update({keyValue: f'- Not Found {getValue} Process\n'})
        flag = 0
        if 'processInfo' in sysInfo.keys():
            valueStr = ''.join(f'{line}\n' for line in sysInfo['processInfo'].split('\n') if getValue in line)
            if valueStr != '':
                self.stat.update({keyValue: valueStr})
                flag = 1
        return flag

    def portCheck(self, sysInfo, getValue, srvName):
        keyValue = f'{srvName}_PORT'
        self.stat.update({keyValue: f'- Not Found {srvName} Port\n'})
        flag = 0
        if 'portInfo' in sysInfo.keys():
            valueStr = ''.join(f'{line}\n' for line in sysInfo['portInfo'].split('\n') if getValue in line)
            if valueStr != '':
                self.stat.update({keyValue: valueStr})
                flag = 1

        return flag

    def serviceCheck(self, sysInfo, getValue, srvName, compValue=None):
        keyValue = f'{srvName}_SYS'
        self.stat.update({keyValue: f'- Not Found {srvName} Service\n'})
        flag = 0
        if compValue is None:
            compValue = srvName
        if 'serviceInfo' in sysInfo.keys():
            valueStr = ''.join(f'{line}\n' for line in sysInfo['serviceInfo'].split('\n') for value in getValue if value in line)
            if valueStr != '':
                self.stat.update({keyValue: valueStr})
                if compValue in self.stat[keyValue]:
                    flag = 1

        return flag

    def getFileName(self, infoList, fileDict, getValue, compValue=None):
        fileKey = None
        reBool = True
        match = [x for x in infoList if getValue in x]
        if match:
            if match[0] in fileDict.keys():
                fileKey = f'FILEDATA:{match[0]}'
                self.stat.update({fileKey: fileDict[match[0]]['fileData']})
        if fileKey is None:
            fileKey = f'FILEDATA:{getValue}'
            if compValue == 'exist':
                self.stat.update({fileKey: f' - Not Found {getValue} Configuration File\n'})
            else:
                self.stat.update({fileKey: f' - Not Found {getValue} Configuration File(!)\n'})
            reBool = False

        return reBool, fileKey

    def getConfig(self, key, pattern, confName, parseKey):
        reBool = False
        com = re.compile(pattern, re.MULTILINE)
        reg = re.findall(com, self.stat[key])
        if reg:
            self.stat.update({key: ''.join(f'{line}\n' for line in reg)})
            if parseKey == 'exist':     # 설정 있어야 양호
                reBool = True
            elif parseKey == '!exist':  # 설정 없어야 양호
                self.stat.update({key: self.stat[key].replace('\n', '(!)\n')})
        elif parseKey == '!exist':
            self.stat.update({key: f'- Not Found {confName} Configuration\n'})
            reBool = True
        else:
            self.stat.update({key: f'- Not Found {confName} Configuration(!)\n'})

        return reBool

    def compStrValue(self, key, pattern, compValue, compType):
        reCnt = 0
        com = re.compile(pattern, re.MULTILINE)
        reg = re.findall(com, self.stat[key])
        if reg:
            cmpOper = OPS[compType]
            if compType == 'in':
                if cmpOper(reg[0], compValue):
                    reCnt += 1
                else:
                    self.stat.update({key: self.stat[key].replace('\n', '(!)\n')})
            else:
                if cmpOper(compValue, reg[0]):
                    reCnt += 1
                else:
                    self.stat.update({key: self.stat[key].replace('\n', '(!)\n')})

        return reCnt

    def compNumValue(self, key, pattern, compValue, compType):
        reCnt = 0
        com = re.compile(pattern, re.MULTILINE)
        reg = re.findall(com, self.stat[key])
        if reg:
            cmpOper = OPS[compType]
            if not cmpOper(compValue, reg[0]):
                self.stat.update({key: self.stat[key].replace('\n', '(!)\n')})
            else:
                reCnt += 1

        return reCnt

    def filePermCheck(self, fileDict, key, compPerm, compOwner, compType):
        cmpOper = OPS[compType]
        fileKey = f'FILEPERM:{key}'
        if 'fileRealStat' in fileDict[key].keys():
            fileStat = fileDict[key]['fileRealStat'].split('|')
            self.stat.update({f'FILEPERM:{fileDict[key]["fileRealStat"].split("|")[4]}': fileStatSetup(fileStat)})
            self.stat.update({fileKey: fileStatSetup(fileDict[key]['fileStat'].split('|'))})
        else:
            fileStat = fileDict[key]['fileStat'].split('|')
            self.stat.update({fileKey: fileStatSetup(fileStat)})

        filePerm = fileStat[1] if fileStat[1] != '0' else '0' * len(compPerm)
        fileOwner = fileStat[5]
        permBool = True
        ownerBool = True
        reBool = False

        if compPerm is not None:
            for i in range(0, len(filePerm)):
                if not cmpOper(filePerm[i], compPerm[i]):
                    permBool = False
                    break

        if compOwner is not None:
            if fileOwner != compOwner:
                ownerBool = False

        if permBool and ownerBool:
            reBool = True

        return reBool

    def cmdStrGetValue(self, newKey, infoList, infoKey, pattern, compValue, compType):
        reCnt = 0
        reStr = ''
        reBool = True
        for data in infoList[infoKey].splitlines():
            com = re.compile(pattern, re.MULTILINE)
            reg = re.findall(com, data)
            if reg:
                if compType == '|':
                    for comp in compValue.split('|'):
                        if comp in reg[0]:
                            data += '(!)'
                            reBool = False

                else:
                    cmpOper = OPS[compType]
                    if compType == 'in':
                        if cmpOper(reg[0], compValue):
                            data += '(!)'
                            reBool = False
                    else:
                        if cmpOper(compValue, reg[0]):
                            data += '(!)'
                            reBool = False
            reStr += f'{data}\n'
        if reBool:
            reCnt = 1
        self.stat.update({newKey : reStr})

        return reCnt


class PluginCollection:
    def __init__(self, assetType, assetSubType, code=None):
        self.type = ''.join(assetType)          # 리스트 안에 있는 값을 문자열로 저장
        self.subType = ''.join(assetSubType)
        self.code = code
        self.plugins = []
        self.loadPackage('plugins')

    def loadPackage(self, package):
        imported = import_module(f'{package}.{self.type}.{self.subType}')
        # print(f'imported : {imported}')
        for _, name, ispkg in pkgutil.iter_modules(imported.__path__, imported.__name__ + '.'):
            # print(f'name : {name}')
            pluginModule = import_module(name)
            # print(f'pluginModule : {pluginModule}')
            clsmembers = inspect.getmembers(pluginModule, inspect.isclass)
            # print(f'clsmembers : {clsmembers}')
            for _, memClass in clsmembers:
                # print(f'memClass : {memClass}')
                if issubclass(memClass, Plugin) & (memClass is not Plugin):
                    module = memClass()
                    # print(f'module.getcode : {module.getCode()}')
                    # print(f'self.code : {self.code}')
                    if module.getCode() in self.code:
                        self.plugins.append(memClass())
