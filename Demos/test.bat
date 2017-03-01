:: test by running this file both as user and as admin

@echo OFF
:: set setup="MUI_1_2_Full\Setup_MUI_1_2_Full.exe"
:: set setup="MUI2_Limited\Setup_MUI2_Limited.exe"
:: set setup="NSIS_Full\Setup_NSIS_Full.exe"
   set setup="UMUI_Full\Setup_UMUI_Ex_Full.exe"
:: set setup="UMUI_Full2\Setup_UMUI_Ex_Full2.exe"

cd /D %0\..\%setup%\..

set loop=0
set test=0

:Loop
echo Compile with:
echo MULTIUSER_INSTALLMODE_ALLOW_BOTH_INSTALLATIONS = 1
echo MULTIUSER_INSTALLMODE_ALLOW_ELEVATION = %loop%
echo MULTIUSER_INSTALLMODE_ALLOW_ELEVATION_IF_SILENT = %loop%
echo ...
pause > nul


echo.
set /A test=test+1
echo ***(%test%/16) THERE'S NO INSTALLATION***
echo (uninstall program compeletely)
echo ...
pause > nul

echo.
echo no parameters
START "" /WAIT %setup%
echo Result: %errorlevel%

echo.
echo /allusers
START "" /WAIT %setup% /allusers
echo Result: %errorlevel%

echo.
echo /currentuser
START "" /WAIT %setup% /currentuser
echo Result: %errorlevel%

echo.
echo /allusers /S
START "" /WAIT %setup% /allusers /S
echo Result: %errorlevel%
pause

echo.
echo /currentuser /S
START "" /WAIT %setup% /currentuser /S
echo Result: %errorlevel%
pause

echo.
echo /allusers /uninstall 
START "" /WAIT %setup% /allusers /uninstall
echo Result: %errorlevel%

echo.
echo /allusers /uninstall /S
START "" /WAIT %setup% /allusers /uninstall /S
echo Result: %errorlevel%


echo.
set /A test=test+1
echo ***(%test%/16) THERE'S PER-USER INSTALLATION ONLY***
echo ...
pause > nul

echo.
echo no parameters
START "" /WAIT %setup%
echo Result: %errorlevel%

echo.
echo /currentuser
START "" /WAIT %setup% /currentuser
echo Result: %errorlevel%

echo.
echo /allusers
START "" /WAIT %setup% /allusers
echo Result: %errorlevel%

echo.
echo /currentuser /S
START "" /WAIT %setup% /currentuser /S
echo Result: %errorlevel%

echo.
echo /allusers /S
START "" /WAIT %setup% /allusers /S
echo Result: %errorlevel%
pause

echo.
echo /currentuser /uninstall 
START "" /WAIT %setup% /currentuser /uninstall
echo Result: %errorlevel%

echo.
echo /currentuser /uninstall /S
START "" /WAIT %setup% /currentuser /uninstall /S
echo Result: %errorlevel%


echo.
set /A test=test+1
echo ***(%test%/16) THERE'S PER-MACHINE INSTALLATION ONLY***
echo (uninstall per-user version)
echo ...
pause > nul

echo.
echo no parameters
START "" /WAIT %setup%
echo Result: %errorlevel%

echo.
echo /allusers
START "" /WAIT %setup% /allusers
echo Result: %errorlevel%

echo.
echo /currentuser
START "" /WAIT %setup% /currentuser
echo Result: %errorlevel%

echo.
echo /allusers /S
START "" /WAIT %setup% /allusers /S
echo Result: %errorlevel%
pause

echo.
echo /currentuser /S
START "" /WAIT %setup% /currentuser /S
echo Result: %errorlevel%


echo.
set /A test=test+1
echo ***(%test%/16) THERE ARE BOTH PER-USER AND PER-MACHINE INSTALLATIONS***
echo ...
pause > nul

echo.
echo no parameters
START "" /WAIT %setup%
echo Result: %errorlevel%

echo.
echo /allusers
START "" /WAIT %setup% /allusers
echo Result: %errorlevel%

echo.
echo /currentuser
START "" /WAIT %setup% /currentuser
echo Result: %errorlevel%

echo.
echo /allusers /S
START "" /WAIT %setup% /allusers /S
echo Result: %errorlevel%
pause

echo.
echo /currentuser /S
START "" /WAIT %setup% /currentuser /S
echo Result: %errorlevel%


