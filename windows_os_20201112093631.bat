@echo off
setlocal
chcp 437>nul
PUSHD %~DP0

set DATETEXT=%date:-=%
set hh=%time:~0,2%
set hh1=%hh:~0,1%
set hh2=%hh:~1,1%
if "%hh1%" == " " set hh=0%hh2%
set TIMETEXT=%hh%%time:~3,2%%time:~6,2%
for /f "tokens=*" %%a in ('hostname') do set HOSTNAME=%%a

set RESULT_COLLECT_FILE=result_collect_%HOSTNAME%_%DATETEXT%%TIMETEXT%.xml
set RESULT_FILE_DATA_FILE=result_file_data_%HOSTNAME%_%DATETEXT%%TIMETEXT%.xml

net session>nul 2>&1
if not ERRORLEVEL 0 (
	echo.
	echo =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
	echo.
	echo This script must be run as admin.
	echo.
	echo =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
	echo.
	pause>nul
	exit
)

set checksumvalue=DUP

set ASSETTYPE=WINDOWS
set ASSETSUBTYPE=OS
echo ^<?xml version="1.0" encoding="UTF-8"?^> > %RESULT_COLLECT_FILE%
echo ^<root^> >> %RESULT_COLLECT_FILE%
echo     ^<assetInfo^> >> %RESULT_COLLECT_FILE%
echo         ^<assetType^>%ASSETTYPE%^</assetType^> >> %RESULT_COLLECT_FILE%
echo         ^<assetSubType^>%ASSETSUBTYPE%^</assetSubType^> >> %RESULT_COLLECT_FILE%
echo     ^</assetInfo^> >> %RESULT_COLLECT_FILE%
echo     ^<sysInfo^> >> %RESULT_COLLECT_FILE%

systeminfo > systeminfo.txt
for /f "tokens=1,2 delims=:" %%a in ('"findstr /bic:"OS Name" systeminfo.txt"') do set OSNAME=%%b
for /f "tokens=1,2 delims=:" %%a in ('"findstr /bic:"OS Version" systeminfo.txt"') do set OSVERSION=%%b
for /f "tokens=1,2 delims=:" %%a in ('"findstr /bic:"OS Host Name" systeminfo.txt"') do set HOSTNAME=%%b

set OSNAME=%OSNAME: =%
set OSVERSION=%OSVERSION: =%
set HOSTNAME=%HOSTNAME: =%

echo         ^<osType^>Windows^</osType^> >> %RESULT_COLLECT_FILE%
echo         ^<osName^>%OSNAME%^</osName^> >> %RESULT_COLLECT_FILE%
echo         ^<osVersion^>%OSVERSION%^</osVersion^> >> %RESULT_COLLECT_FILE%
echo         ^<hostname^>%HOSTNAME%^</hostname^> >> %RESULT_COLLECT_FILE%

certutil > nul
if ERRORLEVEL 0 (set ENCTYPE=base64) else (set ENCTYPE=NULL)
echo         ^<encType^>%ENCTYPE%^</encType^> >> %RESULT_COLLECT_FILE%

ipconfig | more > iplist.txt
call :base64encode iplist.txt
echo         ^<ipList^>^<!^[CDATA^[ >> %RESULT_COLLECT_FILE%
for /f "delims=" %%a in (base64.txt) do echo %%a >> %RESULT_COLLECT_FILE%
echo         ^]^]^>^</ipList^> >> %RESULT_COLLECT_FILE%

tasklist | more > tasklist.txt
call :base64encode tasklist.txt
echo         ^<processInfo^>^<!^[CDATA^[ >> %RESULT_COLLECT_FILE%
for /f "delims=" %%a in (base64.txt) do echo %%a >> %RESULT_COLLECT_FILE%
echo         ^]^]^>^</processInfo^> >> %RESULT_COLLECT_FILE%

netstat -ano | more > portlist.txt
call :base64encode portlist.txt
echo         ^<portInfo^>^<!^[CDATA^[ >> %RESULT_COLLECT_FILE%
for /f "delims=" %%a in (base64.txt) do echo %%a >> %RESULT_COLLECT_FILE%
echo         ^]^]^>^</portInfo^> >> %RESULT_COLLECT_FILE%

