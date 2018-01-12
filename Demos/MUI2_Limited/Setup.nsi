!addplugindir /x86-ansi ".\..\..\Plugins\x86-ansi"
!addplugindir /x86-unicode ".\..\..\Plugins\x86-unicode"
!addincludedir ".\..\..\Include"

!include MUI2.nsh
!include UAC.nsh
!include NsisMultiUser.nsh
!include LogicLib.nsh
!include ".\..\Common\Utils.nsh"

!define PRODUCT_NAME "NsisMultiUser MUI2 Limited Demo" ; name of the application as displayed to the user
!define VERSION "1.0" ; main version of the application (may be 0.1, alpha, beta, etc.)
!define PROGEXE "calc.exe" ; main application filename
!define COMPANY_NAME "Alex Mitev" ; company, used for registry tree hierarchy
!define PLATFORM "Win64"
!define MIN_WIN_VER "XP"
!define SINGLE_INSTANCE_ID "${COMPANY_NAME} ${PRODUCT_NAME} Unique ID" ; do not change this between program versions!
!define LICENSE_FILE "License.txt" ; license file, optional

; NsisMultiUser optional defines
!define MULTIUSER_INSTALLMODE_ALLOW_BOTH_INSTALLATIONS 1 ; value 0 is not supported - previous installation is not fully removed
!define MULTIUSER_INSTALLMODE_ALLOW_ELEVATION 1
!define MULTIUSER_INSTALLMODE_ALLOW_ELEVATION_IF_SILENT 0
!define MULTIUSER_INSTALLMODE_DEFAULT_ALLUSERS 1
!if ${PLATFORM} == "Win64"
	!define MULTIUSER_INSTALLMODE_64_BIT 1
!endif
!define MULTIUSER_INSTALLMODE_DISPLAYNAME "${PRODUCT_NAME} ${VERSION} ${PLATFORM}"  

Var StartMenuFolder

; Installer Attributes
Name "${PRODUCT_NAME} ${VERSION} ${PLATFORM}"
OutFile "Setup_MUI2_Limited.exe"
BrandingText "©2017 ${COMPANY_NAME}"

AllowSkipFiles off
SetOverwrite on ; (default setting) set to on except for where it is manually switched off
ShowInstDetails show 
SetCompressor /SOLID lzma

; Pages
!define MUI_ABORTWARNING ; Show a confirmation when cancelling the installation

!define MUI_PAGE_CUSTOMFUNCTION_PRE PageWelcomeLicensePre
!insertmacro MUI_PAGE_WELCOME

!ifdef LICENSE_FILE
	!define MUI_PAGE_CUSTOMFUNCTION_PRE PageWelcomeLicensePre
	!insertmacro MUI_PAGE_LICENSE ".\..\..\${LICENSE_FILE}"
!endif

!define MUI_PAGE_CUSTOMFUNCTION_PRE PageWelcomeLicensePre
!insertmacro MUI_PAGE_LICENSE "readme.txt"

!define MULTIUSER_INSTALLMODE_CHANGE_MODE_FUNCTION PageInstallModeChangeMode
!insertmacro MULTIUSER_PAGE_INSTALLMODE 

!define MUI_COMPONENTSPAGE_SMALLDESC
!insertmacro MUI_PAGE_COMPONENTS

!define MUI_PAGE_CUSTOMFUNCTION_PRE PageDirectoryPre
!define MUI_PAGE_CUSTOMFUNCTION_SHOW PageDirectoryShow
!insertmacro MUI_PAGE_DIRECTORY

!define MUI_STARTMENUPAGE_NODISABLE ; Do not display the checkbox to disable the creation of Start Menu shortcuts
!define MUI_STARTMENUPAGE_DEFAULTFOLDER "${PRODUCT_NAME}"
!define MUI_STARTMENUPAGE_REGISTRY_ROOT "SHCTX" ; writing to $StartMenuFolder happens in MUI_STARTMENU_WRITE_END, so it's safe to use "SHCTX" here
!define MUI_STARTMENUPAGE_REGISTRY_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}"
!define MUI_STARTMENUPAGE_REGISTRY_VALUENAME "StartMenuFolder"
!define MUI_PAGE_CUSTOMFUNCTION_PRE PageStartMenuPre
!insertmacro MUI_PAGE_STARTMENU "" "$StartMenuFolder"

