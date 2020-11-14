import os
import yaml
import datetime
import stat


def readConfig(confPath):
    document = yaml.load(open(confPath, 'r', encoding='UTF-8'), Loader=yaml.SafeLoader)
    doc = document['assetInfo']
    print(f"""
... Current Configuration File Settings
    TYPE : {doc['assetType']}, SUBTYPE : {doc['assetSubType']}, CODE : {doc['assetCode']}
    """)

    return doc


def readScript(baseFileList, baseDir):
    fullString = ''
    for baseFile in baseFileList:
        fullFilePath = os.path.join(baseDir, baseFile)
        with open(fullFilePath, 'r', encoding='UTF-8') as f:
            lines = f.readlines()
            data = ''.join([line for line in lines if line[0] != '#' if not line.startswith('::')])
            fullString += data + '\n'

    return fullString


def mergeScript(document, plugins, getPwd):
    dt = datetime.datetime.now().strftime("%Y%m%d%H%M%S")
    assetType = document['assetType'][0]
    assetSubType = document['assetSubType'][0]

    libList = {
        'batch': ['@echo off\n', 'bat', f'set ASSETTYPE={assetType}', f'set ASSETSUBTYPE={assetSubType}'],
        'shell': ['#!/bin/sh\n', 'sh', f'ASSETTYPE={assetType}', f'ASSETSUBTYPE={assetSubType}'],
    }
    libName = 'batch' if assetType.lower() == 'windows' else 'shell'
    FILEHEADER = libList[libName][0]
    FILEEXT = libList[libName][1]

    LIBDIR = os.path.join(getPwd, 'LibScript', libName)

    LIBPRE = readScript([f'lib_{libName}_preprocess.inc'], LIBDIR)
    ASSETINFO = f'{libList[libName][2]}\n{libList[libName][3]}\n'
    LIBAUTO = readScript([f'lib_{libName}_autostruct.inc'], LIBDIR)

    code_script = [data.getScript() for data in plugins]
    code_funcList = [data.getScriptExecute() for data in plugins]
    if libName == 'batch':
        SCRIPTMID = LIBAUTO + '\n'.join(code_funcList) + '\n'.join(code_script)
    else:
        LIBXML = readScript(['lib_shell_xml.inc', 'lib_shell_encode.inc'], LIBDIR)
        SCRIPTMID = LIBXML + '\n'.join(code_script) + '\n' + LIBAUTO + '\n'.join(code_funcList)

    LIBPOST = readScript([f'lib_{libName}_postprocess.inc'], LIBDIR)

    NEWSCRIPTFILE = os.path.join(getPwd, f'{assetType.lower()}_{assetSubType.lower()}_{dt}.{FILEEXT}')
    with open(NEWSCRIPTFILE, 'w', encoding='UTF-8', newline='\n') as newFile:
        newFile.write(FILEHEADER)
        newFile.write(LIBPRE)
        newFile.write(ASSETINFO)
        newFile.write(SCRIPTMID)
        newFile.write(LIBPOST)

    os.chmod(NEWSCRIPTFILE, stat.S_IRUSR | stat.S_IWUSR | stat.S_IXUSR)
    return NEWSCRIPTFILE