net start | more > servicelist.txt
call :base64encode servicelist.txt
echo         ^<serviceInfo^>^<!^[CDATA^[ >> %RESULT_COLLECT_FILE%
for /f "delims=" %%a in (base64.txt) do echo %%a >> %RESULT_COLLECT_FILE%
echo         ^]^]^>^</serviceInfo^> >> %RESULT_COLLECT_FILE%

echo     ^</sysInfo^> >> %RESULT_COLLECT_FILE%

echo     ^<fileList^> > %RESULT_FILE_DATA_FILE%

set CODE001=W-01
set CODE002=W-02
set CODE008=W-08
set CODE032=W-32
set CODE035=W-35
set CODE037=W-37
set CODE040=W-40
echo    ^<infoElement code="%CODE001%"^> >> %RESULT_COLLECT_FILE%

net user Administrator | findstr /bic:"Account active" > administrator_tmp.txt
if ERRORLEVEL 0 (
    call :base64encode administrator_tmp.txt
    echo        ^<command name="ADMIN_ACCOUNT"^>^<!^[CDATA^[ >> %RESULT_COLLECT_FILE%
    for /f "delims=" %%a in (base64.txt) do echo %%a >> %RESULT_COLLECT_FILE%
    echo        ^]^]^>^</command^> >> %RESULT_COLLECT_FILE%
)
if exist administrator_tmp.txt (
    del /q administrator_tmp.txt
)

echo    ^</infoElement^> >> %RESULT_COLLECT_FILE%

secedit /export /cfg secpolicy_tmp.txt > nul
type secpolicy_tmp.txt | more > secpolicy.txt
del /q secpolicy_tmp.txt
if ERRORLEVEL 0 (
    call :fileCheckSum secpolicy.txt, checksumvalue
    if not "%checksumvalue%" == "DUP" (
        echo    ^<fileInfo^> >> %RESULT_FILE_DATA_FILE%
        echo    ^<filePath checksum="%checksumvalue%"^>^<!^[CDATA^[Local Security Policy^]^]^>^</filePath^> >> %RESULT_FILE_DATA_FILE%
        call :base64encode secpolicy.txt
        echo    ^<fileData^>^<!^[CDATA^[ >> %RESULT_FILE_DATA_FILE% 
        for /f "delims=" %%a in (base64.txt) do echo %%a >> %RESULT_FILE_DATA_FILE%
        echo    ^]^]^>^</fileData^> >> %RESULT_FILE_DATA_FILE%
        echo    ^</fileInfo^> >> %RESULT_FILE_DATA_FILE%
    )
)
if exist secpolicy.txt (
    del /q secpolicy.txt
)

echo %CODE001% Collect


echo    ^<infoElement code="%CODE002%"^> >> %RESULT_COLLECT_FILE%

net user guest | findstr /bic:"Account active" > guest_tmp.txt
if ERRORLEVEL 0 (
    call :base64encode guest_tmp.txt
    echo        ^<command name="GUEST_ACCOUNT"^>^<!^[CDATA^[ >> %RESULT_COLLECT_FILE%
    for /f "delims=" %%a in (base64.txt) do echo %%a >> %RESULT_COLLECT_FILE%
    echo        ^]^]^>^</command^> >> %RESULT_COLLECT_FILE%
)
if exist guest_tmp.txt (
    del /q guest_tmp.txt
)

echo    ^</infoElement^> >> %RESULT_COLLECT_FILE%

secedit /export /cfg secpolicy_tmp.txt > nul
type secpolicy_tmp.txt | more > secpolicy.txt
del /q secpolicy_tmp.txt
if ERRORLEVEL 0 (
    call :fileCheckSum secpolicy.txt, checksumvalue
    if not "%checksumvalue%" == "DUP" (
        echo    ^<fileInfo^> >> %RESULT_FILE_DATA_FILE%
        echo    ^<filePath checksum="%checksumvalue%"^>^<!^[CDATA^[Local Security Policy^]^]^>^</filePath^> >> %RESULT_FILE_DATA_FILE%
        call :base64encode secpolicy.txt
        echo    ^<fileData^>^<!^[CDATA^[ >> %RESULT_FILE_DATA_FILE% 
        for /f "delims=" %%a in (base64.txt) do echo %%a >> %RESULT_FILE_DATA_FILE%
        echo    ^]^]^>^</fileData^> >> %RESULT_FILE_DATA_FILE%
        echo    ^</fileInfo^> >> %RESULT_FILE_DATA_FILE%
    )
)