!insertmacro MUI_PAGE_INSTFILES

!define MUI_FINISHPAGE_RUN 
!define MUI_FINISHPAGE_RUN_FUNCTION PageFinishRun
!insertmacro MUI_PAGE_FINISH

!include Uninstall.nsh

!insertmacro MUI_LANGUAGE "English" ; Set languages (first is default language) - must be inserted after all pages 

InstType "Typical" 
InstType "Minimal" 
InstType "Full" 

Section "Core Files (required)" SectionCoreFiles
	SectionIn 1 2 3 RO
				
	${if} $HasCurrentModeInstallation == 1 ; if there's an installed version, remove all optinal components (except "Core Files")
		; Clean up "Documentation"
		Delete "$INSTDIR\readme.txt"
	
		; Clean up "Program Group" - we check that we created Start menu folder, if $StartMenuFolder is empty, the whole $SMPROGRAMS directory will be removed!
		${if} "$StartMenuFolder" != ""
			RMDir /r "$SMPROGRAMS\$StartMenuFolder"
		${endif}	
	
		; Clean up "Dektop Icon"
		Delete "$DESKTOP\${PRODUCT_NAME}.lnk"
		
		; Clean up "Start Menu Icon"
		Delete "$STARTMENU\${PRODUCT_NAME}.lnk"
			
		; Clean up "Quick Launch Icon"
		Delete "$QUICKLAUNCH\${PRODUCT_NAME}.lnk"		
	${endif}

	SetOutPath $INSTDIR
	; Write uninstaller and registry uninstall info as the first step,
	; so that the user has the option to run the uninstaller if sth. goes wrong 
	WriteUninstaller "${UNINSTALL_FILENAME}"			
	!insertmacro MULTIUSER_RegistryAddInstallInfo ; add registry keys		

	File "C:\Windows\System32\${PROGEXE}" 
	!ifdef LICENSE_FILE
		File ".\..\..\${LICENSE_FILE}"	
	!endif
SectionEnd

Section "Documentation" SectionDocumentation	
	SectionIn 1 3
	
	SetOutPath $INSTDIR	
	File "readme.txt" 
	
SectionEnd

SectionGroup /e "Integration" SectionGroupIntegration

Section "Program Group" SectionProgramGroup
	SectionIn 1	3
	
  !insertmacro MUI_STARTMENU_WRITE_BEGIN ""

	  CreateDirectory "$SMPROGRAMS\$StartMenuFolder"
	  CreateShortCut "$SMPROGRAMS\$StartMenuFolder\${PRODUCT_NAME}.lnk" "$INSTDIR\${PROGEXE}"
			
		!ifdef LICENSE_FILE
			CreateShortCut "$SMPROGRAMS\$StartMenuFolder\License Agreement.lnk" "$INSTDIR\${LICENSE_FILE}"	
		!endif
		${if} $MultiUser.InstallMode == "AllUsers" 
			CreateShortCut "$SMPROGRAMS\$StartMenuFolder\Uninstall.lnk" "$INSTDIR\${UNINSTALL_FILENAME}" "/allusers"
		${else}
			CreateShortCut "$SMPROGRAMS\$StartMenuFolder\Uninstall (current user).lnk" "$INSTDIR\${UNINSTALL_FILENAME}" "/currentuser"
		${endif}
	
  !insertmacro MUI_STARTMENU_WRITE_END	
SectionEnd

Section "Dektop Icon" SectionDesktopIcon
	SectionIn 1 3

	CreateShortCut "$DESKTOP\${PRODUCT_NAME}.lnk" "$INSTDIR\${PROGEXE}"	
SectionEnd

Section /o "Start Menu Icon" SectionStartMenuIcon
	SectionIn 3

	CreateShortCut "$STARTMENU\${PRODUCT_NAME}.lnk" "$INSTDIR\${PROGEXE}"
SectionEnd

Section /o "Quick Launch" SectionQuickLaunchIcon
	SectionIn 3

  ; The QuickLaunch is always only for the current user
	CreateShortCut "$QUICKLAUNCH\${PRODUCT_NAME}.lnk" "$INSTDIR\${PROGEXE}"
SectionEnd
SectionGroupEnd