echo.
echo.
echo Compile with:
echo MULTIUSER_INSTALLMODE_ALLOW_BOTH_INSTALLATIONS = 0
echo MULTIUSER_INSTALLMODE_ALLOW_ELEVATION = %loop%
echo MULTIUSER_INSTALLMODE_ALLOW_ELEVATION_IF_SILENT = %loop%
echo ...
pause > nul


echo.
set /A test=test+1
echo ***(%test%/16) THERE ARE BOTH PER-USER AND PER-MACHINE INSTALLATIONS***
echo ...
pause > nul

echo.
echo no parameters
START "" /WAIT %setup%
echo Result: %errorlevel%

echo.
echo /allusers
START "" /WAIT %setup% /allusers
echo Result: %errorlevel%

echo.
echo /currentuser
START "" /WAIT %setup% /currentuser
echo Result: %errorlevel%

echo.
echo /allusers /S
START "" /WAIT %setup% /allusers /S
echo Result: %errorlevel%
pause

echo.
echo /currentuser /S
START "" /WAIT %setup% /currentuser /S
echo Result: %errorlevel%

echo.
echo /currentuser /uninstall 
START "" /WAIT %setup% /currentuser /uninstall 
echo Result: %errorlevel%

echo.
echo /currentuser /uninstall /S
START "" /WAIT %setup% /currentuser /uninstall /S
echo Result: %errorlevel%


echo.
set /A test=test+1
echo ***(%test%/16) THERE'S PER-MACHINE INSTALLATION ONLY***
echo (uninstall per-user version)
echo ...
pause > nul

echo.
echo no parameters
START "" /WAIT %setup%
echo Result: %errorlevel%

echo.
echo /allusers
START "" /WAIT %setup% /allusers
echo Result: %errorlevel%

echo.
echo /currentuser
START "" /WAIT %setup% /currentuser
echo Result: %errorlevel%

echo.
echo /allusers /S
START "" /WAIT %setup% /allusers /S
echo Result: %errorlevel%
pause

echo.
echo /currentuser /S
START "" /WAIT %setup% /currentuser /S
echo Result: %errorlevel%

echo.
echo /allusers /uninstall 
START "" /WAIT %setup% /allusers /uninstall 
echo Result: %errorlevel%

echo.
echo /allusers /uninstall /S
START "" /WAIT %setup% /allusers /uninstall /S
echo Result: %errorlevel%


echo.
set /A test=test+1
echo ***(%test%/16) THERE'S PER-USER INSTALLATION ONLY***
echo ...
pause > nul

echo.
echo no parameters
START "" /WAIT %setup%
echo Result: %errorlevel%

echo.
echo /allusers
START "" /WAIT %setup% /allusers
echo Result: %errorlevel%

echo.
echo /currentuser
START "" /WAIT %setup% /currentuser
echo Result: %errorlevel%

echo.
echo /allusers /S
START "" /WAIT %setup% /allusers /S
echo Result: %errorlevel%
pause

echo.
echo /currentuser /S
START "" /WAIT %setup% /currentuser /S
echo Result: %errorlevel%

echo.
echo /currentuser /uninstall 
START "" /WAIT %setup% /currentuser /uninstall 
echo Result: %errorlevel%

echo.
echo /currentuser /uninstall /S
START "" /WAIT %setup% /currentuser /uninstall /S
echo Result: %errorlevel%


echo.
set /A test=test+1
echo ***(%test%/16) THERE'S NO INSTALLATION***
echo (uninstall per-user version)
echo ...
pause > nul

echo.
echo no parameters
START "" /WAIT %setup%
echo Result: %errorlevel%

echo.
echo /allusers
START "" /WAIT %setup% /allusers
echo Result: %errorlevel%

echo.
echo /currentuser
START "" /WAIT %setup% /currentuser
echo Result: %errorlevel%

echo.
echo /allusers /S
START "" /WAIT %setup% /allusers /S
echo Result: %errorlevel%
pause

echo.
echo /currentuser /S
START "" /WAIT %setup% /currentuser /S
echo Result: %errorlevel%

echo.
echo /allusers /uninstall 
START "" /WAIT %setup% /allusers /uninstall 
echo Result: %errorlevel%

echo.
echo /allusers /uninstall /S
START "" /WAIT %setup% /allusers /uninstall /S
echo Result: %errorlevel%

echo.
echo /currentuser /uninstall 
START "" /WAIT %setup% /currentuser /uninstall 
echo Result: %errorlevel%

echo.
echo /currentuser /uninstall /S
START "" /WAIT %setup% /currentuser /uninstall /S
echo Result: %errorlevel%





set /A loop=loop+1
if %loop% LSS 2 goto Loop


echo Press a key to exit...
pause > nul