if exist secpolicy.txt (
    del /q secpolicy.txt
)

echo %CODE002% Collect


echo    ^<infoElement code="%CODE008%"^> >> %RESULT_COLLECT_FILE%

net share | more > default_share_tmp.txt
if ERRORLEVEL 0 (
    call :base64encode default_share_tmp.txt
    echo        ^<command name="DEFAULT_SHARE"^>^<!^[CDATA^[ >> %RESULT_COLLECT_FILE%
    for /f "delims=" %%a in (base64.txt) do echo %%a >> %RESULT_COLLECT_FILE%
    echo        ^]^]^>^</command^> >> %RESULT_COLLECT_FILE%
)
if exist default_share_tmp.txt (
    del /q default_share_tmp.txt
)

reg query "HKLM\SYSTEM\CurrentControlSet\Services\lanmanserver\parameters" /s /v AutoShareServer > autoshare_server_reg_tmp.txt
if ERRORLEVEL 0 (
    call :base64encode autoshare_server_reg_tmp.txt
    echo        ^<command name="AUTOSHARE_SERVER_REG"^>^<!^[CDATA^[ >> %RESULT_COLLECT_FILE%
    for /f "delims=" %%a in (base64.txt) do echo %%a >> %RESULT_COLLECT_FILE%
    echo        ^]^]^>^</command^> >> %RESULT_COLLECT_FILE%
)
if exist autoshare_server_reg_tmp.txt (
    del /q autoshare_server_reg_tmp.txt
)

reg query "HKLM\SYSTEM\CurrentControlSet\Services\lanmanserver\parameters" /s /v AutoShareWks > autoshare_wks_reg_tmp.txt
if ERRORLEVEL 0 (
    call :base64encode autoshare_wks_reg_tmp.txt
    echo        ^<command name="AUTOSHARE_WKS_REG"^>^<!^[CDATA^[ >> %RESULT_COLLECT_FILE%
    for /f "delims=" %%a in (base64.txt) do echo %%a >> %RESULT_COLLECT_FILE%
    echo        ^]^]^>^</command^> >> %RESULT_COLLECT_FILE%
)
if exist autoshare_wks_reg_tmp.txt (
    del /q autoshare_wks_reg_tmp.txt
)

echo    ^</infoElement^> >> %RESULT_COLLECT_FILE%

echo %CODE008% Collect


echo    ^<infoElement code="%CODE032%"^> >> %RESULT_COLLECT_FILE%

wmic qfe list brief /format:texttablewsys | more > hotfix_tmp.txt
if ERRORLEVEL 0 (
    call :base64encode hotfix_tmp.txt
    echo        ^<command name="WINDOWS HOTFIX"^>^<!^[CDATA^[ >> %RESULT_COLLECT_FILE%
    for /f "delims=" %%a in (base64.txt) do echo %%a >> %RESULT_COLLECT_FILE%
    echo        ^]^]^>^</command^> >> %RESULT_COLLECT_FILE%
)
if exist hotfix_tmp.txt (
    del /q hotfix_tmp.txt
)

reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update"  > updatereg_tmp.txt
if ERRORLEVEL 0 (
    call :base64encode updatereg_tmp.txt
    echo        ^<command name="WINDOWS_UPDATE_REG"^>^<!^[CDATA^[ >> %RESULT_COLLECT_FILE%
    for /f "delims=" %%a in (base64.txt) do echo %%a >> %RESULT_COLLECT_FILE%
    echo        ^]^]^>^</command^> >> %RESULT_COLLECT_FILE%
)
if exist updatereg_tmp.txt (
    del /q updatereg_tmp.txt
)

echo    ^</infoElement^> >> %RESULT_COLLECT_FILE%

echo %CODE032% Collect


echo    ^<infoElement code="%CODE035%"^> >> %RESULT_COLLECT_FILE%

