import os
import argparse
import glob
import collectutility
import analysisutility
import excelutility
from plugins import PluginCollection


def collectMain():
    fullPath = os.path.join(os.getcwd(), 'AVAS.yaml')
    print(f'\nConfiguration File Path : {fullPath}')
    doc = collectutility.readConfig(fullPath)
    pluginModules = PluginCollection(doc['assetType'], doc['assetSubType'], doc['assetCode']).plugins
    # print(f'pluginModules : {pluginModules}')
    fileName = collectutility.mergeScript(doc, pluginModules, os.getcwd())
    print('... Merge Script Finished!')
   # print(f'Script File : {fileName}\n')


def analysisMain():
    fullPath = os.path.join(os.getcwd(), 'InputResult')
    print(f'Input Result Collection XML File Directory : {fullPath}\n')
    resultFileList = glob.glob(f'{fullPath}/*.xml')
    print(resultFileList)
    # analysisutility.xmlResultFileParser(resultFileList[1])
    for resultFile in resultFileList:
        print(f'Collect File : {resultFile}')
        assetInfo, sysInfo, infoDict, fileDict = analysisutility.xmlResultFileParser(resultFile)
        print('... Result xml File Parsing Success!')
        analysisRes = analysisutility.assetDistribution(assetInfo, sysInfo, infoDict, fileDict)
        # print(f'analysisRes : {analysisRes}')
        excelFile = excelutility.makeExcelReport(analysisRes, sysInfo)
        print('... Final Result Report Successfully Created!')
        print(f'Report File : {excelFile}\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog='avas', usage='%(prog)s [ AVAS MOD ] [options]',
        description='Automated Vulnerability Analysis System',
    )

    parser.add_argument('avas_mod', metavar='AVAS_MOD', help='collect [ ... ] or analysis [ ... ]')

    args = parser.parse_args()
    print(f'[ Start {args.avas_mod} Module ]\n')
    if args.avas_mod == 'collect':
        collectMain()
    elif args.avas_mod == 'analysis':
        analysisMain()
    else:
        parser.print_help()
    print(f'[ End {args.avas_mod} Module ]\n')