Section "-Write Install Size" ; hidden section, write install size as the final step
	!insertmacro MULTIUSER_RegistryAddInstallSizeInfo
SectionEnd

; Modern install component descriptions
!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
	!insertmacro MUI_DESCRIPTION_TEXT ${SectionCoreFiles} "Core files requred to run ${PRODUCT_NAME}."
	!insertmacro MUI_DESCRIPTION_TEXT ${SectionDocumentation} "Help files for ${PRODUCT_NAME}."
	
  !insertmacro MUI_DESCRIPTION_TEXT ${SectionGroupIntegration} "Select how to integrate the program in Windows."
	!insertmacro MUI_DESCRIPTION_TEXT ${SectionProgramGroup} "Create a ${PRODUCT_NAME} program group under Start Menu > Programs."
	!insertmacro MUI_DESCRIPTION_TEXT ${SectionDesktopIcon} "Create ${PRODUCT_NAME} icon on the Desktop."
	!insertmacro MUI_DESCRIPTION_TEXT ${SectionStartMenuIcon} "Create ${PRODUCT_NAME} icon in the Start Menu."
	!insertmacro MUI_DESCRIPTION_TEXT ${SectionQuickLaunchIcon} "Create ${PRODUCT_NAME} icon in Quick Launch."
!insertmacro MUI_FUNCTION_DESCRIPTION_END

; Callbacks 
Function .onInit
	!insertmacro CheckPlatform ${PLATFORM}
	!insertmacro CheckMinWinVer ${MIN_WIN_VER}
	${ifnot} ${UAC_IsInnerInstance}
		!insertmacro CheckSingleInstance "${SINGLE_INSTANCE_ID}"
	${endif}	

	!insertmacro MULTIUSER_INIT	  
FunctionEnd

Function PageWelcomeLicensePre		
	${if} $InstallShowPagesBeforeComponents == 0
		Abort ; don't display the Welcome and License pages for the inner instance 
	${endif}	
FunctionEnd

Function PageInstallModeChangeMode
	!insertmacro MUI_STARTMENU_GETFOLDER "" $StartMenuFolder
FunctionEnd

Function PageDirectoryPre	
	GetDlgItem $0 $HWNDPARENT 1		
	${if} ${SectionIsSelected} ${SectionProgramGroup}		
		SendMessage $0 ${WM_SETTEXT} 0 "STR:$(^NextBtn)" ; this is not the last page before installing
	${else}
		SendMessage $0 ${WM_SETTEXT} 0 "STR:$(^InstallBtn)" ; this is the last page before installing
	${endif}		
FunctionEnd

Function PageDirectoryShow
	${if} $CmdLineDir != ""
		${orif} $HasCurrentModeInstallation == 1
		FindWindow $R1 "#32770" "" $HWNDPARENT
		
		GetDlgItem $0 $R1 1019 ; Directory edit
		SendMessage $0 ${EM_SETREADONLY} 1 0 ; read-only is better than disabled, as user can copy contents
		
		GetDlgItem $0 $R1 1001 ; Browse button
		EnableWindow $0 0	
	${endif}			
FunctionEnd

Function PageStartMenuPre
	${ifnot} ${SectionIsSelected} ${SectionProgramGroup}
		Abort ; don't display this dialog if SectionProgramGroup is not selected
	${endif}	
FunctionEnd

Function PageFinishRun
	; the installer might exit too soon before the application starts and it loses the right to be the foreground window and starts in the background
	; however, if there's no active window when the application starts, it will become the active window, so we hide the installer
	HideWindow
	; the installer will show itself again quickly before closing (w/o Taskbar button), we move it offscreen
	!define SWP_NOSIZE 0x0001
	!define SWP_NOZORDER 0x0004
	System::Call "User32::SetWindowPos(i, i, i, i, i, i, i) b ($HWNDPARENT, 0, -1000, -1000, 0, 0, ${SWP_NOZORDER}|${SWP_NOSIZE})"

	!insertmacro UAC_AsUser_ExecShell "open" "$INSTDIR\${PROGEXE}" "" "$INSTDIR" ""
FunctionEnd

Function .onInstFailed
	MessageBox MB_ICONSTOP "${PRODUCT_NAME} ${VERSION} could not be fully installed.$\r$\nPlease, restart Windows and run the setup program again." /SD IDOK
FunctionEnd