reg query "HKLM\SYSTEM\CurrentControlSet\Services\RemoteRegistry" /s /v Start > remote_reg_tmp.txt
if ERRORLEVEL 0 (
    call :base64encode remote_reg_tmp.txt
    echo        ^<command name="REMOTE_REGISTRY_REG"^>^<!^[CDATA^[ >> %RESULT_COLLECT_FILE%
    for /f "delims=" %%a in (base64.txt) do echo %%a >> %RESULT_COLLECT_FILE%
    echo        ^]^]^>^</command^> >> %RESULT_COLLECT_FILE%
)
if exist remote_reg_tmp.txt (
    del /q remote_reg_tmp.txt
)

echo    ^</infoElement^> >> %RESULT_COLLECT_FILE%

echo %CODE035% Collect


echo    ^<infoElement code="%CODE037%"^> >> %RESULT_COLLECT_FILE%

cacls %systemroot%\system32\config\SAM > samperm_tmp.txt
if ERRORLEVEL 0 (
    call :base64encode samperm_tmp.txt
    echo        ^<command name="REMOTE_REGISTRY_REG"^>^<!^[CDATA^[ >> %RESULT_COLLECT_FILE%
    for /f "delims=" %%a in (base64.txt) do echo %%a >> %RESULT_COLLECT_FILE%
    echo        ^]^]^>^</command^> >> %RESULT_COLLECT_FILE%
)
if exist samperm_tmp.txt (
    del /q samperm_tmp.txt
)
echo    ^</infoElement^> >> %RESULT_COLLECT_FILE%

echo %CODE037% Collect


echo    ^<infoElement code="%CODE040%"^> >> %RESULT_COLLECT_FILE%

echo    ^</infoElement^> >> %RESULT_COLLECT_FILE%

secedit /export /cfg secpolicy_tmp.txt > nul
type secpolicy_tmp.txt | more > secpolicy.txt
del /q secpolicy_tmp.txt

if ERRORLEVEL 0 (
    call :fileCheckSum secpolicy.txt, checksumvalue
    if not "%checksumvalue%" == "DUP" (
        echo    ^<fileInfo^> >> %RESULT_FILE_DATA_FILE%
        echo    ^<filePath checksum="%checksumvalue%"^>^<!^[CDATA^[Local Security Policy^]^]^>^</filePath^> >> %RESULT_FILE_DATA_FILE%
        call :base64encode secpolicy.txt
        echo    ^<fileData^>^<!^[CDATA^[ >> %RESULT_FILE_DATA_FILE% 
        for /f "delims=" %%a in (base64.txt) do echo %%a >> %RESULT_FILE_DATA_FILE%
        echo    ^]^]^>^</fileData^> >> %RESULT_FILE_DATA_FILE%
        echo    ^</fileInfo^> >> %RESULT_FILE_DATA_FILE%
    )
)

if exist secpolicy.txt (
    del /q secpolicy.txt
)

echo %CODE040% Collect

echo     ^</fileList^> >> %RESULT_FILE_DATA_FILE%
copy %RESULT_COLLECT_FILE% + %RESULT_FILE_DATA_FILE% %RESULT_COLLECT_FILE% /b
echo ^</root^> >> %RESULT_COLLECT_FILE%

del /q "systeminfo.txt"
del /q "base64.txt"
del /q "filecksum.txt"
del /q "%RESULT_FILE_DATA_FILE%"

exit /b 0
:base64encode
	certutil -encode %~1 base64tmp.txt > nul
	type base64tmp.txt | findstr /v CERTIFICATE > base64.txt
	del /q %~1
	del /q base64tmp.txt
exit /b

:fileCheckSum
    certutil -hashfile %~1 > filecksumtmp.txt
    for /f "tokens=*" %%a in ('"type filecksumtmp.txt | findstr /v "%~1 hash""') do set chksumvalue=%%a
    set chksumvalue=%chksumvalue: =%
    if exist filecksum.txt (
        type filecksum.txt | findstr /bic:%chksumvalue% > nul
        if ERRORLEVEL 0 (
            set %~2=DUP
        ) else (
            echo %chksumvalue% >> filecksum.txt
            set %~2=%chksumvalue%
        )
    ) else (
        echo %chksumvalue% > filecksum.txt
        set %~2=%chksumvalue%
    )
    del /q filecksumtmp.txt
exit /b
