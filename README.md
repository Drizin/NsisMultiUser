# NSIS Multi User Plugin
Installer/Uninstaller that allows installations "per-user" (no admin required) or "per-machine" (asks elevation only when necessary)

This plugin is based on [MultiUser.nsh (by Joost Verburg)](http://nsis.sourceforge.net/Docs/MultiUser/Readme.html) but with some new features and some simplifications:
- Installer allows installations "per-user" (no admin required) or "per-machine" (as original)
- If running user IS part of Administrators group, he is not forced to elevate and install per-machine (only if necessary)
- If running user is NOT part of Administrators group, he is still able to elevate and install per-machine (I expect that power-users will have administrator password, but will not be part of the administrators group)
- UAC Elevation happens only when necessary (when per-machine is selected), not in the start of the installer
- Uninstaller block is mandatory (why shouldn't it be?)
- If there are both per-user and per-machine installations, user can choose which one to remove during uninstall
- Correctly creates and removes shortcuts and registry (per-user and per-machine are totally independent)
- Fills uninstall information in registry like Icon and Estimated Size.
- If running as non-elevated user, the "per-machine" install can be allowed (automatically invoking UAC elevation) or can be disabled (suggesting to run again as elevated user)
- If elevation is invoked for per-machine install, the calling process automatically hides itself, and the elevated inner process automatically skips the choice screen (cause in this case we know that per-machine installation was chosen)

## Structure:
 - `Include` - contains all necessary headers (*.nsh), including [UAC Plugin](http://nsis.sourceforge.net/UAC_plug-in) v0.2.4c (2015-05-26)
 - `Plugins` - contains only the DLLs for the [UAC Plugin](http://nsis.sourceforge.net/UAC_plug-in) v0.2.4c (2015-05-26). 

## Installation

### All Users
1. Copy/Extract `Include` contents to NSIS includes directory (usually `C:\Program Files\Nsis\Include\` or `C:\Program Files (x86)\Nsis\Include\`)
2. Copy/Extract `Plugins` contents to NSIS plugins directory (usually `C:\Program Files\Nsis\Plugins\` or `C:\Program Files (x86)\Nsis\Plugins\`)
3. Add reference to  `NsisMultiUser.nsh` in your main NSI file like this:
		`!include "NsisMultiUser.nsh"`

### Local
1. Copy the whole project into any folder (suggestion is a subfolder called `NsisMultiUser` under your NSIS Script folder)
2. Add reference to the DLLs and to the INCLUDE headers like this: 
    ```nsis
    ; if you don't have UAC plug-in installed, add plugin directories (DLLs) to the search path
    !addplugindir /x86-ansi ".\NsisMultiUser\Plugins\x86-ansi\"
    !addplugindir /x86-unicode ".\NsisMultiUser\Plugins\x86-unicode\"
     
    ; include the path to header file (full or relative paths), or just add the include directory to the search path (like !addplugindir above)
    ;!include ".\NsisMultiUser\Include\NsisMultiUser.nsh" 
    !addincludedir ".\NsisMultiUser\Include\"
    !include "NsisMultiUser.nsh" 
    ```

## Usage

The include for `NsisMultiUser.nsh` should be done *after* defining the following constants:

```nsis
!define APP_NAME "Servantt"
!define UNINSTALL_FILENAME "uninstall.exe"
!define MULTIUSER_INSTALLMODE_INSTDIR "${APP_NAME}"  ; suggested name of directory to install (under $PROGRAMFILES or $LOCALAPPDATA)
!define MULTIUSER_INSTALLMODE_INSTALL_REGISTRY_KEY "${APP_NAME}"  ; registry key for INSTALL info, placed under [HKLM|HKCU]\Software  (can be ${APP_NAME} or some {GUID})
!define MULTIUSER_INSTALLMODE_UNINSTALL_REGISTRY_KEY "${APP_NAME}"  ; registry key for UNINSTALL info, placed under [HKLM|HKCU]\Software\Microsoft\Windows\CurrentVersion\Uninstall  (can be ${APP_NAME} or some {GUID})
!define MULTIUSER_INSTALLMODE_DEFAULT_REGISTRY_VALUENAME "UninstallString"
!define MULTIUSER_INSTALLMODE_INSTDIR_REGISTRY_VALUENAME "InstallLocation"
;!define MULTIUSER_INSTALLMODE_DISPLAYNAME "${APP_NAME} ${VERSION} ${PRODUCT_EDITION}"  ; optional... default is "${APP_NAME} ${VERSION}"
!define MULTIUSER_INSTALLMODE_ALLOW_ELEVATION   ; OPTIONAL - allow requesting for elevation... if false, radiobutton will be disabled and user will have to restart installer with elevated permissions
!define MULTIUSER_INSTALLMODE_DEFAULT_ALLUSERS  ; OPTIONAL (only available if MULTIUSER_INSTALLMODE_ALLOW_ELEVATION) - will mark "all users" (per-machine) as default even if running as non-elevated user.
```

Between your pages (normally you'll want to add it after the PAGE_LICENSE), just add this call to MULTIUSER_PAGE_INSTALLMODE:

```nsis
!insertmacro MUI_PAGE_LICENSE "..\License.rtf"
;...
!insertmacro MULTIUSER_PAGE_INSTALLMODE ; this will show the 2 install options, unless it's an elevated inner process (in that case we know we should install for all users)
;...
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_INSTFILES 
```

In your main section, after writing all files (and uninstaller) just add this call (MULTIUSER_RegistryAddInstallInfo):

```nsis
Section "MyProgram (required)"
  SectionIn RO

  ; Set output path to the installation directory.
  SetOutPath $INSTDIR
  SetOverwrite on

  ; Put files there
  File "..\Release\Obfuscated\${PROGEXE}"
  File "..\Release\Obfuscated\${PROGEXE}.config"
  File "..\Release\ExternalReference.dll"
  ; ...
  File "..\License.rtf"
  WriteUninstaller "${UNINSTALL_FILENAME}"
  !insertmacro MULTIUSER_RegistryAddInstallInfo ; add registry keys
SectionEnd
```

In the end of your uninstall, do the same (MULTIUSER_RegistryRemoveInstallInfo):

```nsis
Section "Uninstall"
  ; Remove files and uninstaller
  Delete $INSTDIR\*.dll
  Delete $INSTDIR\*.exe
  Delete $INSTDIR\*.rtf
  Delete $INSTDIR\*.config
  
  ; Remove shortcuts, if any
  ;SetShellVarContext all ; all users
  Delete "$SMPROGRAMS\Servantt\*.*"
  
  ; Remove directories used
  RMDir "$SMPROGRAMS\Servantt"
  RMDir "$INSTDIR"
  
  !insertmacro MULTIUSER_RegistryRemoveInstallInfo ; Remove registry keys
SectionEnd
```

In the shortcuts section, don’t set var context (plugin will do), and use $SMPROGRAMS:

```nsis
Section "Start Menu Shortcuts"
  ;SetShellVarContext all ; all users
  CreateDirectory "$SMPROGRAMS\${APP_NAME}"
  ;CreateShortCut "$SMPROGRAMS\${APP_NAME}\Uninstall.lnk" "$INSTDIR\${UNINSTALL_FILENAME}" "" "$INSTDIR\${UNINSTALL_FILENAME}" 0  ; shortcut for uninstall is bad cause user can choose this by mistake during search.
  CreateShortCut "$SMPROGRAMS\${APP_NAME}\${PRODUCT_NAME} ${VERSION}.lnk" "$INSTDIR\${PROGEXE}" "" "$INSTDIR\${PROGEXE}" 0
  Delete "$SMPROGRAMS\${APP_NAME}\${APP_NAME} 1.0*" ; old versions
SectionEnd
```
  
Initialize the plugin both for install and for uninstall (MULTIUSER_INIT and MULTIUSER_UNINIT):

```nsis
Function .onInit
  !insertmacro MULTIUSER_INIT
FunctionEnd
  
Function un.onInit
  !insertmacro MULTIUSER_UNINIT
FunctionEnd
```


## Screenshots

User runs the installer, no elevation is required unless/until it's necessary.

If the **ALLOW_ELEVATION** is NOT defined and user is NOT running as admin, only per-user installation is offered:

![Per-user install](/Documentation/screenshot1.png?raw=true)
![Per-user install](/Documentation/screenshot2.png?raw=true)


If the user is running as admin or if  **ALLOW_ELEVATION** is defined, both options are offered:

![Per-user install](/Documentation/screenshot3.png?raw=true)

PS: If running as regular user, default is to suggest a per-user install, unless **DEFAULT_ALLUSERS** is defined 

Reinstallations/Upgrades will always suggest to use the existing installation:

![Per-user install](/Documentation/screenshot4.png?raw=true)

![Per-user install](/Documentation/screenshot5.png?raw=true)


**If there are both per-user and per-machine installations**, uninstaller will ask which one should be removed.

![Per-user install](/Documentation/screenshot6.png?raw=true)

The "add/remove programs" will show individual installations (one is stored in HKLM and other in HKCU):

![Per-user install](/Documentation/screenshot7.png?raw=true)

If you choose to uninstall the per-machine installation (first row) from this "add/remove" screen, command-line argument "/allusers" will make the uninstaller **automatically remove the per-machine installation** (skip the which-installation-screen, even if you also have a per-user installation on the Administrator account)

If you choose uninstall the per-user installation (second row) from this "**add/remove**" screen, command-line argument "/currentuser" will make the uninstaller **automatically remove the per-user installation** (skip the which-installation-screen, even if you also have a per-machine installation)

If you run the uninstaller from the program folder (that is, without passing command-line arguments), this "**which installation to remove**" screen will be shown **if there is both per-user and per-machine installations**.

