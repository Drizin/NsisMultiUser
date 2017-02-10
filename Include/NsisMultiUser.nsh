/*
SimpleMultiUser.nsh - Installer/Uninstaller that allows installations "per-user" (no admin required) or "per-machine" (asks elevation *only when necessary*)
By Ricardo Drizin (contact at http://drizin.com.br)
This plugin is based on [MultiUser.nsh (by Joost Verburg)](http://nsis.sourceforge.net/Docs/MultiUser/Readme.html) but with some new features and some simplifications:
- Installer allows installations "per-user" (no admin required) or "per-machine" (as original)
- If running user IS part of Administrators group, he is not forced to elevate (only if necessary - for per-machine install)
- If running user is NOT part of Administrators group, he is still able to elevate and install per-machine (I expect that power-users will have administrator password, but will not be part of the administrators group)
- UAC Elevation happens only when necessary (when per-machine is selected), not in the start of the installer
- Uninstaller block is mandatory (why shouldn't it be?)
- If there are both per-user and per-machine installations, user can choose which one to remove during uninstall
- Correctly creates and removes shortcuts and registry (per-user and per-machine are totally independent)
- Fills uninstall information in registry like Icon and Estimated Size.
- If running as non-elevated user, the "per-machine" install can be allowed (automatically invoking UAC elevation) or can be disabled (suggesting to run again as elevated user)
- If elevation is invoked for per-machine install, the calling process automatically hides itself, and the elevated inner process automatically skips the choice screen (cause in this case we know that per-machine installation was chosen)
- If uninstalling from the "add/remove programs", automatically detects if user is trying to remove per-machine or per-user install
*/

!verbose push
!verbose 3

;Standard NSIS header files
!include MUI2.nsh
!include nsDialogs.nsh
!include LogicLib.nsh
!include WinVer.nsh
!include FileFunc.nsh
!include UAC.nsh

RequestExecutionLevel user ; will ask elevation only if necessary

; exit and error codes
!define MULTIUSER_ERROR_INVALID_PARAMETERS 666660 ; invalid command-line parameters
!define MULTIUSER_ERROR_ELEVATION_NOT_ALLOWED 666661 ; elevation is restricted by MULTIUSER_INSTALLMODE_ALLOW_ELEVATION and MULTIUSER_INSTALLMODE_ALLOW_ELEVATION_IF_SILENT 
!define MULTIUSER_ERROR_NOT_INSTALLED 666662 ; returned from uninstaller when no version is installed
!define MULTIUSER_ERROR_ELEVATION_FAILED 666666 ; returned by the outer instance when the inner instance cannot start (user aborted elevation dialog, Logon service not running, UAC is not supported by the OS, user without admin priv. is used in the runas dialog), or started, but was not admin
!define MULTIUSER_INNER_INSTANCE_BACK 666667 ; returned by the inner instance when the user presses the Back button on the first visible page (display outer instance)

;Macros for compile-time defines
!ifmacrondef MUI_DEFAULT
	!macro MUI_DEFAULT SYMBOL CONTENT	
		;Define symbol if not yet defined
		;For setting default values	
		!ifndef "${SYMBOL}"
			!define "${SYMBOL}" "${CONTENT}"
		!endif	
	!macroend
!endif	

!macro MULTIUSER_INIT_VARS
	; required defines
	!ifndef PRODUCT_NAME | VERSION | PROGEXE | COMPANY_NAME
		!error "Should define all variables: PRODUCT_NAME, VERSION, PROGEXE, COMPANY_NAME"
	!endif
	
	; optional defines
	!insertmacro MUI_DEFAULT MULTIUSER_INSTALLMODE_ALLOW_ELEVATION 1 ; 0 (false) or 1 (true), allow UAC screens in the (un)installer - if set to 0 and user is not admin, per-machine radiobutton will be disabled, or if elevation is required, (un)installer will exit with an error code (and message if not silent)
	!if "${MULTIUSER_INSTALLMODE_ALLOW_ELEVATION}" == "" ; old code - just defined with no value, change to this code now: !define MULTIUSER_INSTALLMODE_ALLOW_ELEVATION 0
		!define /redef MULTIUSER_INSTALLMODE_ALLOW_ELEVATION 1
	!endif	
	!insertmacro MUI_DEFAULT MULTIUSER_INSTALLMODE_ALLOW_ELEVATION_IF_SILENT 0 ; 0 (false) or 1 (true), (only available if MULTIUSER_INSTALLMODE_ALLOW_ELEVATION = 1) allow UAC screens in the (un)installer in silent mode; if set to 0 and user is not admin and elevation is required, (un)installer will exit with an error code	
	!if "${MULTIUSER_INSTALLMODE_ALLOW_ELEVATION}" == 0
		!if "${MULTIUSER_INSTALLMODE_ALLOW_ELEVATION_IF_SILENT}" == 1
			!error "MULTIUSER_INSTALLMODE_ALLOW_ELEVATION_IF_SILENT can be set only when MULTIUSER_INSTALLMODE_ALLOW_ELEVATION is set!"
		!endif
	!endif
	!insertmacro MUI_DEFAULT MULTIUSER_INSTALLMODE_ALLOW_BOTH_INSTALLATIONS 1 ; 0 (false) or 1 (true) - whether user can install BOTH per-user and per-machine; this only affects the texts (and shield) on the page, and the required elevation, the actual uninstall of previous version has to be implemented by script	
	!insertmacro MUI_DEFAULT MULTIUSER_INSTALLMODE_DEFAULT_ALLUSERS 0 ; 0 (false) or 1 (true), (only available if MULTIUSER_INSTALLMODE_ALLOW_ELEVATION = 1 or running elevated and there are 0 or 2 installations on the system) when running as user and is set to 1, per-machine installation is pre-selected, otherwise per-user installation
	!if "${MULTIUSER_INSTALLMODE_DEFAULT_ALLUSERS}" == "" ; old code - just defined with no value, change to this code now: !define MULTIUSER_INSTALLMODE_DEFAULT_ALLUSERS 0
		!define /redef MULTIUSER_INSTALLMODE_DEFAULT_ALLUSERS 1
	!endif	
	!insertmacro MUI_DEFAULT MULTIUSER_INSTALLMODE_DEFAULT_CURRENTUSER 0 ; 0 (false) or 1 (true), (only available if there are 0 or 2 installations on the system) when running as admin and is set to 1, per-user installation is pre-selected, otherwise per-machine installation
	!if "${MULTIUSER_INSTALLMODE_DEFAULT_CURRENTUSER}" == "" ; old code - just defined with no value, change to this code now: !define MULTIUSER_INSTALLMODE_DEFAULT_CURRENTUSER 0
		!define /redef MULTIUSER_INSTALLMODE_DEFAULT_CURRENTUSER 1
	!endif		
	!insertmacro MUI_DEFAULT MULTIUSER_INSTALLMODE_PROGRAMFILES $PROGRAMFILES ; set to "$PROGRAMFILES64" for 64-bit installers	
	!insertmacro MUI_DEFAULT MULTIUSER_INSTALLMODE_INSTDIR "${PRODUCT_NAME}" ; suggested name of directory to install (under $MULTIUSER_INSTALLMODE_PROGRAMFILES or $LOCALAPPDATA)
	!insertmacro MUI_DEFAULT MULTIUSER_INSTALLMODE_UNINSTALL_REGISTRY_KEY "${PRODUCT_NAME}" ; registry key for UNINSTALL info, placed under [HKLM|HKCU]\Software\Microsoft\Windows\CurrentVersion\Uninstall  (can be ${PRODUCT_NAME} or some {GUID})	
	!insertmacro MUI_DEFAULT MULTIUSER_INSTALLMODE_INSTALL_REGISTRY_KEY "Microsoft\Windows\CurrentVersion\Uninstall\${MULTIUSER_INSTALLMODE_UNINSTALL_REGISTRY_KEY}" ; registry key where InstallLocation is stored, placed under [HKLM|HKCU]\Software (can be ${PRODUCT_NAME} or some {GUID})	
	!define MULTIUSER_INSTALLMODE_UNINSTALL_REGISTRY_KEY2 "Software\Microsoft\Windows\CurrentVersion\Uninstall\${MULTIUSER_INSTALLMODE_UNINSTALL_REGISTRY_KEY}" ; full path to registry key storing uninstall information displayed in Windows installed programs list
	!define MULTIUSER_INSTALLMODE_INSTALL_REGISTRY_KEY2 "Software\${MULTIUSER_INSTALLMODE_INSTALL_REGISTRY_KEY}" ; full path to registry key where InstallLocation is stored 	
	!insertmacro MUI_DEFAULT UNINSTALL_FILENAME "uninstall.exe" ; name of uninstaller	
	!insertmacro MUI_DEFAULT MULTIUSER_INSTALLMODE_DEFAULT_REGISTRY_VALUENAME "UninstallString" ; do not change this value - doing so will make the program disappear from the Windows installed programs list	
	!insertmacro MUI_DEFAULT MULTIUSER_INSTALLMODE_DISPLAYNAME "${PRODUCT_NAME} ${VERSION}" ; display name in Windows uninstall list of programs	
	!insertmacro MUI_DEFAULT MULTIUSER_INSTALLMODE_INSTDIR_REGISTRY_VALUENAME "InstallLocation" ; name of the registry value containing install directory
	
	!ifdef MULTIUSER_INSTALLMODE_FUNCTION
		!define MULTIUSER_INSTALLMODE_CHANGE_MODE_FUNCTION ${MULTIUSER_INSTALLMODE_FUNCTION} ; old code - changed function name
	!endif			
	
	; Variables
	Var MultiUser.Privileges ; Current user level: "Admin", "Power" (up to Windows XP), or else regular user.
	Var MultiUser.InstallMode ; Current Install Mode ("AllUsers" or "CurrentUser")
	Var IsAdmin ; 0 (false) or 1 (true)
	Var HasPerMachineInstallation ; 0 (false) or 1 (true)
	Var HasPerUserInstallation ; 0 (false) or 1 (true)
	Var PerMachineInstallationFolder 
	Var PerUserInstallationFolder
	Var PerMachineInstallationVersion ; contains version number of empty string ""
	Var PerUserInstallationVersion ; contains version number of empty string ""
	Var HasTwoAvailableOptions ; 0 (false) or 1 (true): 0 means only per-user radio button is enabled on page, 1 means both; will be 0 only when MULTIUSER_INSTALLMODE_ALLOW_ELEVATION = 0 and user is not admin
	Var InstallHidePagesBeforeComponents ; 0 (false) or 1 (true), use it to hide all pages before Components inside the installer when running as inner instance
	Var UninstallHideBackButton ; 0 (false) or 1 (true), use it to hide the Back button on the first visible page of the uninstaller
	Var DisplayDialog ; (internal)
	Var PreFunctionCalled ; (internal)
	Var CmdLineInstallMode ; contains command-line install mode set via /allusers and /currentusers parameters
	Var CmdLineDir ; contains command-line directory set via /D parameter
	
	; interface variables
	Var MultiUser.InstallModePage
	Var MultiUser.InstallModePage.Text
	Var MultiUser.InstallModePage.AllUsers
	Var MultiUser.InstallModePage.CurrentUser	
	Var MultiUser.RadioButtonLabel1
	;Var MultiUser.RadioButtonLabel2
	;Var MultiUser.RadioButtonLabel3		
!macroend	

!macro MULTIUSER_UNINIT_VARS
	!ifdef MULTIUSER_INSTALLMODE_UNFUNCTION
		!define MULTIUSER_INSTALLMODE_CHANGE_MODE_UNFUNCTION ${MULTIUSER_INSTALLMODE_UNFUNCTION} ; old code - changed function name
	!endif			
!macroend	

/****** Modern UI 2 page ******/
!macro MULTIUSER_PAGE UNINSTALLER_PREFIX UNINSTALLER_FUNCPREFIX
	!ifdef MULTIUSER_${UNINSTALLER_PREFIX}PAGE_INSTALLMODE
		!error "You cannot insert MULTIUSER_${UNINSTALLER_PREFIX}PAGE_INSTALLMODE more than once!"
	!endif
	!define MULTIUSER_${UNINSTALLER_PREFIX}PAGE_INSTALLMODE
	
	!insertmacro MUI_${UNINSTALLER_PREFIX}PAGE_INIT
	
	!insertmacro MULTIUSER_${UNINSTALLER_PREFIX}INIT_VARS	
	
	!insertmacro MULTIUSER_FUNCTION_INSTALLMODEPAGE "${UNINSTALLER_PREFIX}" "${UNINSTALLER_FUNCPREFIX}"

	PageEx ${UNINSTALLER_FUNCPREFIX}custom
		PageCallbacks ${UNINSTALLER_FUNCPREFIX}MultiUser.InstallModePre ${UNINSTALLER_FUNCPREFIX}MultiUser.InstallModeLeave
	PageExEnd	
!macroend

!macro MULTIUSER_PAGE_INSTALLMODE ; create install page - called by user script
	!insertmacro MULTIUSER_PAGE "" ""
!macroend

!macro MULTIUSER_UNPAGE_INSTALLMODE ; create uninstall page - called by user script
	!ifndef MULTIUSER_PAGE_INSTALLMODE
		!error "You have to insert MULTIUSER_PAGE_INSTALLMODE before MULTIUSER_UNPAGE_INSTALLMODE!"
	!endif
	!insertmacro MULTIUSER_PAGE "UN" "un."
!macroend

/****** Installer/uninstaller initialization ******/
!macro MULTIUSER_INIT ; called by user script in .onInit (after MULTIUSER_PAGE_INSTALLMODE)
	!ifdef MULTIUSER_INIT
		!error "MULTIUSER_INIT already inserted!"
	!endif
	!define MULTIUSER_INIT

	!ifndef MULTIUSER_PAGE_INSTALLMODE | MULTIUSER_UNPAGE_INSTALLMODE
		!error "You have to insert both MULTIUSER_PAGE_INSTALLMODE and MULTIUSER_UNPAGE_INSTALLMODE!" 
	!endif

	Call MultiUser.InitChecks
!macroend

!macro MULTIUSER_UNINIT ; called by user script in un.onInit (after MULTIUSER_UNPAGE_INSTALLMODE)
	!ifdef MULTIUSER_UNINIT
		!error "MULTIUSER_UNINIT already inserted!"
	!endif
	!define MULTIUSER_UNINIT	
	
	Call un.MultiUser.InitChecks
!macroend

/****** Functions ******/
!macro MULTIUSER_FUNCTION_INSTALLMODEPAGE UNINSTALLER_PREFIX UNINSTALLER_FUNCPREFIX
	Function ${UNINSTALLER_FUNCPREFIX}MultiUser.InstallMode.AllUsers
		${if} $MultiUser.InstallMode == "AllUsers"
			Return
		${endif}

		StrCpy $MultiUser.InstallMode "AllUsers"
	
		SetShellVarContext all
		
		${if} $CmdLineDir != ""
			StrCpy $INSTDIR $CmdLineDir
		${elseif} $PerMachineInstallationFolder != ""
			StrCpy $INSTDIR $PerMachineInstallationFolder
		${else}			
			!if "${UNINSTALLER_FUNCPREFIX}" == ""
				;Set default installation location for installer
				StrCpy $INSTDIR "${MULTIUSER_INSTALLMODE_PROGRAMFILES}\${MULTIUSER_INSTALLMODE_INSTDIR}"
			!endif
		${endif}	

		!ifdef MULTIUSER_INSTALLMODE_CHANGE_MODE_${UNINSTALLER_PREFIX}FUNCTION
			Call "${MULTIUSER_INSTALLMODE_CHANGE_MODE_${UNINSTALLER_PREFIX}FUNCTION}"
		!endif		
	FunctionEnd

	Function ${UNINSTALLER_FUNCPREFIX}MultiUser.InstallMode.CurrentUser
		${if} $MultiUser.InstallMode == "CurrentUser"
			Return
		${endif}		
		
		StrCpy $MultiUser.InstallMode "CurrentUser"
	
		SetShellVarContext current
		
		${if} $CmdLineDir != ""
			StrCpy $INSTDIR $CmdLineDir
		${elseif} $PerUserInstallationFolder != ""
			StrCpy $INSTDIR $PerUserInstallationFolder
		${else}			
			!if "${UNINSTALLER_FUNCPREFIX}" == ""
				;Set default installation location for installer
				${if} ${AtLeastWin2000}
					StrCpy $INSTDIR "$LOCALAPPDATA\${MULTIUSER_INSTALLMODE_INSTDIR}"
				${else}
					StrCpy $INSTDIR "${MULTIUSER_INSTALLMODE_PROGRAMFILES}\${MULTIUSER_INSTALLMODE_INSTDIR}"
				${endif}
			!endif
		${endif}	
		
		!ifdef MULTIUSER_INSTALLMODE_CHANGE_MODE_${UNINSTALLER_PREFIX}FUNCTION
			Call "${MULTIUSER_INSTALLMODE_CHANGE_MODE_${UNINSTALLER_PREFIX}FUNCTION}"
		!endif
	FunctionEnd

	!if ${MULTIUSER_INSTALLMODE_ALLOW_BOTH_INSTALLATIONS} == 0
		!if "${UNINSTALLER_FUNCPREFIX}" == ""
			Function MultiUser.GetInstallMode 
				; called by the inner instance via the UAC plugin to get InstallMode selected by user in outer instance 
				; (UAC doesn't support passing custom parameters to the inner instance)
				StrCpy $0 $MultiUser.InstallMode
			FunctionEnd	
		!endif
	!endif

	Function ${UNINSTALLER_FUNCPREFIX}MultiUser.CheckElevationRequired
		; check if elevation is always required, return result in $0
		StrCpy $0 0
		${if} $IsAdmin == 0 
			!if "${UNINSTALLER_FUNCPREFIX}" == "" ; installer
				!if ${MULTIUSER_INSTALLMODE_ALLOW_BOTH_INSTALLATIONS} == 0
					${if} $HasPerMachineInstallation == 1
					${andif} $HasPerUserInstallation == 0 
						; has to uninstall the per-machine istalattion, which requires admin rights
						StrCpy $0 1
					${endif}			
				!endif				
			!else ; uninstaller
				${if} $HasPerMachineInstallation == 1
					${andif} $HasPerUserInstallation == 0 
					; there is only per-machine istalattion, which requires admin rights
					StrCpy $0 1
				${endif}			
			!endif
		${endif}
	FunctionEnd

	Function ${UNINSTALLER_FUNCPREFIX}MultiUser.CheckElevationAllowed
		${if} ${silent}
			StrCpy $0 "${MULTIUSER_INSTALLMODE_ALLOW_ELEVATION_IF_SILENT}"
		${else}
			StrCpy $0 "${MULTIUSER_INSTALLMODE_ALLOW_ELEVATION}"
		${endif}
		
		${if} $0 == 0
			MessageBox MB_ICONSTOP "You need to run this program as administrator."	/SD IDOK
			SetErrorLevel ${MULTIUSER_ERROR_ELEVATION_NOT_ALLOWED}
			Quit
		${endif}	
	FunctionEnd	
	
	Function ${UNINSTALLER_FUNCPREFIX}MultiUser.Elevate
		Call ${UNINSTALLER_FUNCPREFIX}MultiUser.CheckElevationAllowed
		
		HideWindow
		!insertmacro UAC_RunElevated
		${if} $0 == 0
			; if inner instance was started ($1 == 1), return code of the elevated fork process is in $2 as well as set via SetErrorLevel
			; NOTE: the error level may have a value MULTIUSER_ERROR_ELEVATION_FAILED (but not MULTIUSER_ERROR_ELEVATION_NOT_ALLOWED)		
			${if} $1 != 1 ; process did not start - return MULTIUSER_ERROR_ELEVATION_FAILED
				SetErrorLevel ${MULTIUSER_ERROR_ELEVATION_FAILED}
			${endif}
		${else} ; process did not start - return MULTIUSER_ERROR_ELEVATION_FAILED or Win32 error code stored in $0
			${if} $0 == 1223 ; user aborted elevation dialog - translate to MULTIUSER_ERROR_ELEVATION_FAILED for easier processing
				${orif} $0 == 1062 ; Logon service not running - translate to MULTIUSER_ERROR_ELEVATION_FAILED for easier processing
				StrCpy $0 ${MULTIUSER_ERROR_ELEVATION_FAILED}
			${endif}	
			SetErrorLevel $0
		${endif}
		Quit 
	FunctionEnd		
		
	Function ${UNINSTALLER_FUNCPREFIX}MultiUser.InitChecks		
		;Installer initialization - check privileges and set default install mode	
		StrCpy $MultiUser.InstallMode ""
		StrCpy $HasTwoAvailableOptions 1
		StrCpy $InstallHidePagesBeforeComponents 0
		StrCpy $UninstallHideBackButton 1		
		StrCpy $DisplayDialog 1
		StrCpy $PreFunctionCalled 0	
		StrCpy $CmdLineInstallMode ""
		StrCpy $CmdLineDir ""
		
		; check in the inner instance has admin rights
		${if} ${UAC_IsInnerInstance}
			${andifnot} ${UAC_IsAdmin}
				SetErrorLevel ${MULTIUSER_ERROR_ELEVATION_FAILED} ;special return value for outer instance so it knows we did not have admin rights
				Quit
		${endif}
						
		UserInfo::GetAccountType
		Pop $MultiUser.Privileges
		${if} $MultiUser.Privileges == "Admin"
			${orif} $MultiUser.Privileges == "Power"
			StrCpy $IsAdmin 1
		${else}
			StrCpy $IsAdmin 0
		${endif}
	
		; Checks registry for previous installation path (both for upgrading, reinstall, or uninstall)
		StrCpy $HasPerMachineInstallation 0
		StrCpy $HasPerUserInstallation 0
		;Set installation mode to setting from a previous installation
		ReadRegStr $PerMachineInstallationFolder HKLM "${MULTIUSER_INSTALLMODE_INSTALL_REGISTRY_KEY2}" "${MULTIUSER_INSTALLMODE_INSTDIR_REGISTRY_VALUENAME}" ; "InstallLocation"
		ReadRegStr $PerMachineInstallationVersion HKLM "${MULTIUSER_INSTALLMODE_UNINSTALL_REGISTRY_KEY2}" "DisplayVersion"
		${if} $PerMachineInstallationFolder != ""
			StrCpy $HasPerMachineInstallation 1
		${endif}
		ReadRegStr $PerUserInstallationFolder HKCU "${MULTIUSER_INSTALLMODE_INSTALL_REGISTRY_KEY2}" "${MULTIUSER_INSTALLMODE_INSTDIR_REGISTRY_VALUENAME}" ; "InstallLocation"
		ReadRegStr $PerUserInstallationVersion HKCU "${MULTIUSER_INSTALLMODE_UNINSTALL_REGISTRY_KEY2}" "DisplayVersion"
		${if} $PerUserInstallationFolder != ""
			StrCpy $HasPerUserInstallation 1
		${endif}
	
		; initialize CmdLineInstallMode and CmdLineDir, needed also if we are the inner instance (UAC passes all parameters from the outer instance)
		${GetParameters} $R0
		${GetOptions} $R0 "/?" $R1
		${ifnot} ${errors}
			MessageBox MB_ICONINFORMATION "Usage:$\r$\n$\r$\n\
				 /allusers$\t- (un)install for all users (case-insensitive)$\r$\n\			
			/currentuser - (un)install for current user only (case-insensitive)$\r$\n\			
								/S$\t- silent mode (case-sensitive)$\r$\n\
								/D$\t- set install directory, must be last paramter, without quotes (case-sensitive)$\r$\n\
								/?$\t- display this message$\r$\n$\r$\n\
			Return codes (DEC):$\r$\n$\r$\n\
					 0$\t- normal execution (no error)$\r$\n\
					 1$\t- installation aborted by user (cancel button)$\r$\n\
			     2$\t- installation aborted by script$\r$\n\
			666660$\t- invalid command-line parameters$\r$\n\
			666661$\t- elevation is not allowed by defines$\r$\n\
			666662$\t- uninstaller detects there's no installed version$\r$\n\
			666666$\t- cannot start elevated instance$\r$\n\
			 other$\t- Win32 error code when trying to start elevated instance"
			SetErrorLevel 0
			Quit
		${endif}			
		${GetOptions} $R0 "/allusers" $R1
		${ifnot} ${errors}
			StrCpy $CmdLineInstallMode "AllUsers"
		${endif}	
		${GetOptions} $R0 "/currentuser" $R1
		${ifnot} ${errors}
			${if} $CmdLineInstallMode == "AllUsers"
				MessageBox MB_ICONSTOP "Provide only on of the /allusers or /currentuser parameters." /SD IDOK
				SetErrorLevel ${MULTIUSER_ERROR_INVALID_PARAMETERS}
				Quit			
			${endif}
			StrCpy $CmdLineInstallMode "CurrentUser"
		${endif}		
		!if "${UNINSTALLER_FUNCPREFIX}" == ""
			${if} "$INSTDIR" != "" ; if $INSTDIR is not empty here in the installer, it's initialized with the value of the /D command-line parameter
				StrCpy $CmdLineDir "$INSTDIR"
			${endif}
		!endif
	
		; initialize $InstallHidePagesBeforeComponents and $UninstallHideBackButton		
		!if "${UNINSTALLER_FUNCPREFIX}" == ""			
			${if} ${UAC_IsInnerInstance}
				${andif} $CmdLineInstallMode == ""
				StrCpy $InstallHidePagesBeforeComponents 1 ; make sure we hide pages only if outer instance showed them, i.e. installer was elevated by dialog in outer instance (not by param in the beginning) (see when MultiUser.Elevate is called)
			${endif}	
		!else				
			${if} $CmdLineInstallMode == ""
				${andif} $HasPerUserInstallation == 1
				${andif} $HasPerMachineInstallation == 1				
					StrCpy $UninstallHideBackButton 0 ; make sure we show Back button only if dialog was displayed, i.e. uninstaller did not elevate in the beginning (see when MultiUser.Elevate is called)
			${endif}			
		!endif			
			
		; check for limitations
		${if} ${silent}
			${andif} $CmdLineInstallMode == ""
			SetErrorLevel ${MULTIUSER_ERROR_INVALID_PARAMETERS} ; one of the /allusers or /currentuser parameters is required in silent mode
			Quit
		${endif}		
		
		!if "${UNINSTALLER_FUNCPREFIX}" != ""
			${if} $HasPerMachineInstallation == 0
				${andif} $HasPerUserInstallation == 0 
				MessageBox MB_ICONSTOP "There's no installed version of ${PRODUCT_NAME}." /SD IDOK	
				SetErrorLevel ${MULTIUSER_ERROR_NOT_INSTALLED}
				Quit
			${endif}
		!endif
	
		${If} ${UAC_IsInnerInstance}
			!if ${MULTIUSER_INSTALLMODE_ALLOW_BOTH_INSTALLATIONS} == 0
				!if "${UNINSTALLER_FUNCPREFIX}" == ""
					!insertmacro UAC_AsUser_Call Function ${UNINSTALLER_FUNCPREFIX}MultiUser.GetInstallMode ${UAC_SYNCREGISTERS}
					${if} $0 == "CurrentUser"
						; the inner instance was elevated because there is installation per-machine, which needs to be removed and requires admin rights, 
						; but the user selected per-user installation in the outer instance, so set context to CurrentUser
						Call ${UNINSTALLER_FUNCPREFIX}MultiUser.InstallMode.CurrentUser
						StrCpy $DisplayDialog 0
						Return
					${endif}	
				!endif
			!endif

			Call ${UNINSTALLER_FUNCPREFIX}MultiUser.InstallMode.AllUsers ; Inner Process (and Admin) - set to AllUsers
			StrCpy $DisplayDialog 0
			Return
		${endif}		
				
		; check if elevation is always required
		Call ${UNINSTALLER_FUNCPREFIX}MultiUser.CheckElevationRequired
		${if} $0 == 1
			Call ${UNINSTALLER_FUNCPREFIX}MultiUser.CheckElevationAllowed
		${endif}	
		
		; process command-line parameters (both silent and non-silent mode, installer and uninstaller)
		${if} $CmdLineInstallMode != ""	
			${if} $CmdLineInstallMode == "AllUsers"
				!if "${UNINSTALLER_FUNCPREFIX}" != ""
					${if} $HasPerMachineInstallation == 0
						MessageBox MB_ICONSTOP "There is no per-machine installation." /SD IDOK
						SetErrorLevel ${MULTIUSER_ERROR_INVALID_PARAMETERS}
						Quit
					${endif}
				!endif	
	
				${if} $IsAdmin == 0 
					Call ${UNINSTALLER_FUNCPREFIX}MultiUser.Elevate
				${endif}
				Call ${UNINSTALLER_FUNCPREFIX}MultiUser.InstallMode.AllUsers 
			${else}
				!if "${UNINSTALLER_FUNCPREFIX}" != ""
					${if} $HasPerUserInstallation == 0
						MessageBox MB_ICONSTOP "There is no per-user installation." /SD IDOK
						SetErrorLevel ${MULTIUSER_ERROR_INVALID_PARAMETERS}
						Quit
					${endif}
				!endif			
				${ifnot} ${IsNT} ; Not running Windows NT, (so it's Windows XP at best), so per-user installation not supported					
					MessageBox MB_ICONSTOP "The OS doesn't support per-user installs." /SD IDOK
					SetErrorLevel ${MULTIUSER_ERROR_INVALID_PARAMETERS}
					Quit
				${endif}	

				Call ${UNINSTALLER_FUNCPREFIX}MultiUser.InstallMode.CurrentUser
			${endif}	
	
			StrCpy $DisplayDialog 0				
			Return
		${endif}		
				
		${ifnot} ${IsNT} ; Not running Windows NT, (so it's Windows XP at best), so per-user installation not supported
			Call ${UNINSTALLER_FUNCPREFIX}MultiUser.InstallMode.AllUsers	
			StrCpy $DisplayDialog 0
			Return
		${endif}	

		; uninstaller - check if there's only one installed version;
		; when invoked from the "add/remove programs", Windows will automatically start uninstaller elevated if uninstall keys are in HKLM
		!if "${UNINSTALLER_FUNCPREFIX}" != ""
			${if} $HasPerUserInstallation == 0 
				${andif} $HasPerMachineInstallation == 1				
				${if} $IsAdmin == 0 
					Call ${UNINSTALLER_FUNCPREFIX}MultiUser.Elevate
				${endif}
				Call ${UNINSTALLER_FUNCPREFIX}MultiUser.InstallMode.AllUsers 
				StrCpy $DisplayDialog 0				
				Return
			${elseif} $HasPerUserInstallation == 1 
				${andif} $HasPerMachineInstallation == 0
				Call ${UNINSTALLER_FUNCPREFIX}MultiUser.InstallMode.CurrentUser
				StrCpy $DisplayDialog 0				
				Return
			${endif} 			
		!endif	
		
		; default initialization (both installer and uninstaller) - we always display the dialog 
		${if} $HasPerUserInstallation == 0 ; if there is only per-machine installation, set it as default
			${andif} $HasPerMachineInstallation == 1
			Call ${UNINSTALLER_FUNCPREFIX}MultiUser.InstallMode.AllUsers		
		${elseif} $HasPerUserInstallation == 1 ; if there is only per-user installation, set it as default
			${andif} $HasPerMachineInstallation == 0
			Call ${UNINSTALLER_FUNCPREFIX}MultiUser.InstallMode.CurrentUser
		${else} ; if there is no installation, or there are 2 installations
			${if} $IsAdmin == 1 ; If running as admin, default to per-machine installation (unless default is forced by MULTIUSER_INSTALLMODE_DEFAULT_CURRENTUSER)
				!if ${MULTIUSER_INSTALLMODE_DEFAULT_CURRENTUSER} == 1
					Call ${UNINSTALLER_FUNCPREFIX}MultiUser.InstallMode.CurrentUser
				!else
					Call ${UNINSTALLER_FUNCPREFIX}MultiUser.InstallMode.AllUsers
				!endif
			${else} ; If not running as admin, default to per-user installation (unless default is forced by MULTIUSER_INSTALLMODE_DEFAULT_ALLUSERS)
				!if ${MULTIUSER_INSTALLMODE_DEFAULT_ALLUSERS} == 1					
					Call ${UNINSTALLER_FUNCPREFIX}MultiUser.InstallMode.AllUsers
				!else
					Call ${UNINSTALLER_FUNCPREFIX}MultiUser.InstallMode.CurrentUser
				!endif
			${endif}
		${endif}
		
		; if elevation is not allowed and user is not admin, select the per-user option and disable the per-machine option
		!if ${MULTIUSER_INSTALLMODE_ALLOW_ELEVATION} == 0
			${if} $IsAdmin == 0
				Call ${UNINSTALLER_FUNCPREFIX}MultiUser.InstallMode.CurrentUser
				StrCpy $HasTwoAvailableOptions 0				
			${endif}	
		!endif
	FunctionEnd
	
	Function ${UNINSTALLER_FUNCPREFIX}MultiUser.InstallModePre
		${if} ${UAC_IsInnerInstance}
			${andif} $PreFunctionCalled == 1
			!if "${UNINSTALLER_FUNCPREFIX}" == ""
				${if} $CmdLineInstallMode == ""	; installer - user pressed Back button on the first visible page in the inner instance and installer was elevated by dialog in outer instance (not by param in the beginning) - display outer instance
					SetErrorLevel ${MULTIUSER_INNER_INSTANCE_BACK}
					Quit							
				${endif}				
			!else ; uninstaller - user pressed Back button on the first visible page in the inner instance - display outer instance
				SetErrorLevel ${MULTIUSER_INNER_INSTANCE_BACK}
				Quit			
			!endif
		${endif}				
		StrCpy $PreFunctionCalled 1
		
		${if} $DisplayDialog == 0			
			Abort
		${endif}		
						
		;!insertmacro MUI_HEADER_TEXT_PAGE $(MULTIUSER_TEXT_INSTALLMODE_TITLE) $(MULTIUSER_TEXT_INSTALLMODE_SUBTITLE) ; "Choose Users" and "Choose for which users you want to install $(^NameDA)."
		
		!if "${UNINSTALLER_FUNCPREFIX}" == ""
			!insertmacro MUI_HEADER_TEXT "Choose Installation Options" "Who should this application be installed for?"
		!else
			!insertmacro MUI_HEADER_TEXT "Choose Uninstallation Options" "Which installation should be removed?"
		!endif
		
		!insertmacro MUI_PAGE_FUNCTION_CUSTOM PRE
		nsDialogs::Create 1018
		Pop $MultiUser.InstallModePage

		; default was MULTIUSER_TEXT_INSTALLMODE_TITLE "Choose Users"
		!if "${UNINSTALLER_FUNCPREFIX}" == ""
			${NSD_CreateLabel} 0u 0u 300u 20u "Please select whether you wish to make this software available to all users or just yourself"
			StrCpy $8 "Anyone who uses this computer (&all users)" ; this was MULTIUSER_INNERTEXT_INSTALLMODE_ALLUSERS "Install for anyone using this computer"
			StrCpy $9 "Only for &me" ; this was MULTIUSER_INNERTEXT_INSTALLMODE_CURRENTUSER "Install just for me"
		!else
			${NSD_CreateLabel} 0u 0u 300u 20u "This software is installed both per-machine (all users) and per-user. $\r$\nWhich installation you wish to remove?"
			StrCpy $8 "Anyone who uses this computer (&all users)" ; this was MULTIUSER_INNERTEXT_INSTALLMODE_ALLUSERS "Install for anyone using this computer"
			StrCpy $9 "Only for &me" ; this was MULTIUSER_INNERTEXT_INSTALLMODE_CURRENTUSER "Install just for me"
		!endif
		Pop $MultiUser.InstallModePage.Text

		; criando os radios (disabled se nao for admin/power) e pegando os hwnds (handles)
		${NSD_CreateRadioButton} 10u 30u 280u 20u "$8"
		Pop $MultiUser.InstallModePage.AllUsers		
		${if} $HasTwoAvailableOptions == 0 ; install per-machine is not available
			SendMessage $MultiUser.InstallModePage.AllUsers ${WM_SETTEXT} 0 "STR:$8 (must run as admin)" ; since radio button is disabled, we add that comment to the disabled control itself
			EnableWindow $MultiUser.InstallModePage.AllUsers 0 # start out disabled
		${endif}
		
		;${NSD_CreateRadioButton} 20u 70u 280u 10u "$9"
		System::Call "advapi32::GetUserName(t.r0,*i${NSIS_MAX_STRLEN})i"
		${NSD_CreateRadioButton} 10u 50u 280u 20u "$9 ($0)"
		Pop $MultiUser.InstallModePage.CurrentUser 

		; bind to radiobutton change
		${NSD_OnClick} $MultiUser.InstallModePage.CurrentUser ${UNINSTALLER_FUNCPREFIX}MultiUser.InstallModeOptionClick
		${NSD_OnClick} $MultiUser.InstallModePage.AllUsers ${UNINSTALLER_FUNCPREFIX}MultiUser.InstallModeOptionClick
		
		!if "${UNINSTALLER_FUNCPREFIX}" == ""
			GetFunctionAddress $0 MultiUser.BackButtonClick 
			nsDialogs::OnBack $0
		!endif	
		
		${NSD_CreateLabel} 0u 110u 280u 50u ""
		Pop $MultiUser.RadioButtonLabel1
		;${NSD_CreateLabel} 0u 120u 280u 20u ""
		;Pop $RadioButtonLabel2
		;${NSD_CreateLabel} 0u 130u 280u 20u ""
		;Pop $RadioButtonLabel3

		${if} $MultiUser.InstallMode == "AllUsers" ; setting selected radio button
			SendMessage $MultiUser.InstallModePage.AllUsers ${BM_SETCHECK} ${BST_CHECKED} 0 ; select radio button
			Call ${UNINSTALLER_FUNCPREFIX}MultiUser.SetShieldAndTexts ; simulating click on the control will change $INSTDIR and reset a possible user selection
		${else}
			SendMessage $MultiUser.InstallModePage.CurrentUser ${BM_SETCHECK} ${BST_CHECKED} 0 ; select radio button
			Call ${UNINSTALLER_FUNCPREFIX}MultiUser.SetShieldAndTexts ; simulating click on the control will change $INSTDIR and reset a possible user selection
		${endif}
		
		!insertmacro MUI_PAGE_FUNCTION_CUSTOM SHOW
		nsDialogs::Show
	FunctionEnd

	Function ${UNINSTALLER_FUNCPREFIX}MultiUser.InstallModeLeave
		!if ${MULTIUSER_INSTALLMODE_ALLOW_ELEVATION} == 1 ; if it's not Power or Admin, but elevation is allowed
			StrCpy $0 0
			
			!if ${MULTIUSER_INSTALLMODE_ALLOW_BOTH_INSTALLATIONS} == 0
				!if "${UNINSTALLER_FUNCPREFIX}" == "" ; installer
					${if} $MultiUser.InstallMode == "CurrentUser"	
						${andif} $IsAdmin == 0 			
						${andif} $HasPerMachineInstallation == 1
						${andif} $HasPerUserInstallation == 0 
						; has to uninstall the per-machine istalattion, which requires admin rights
						StrCpy $0 1
					${endif}			
				!endif				
			!endif				
			
			${if} $MultiUser.InstallMode == "AllUsers"
				${andif} $IsAdmin == 0 			
				StrCpy $0 1
			${endif}	

			${if} $0 == 1
				HideWindow
				!insertmacro UAC_RunElevated
				;MessageBox MB_OK "[$0]/[$1]/[$2]/[$3]"
				
				;http://www.videolan.org/developers/vlc/extras/package/win32/NSIS/UAC/Readme.html
				;http://nsis.sourceforge.net/UAC_plug-in
				${Switch} $0
					${Case} 0
						${Switch} $1
							${Case} 1	; Started an elevated child process successfully, exit code is in $2
								${Switch} $2
									${Case} ${MULTIUSER_ERROR_ELEVATION_FAILED} ; the inner instance was not admin after all - stay on page
										MessageBox MB_ICONSTOP "You need to login with an account that is a member of the admin group to continue." /SD IDOK
										${Break}
									${Case} ${MULTIUSER_INNER_INSTANCE_BACK} ; if user pressed Back button on the first visible page of the inner instance - stay on page
										${Break}
									${Default} ; all other cases - Quit
										; return code of the elevated fork process is in $2 as well as set via SetErrorLevel
										Quit 
								${EndSwitch}
								${Break}
							${Case} 3 ; RunAs completed successfully, but with a non-admin user - stay on page
								MessageBox MB_ICONSTOP "You need to login with an account that is a member of the admin group to continue." /SD IDOK
								${Break}						
							${Default} ; 0 - UAC is not supported by the OS, OR 2 - The process is already running @ HighIL (Member of admin group) - stay on page
								MessageBox MB_ICONSTOP "Elevation is not supported by your operating system." /SD IDOK
						${EndSwitch}				
						${Break}												
					${Case} 1223 ;user aborted elevation dialog - stay on page
						${Break} 
					${Case} 1062 ; Logon service not running - stay on page
						MessageBox MB_ICONSTOP "Unable to elevate, Secondary Logon service not running" /SD IDOK
						${Break}
					${Default} ; anything else should be treated as a fatal error - stay on page
						MessageBox MB_ICONSTOP "Unable to elevate, error $0" /SD IDOK
				${EndSwitch}				

				; clear the error level set by UAC for inner instance, so that outer instance returns its own error level when exits (the error level is not reset by NSIS if once set and >= 0)
				; see http://forums.winamp.com/showthread.php?p=3079116&posted=1#post3079116
				SetErrorLevel -1
				BringToFront
				Abort ; Stay on page 			
			${endif}
		!endif

		!insertmacro MUI_PAGE_FUNCTION_CUSTOM LEAVE
	FunctionEnd

	Function ${UNINSTALLER_FUNCPREFIX}MultiUser.SetShieldAndTexts
		GetDlgItem $1 $hwndParent 1 ; get item 1 (next button) at parent window, store in $0 - (0 is back, 1 is next .. what about CANCEL? http://nsis.sourceforge.net/Buttons_Header )

		StrCpy $0 0
		${if} $IsAdmin == 0				
			${if} $MultiUser.InstallMode == "AllUsers"
				StrCpy $0 1
			${else} 
				!if ${MULTIUSER_INSTALLMODE_ALLOW_BOTH_INSTALLATIONS} == 0	
					!if "${UNINSTALLER_FUNCPREFIX}" == ""			
						${if} $HasPerUserInstallation == 0
							${andif} $HasPerMachineInstallation == 1 
							StrCpy $0 1
						${endif}	
					!endif
				!endif
			${endif}
		${endif}
		SendMessage $1 ${BCM_SETSHIELD} 0 $0 ; display/hide SHIELD
				
		StrCpy $0 "$MultiUser.InstallMode"
		; if necessary, display text for different install mode than the actual one in $MultiUser.InstallMode
		!if ${MULTIUSER_INSTALLMODE_ALLOW_BOTH_INSTALLATIONS} == 0
			!if "${UNINSTALLER_FUNCPREFIX}" == ""			
				${if} $MultiUser.InstallMode == "AllUsers" ; user selected "all users" 
					${if} $HasPerMachineInstallation == 0
						${andif} $HasPerUserInstallation == 1 
						StrCpy $0 "CurrentUser" ; display information for the "current user" installation
					${endif}	
				${else} ; user selected "current user"
					${if} $HasPerUserInstallation == 0
						${andif} $HasPerMachineInstallation == 1 
						StrCpy $0 "AllUsers"  ; display information for the "all users" installation
					${endif}		
				${endif}
			!endif
		!endif				
			
		; set label text
		StrCpy $7 ""
		${if} $0 == "AllUsers" ; all users
			${if} $HasPerMachineInstallation == 1
				!if "${UNINSTALLER_FUNCPREFIX}" == ""
					StrCpy $7 "Version $PerMachineInstallationVersion is already installed per-machine in $PerMachineInstallationFolder$\r$\n"
					${if} $PerMachineInstallationVersion == ${VERSION}
						StrCpy $7 "$7Will reinstall version ${VERSION}"
					${else}
						StrCpy $7 "$7Will uninstall version $PerMachineInstallationVersion and install version ${VERSION}"
					${endif}	
					${if} $MultiUser.InstallMode == "AllUsers"
						StrCpy $7 "$7 per-machine"
					${else}	
						StrCpy $7 "$7 per-user"
					${endif}
					StrCpy $7 "$7."
				!else
					StrCpy $7 "Version $PerMachineInstallationVersion is installed per-machine in $PerMachineInstallationFolder$\r$\nWill uninstall."
				!endif
			${else}
				StrCpy $7 "Fresh install for all users."
			${endif}
			${if} $IsAdmin == 0
				StrCpy $7 "$7 Will prompt for admin credentials."
			${endif}		
		${else} ; current user
			${if} $HasPerUserInstallation == 1
				!if "${UNINSTALLER_FUNCPREFIX}" == ""
					StrCpy $7 "Version $PerUserInstallationVersion is already installed per-user in $PerUserInstallationFolder$\r$\n"
					${if} $PerUserInstallationVersion == ${VERSION}
						StrCpy $7 "$7Will reinstall version ${VERSION}"
					${else}
						StrCpy $7 "$7Will uninstall version $PerUserInstallationVersion and install version ${VERSION}"
					${endif}
					${if} $MultiUser.InstallMode == "AllUsers"
						StrCpy $7 "$7 per-machine"
					${else}	
						StrCpy $7 "$7 per-user"
					${endif}
					StrCpy $7 "$7."
				!else
					StrCpy $7 "Version $PerUserInstallationVersion is installed per-user in $PerUserInstallationFolder$\r$\nWill uninstall."
				!endif
			${else}
				StrCpy $7 "Fresh install for current user only."
			${endif}		
		${endif}
		SendMessage $MultiUser.RadioButtonLabel1 ${WM_SETTEXT} 0 "STR:$7"
		;SendMessage $RadioButtonLabel2 ${WM_SETTEXT} 0 "STR:$8"
		;SendMessage $RadioButtonLabel3 ${WM_SETTEXT} 0 "STR:$9"
	FunctionEnd

	Function ${UNINSTALLER_FUNCPREFIX}MultiUser.InstallModeOptionClick
		pop $1 ; get clicked control's HWND, which is on the stack in $1

		; set InstallMode
		${if} $1 == $MultiUser.InstallModePage.AllUsers
			Call ${UNINSTALLER_FUNCPREFIX}MultiUser.InstallMode.AllUsers
		${else}	
			Call ${UNINSTALLER_FUNCPREFIX}MultiUser.InstallMode.CurrentUser
		${endif}				

		Call ${UNINSTALLER_FUNCPREFIX}MultiUser.SetShieldAndTexts
	FunctionEnd
	
	!if "${UNINSTALLER_FUNCPREFIX}" == ""
		Function MultiUser.BackButtonClick
			GetDlgItem $0 $HWNDPARENT 1
			SendMessage $0 ${BCM_SETSHIELD} 0 0 ; hide SHIELD	if displayed			
		FunctionEnd	
	!endif
!macroend

; SHCTX is the hive HKLM if SetShellVarContext all, or HKCU if SetShellVarContext user
!macro MULTIUSER_RegistryAddInstallInfo
	!verbose push
	!verbose 3

	; Write the installation path into the registry
	WriteRegStr SHCTX "${MULTIUSER_INSTALLMODE_INSTALL_REGISTRY_KEY2}" "${MULTIUSER_INSTALLMODE_INSTDIR_REGISTRY_VALUENAME}" "$INSTDIR" ; "InstallLocation"

	; Write the uninstall keys for Windows
	${if} $MultiUser.InstallMode == "AllUsers" ; setting defaults
		WriteRegStr SHCTX "${MULTIUSER_INSTALLMODE_UNINSTALL_REGISTRY_KEY2}" "DisplayName" "${MULTIUSER_INSTALLMODE_DISPLAYNAME}"
		WriteRegStr SHCTX "${MULTIUSER_INSTALLMODE_UNINSTALL_REGISTRY_KEY2}" "${MULTIUSER_INSTALLMODE_DEFAULT_REGISTRY_VALUENAME}" '"$INSTDIR\${UNINSTALL_FILENAME}" /allusers' ; "UninstallString"
	${else}
		WriteRegStr SHCTX "${MULTIUSER_INSTALLMODE_UNINSTALL_REGISTRY_KEY2}" "DisplayName" "${MULTIUSER_INSTALLMODE_DISPLAYNAME} (current user)" ; "add/remove programs" will show if installation is per-user
		WriteRegStr SHCTX "${MULTIUSER_INSTALLMODE_UNINSTALL_REGISTRY_KEY2}" "${MULTIUSER_INSTALLMODE_DEFAULT_REGISTRY_VALUENAME}" '"$INSTDIR\${UNINSTALL_FILENAME}" /currentuser' ; "UninstallString"
	${endif}

	WriteRegStr SHCTX "${MULTIUSER_INSTALLMODE_UNINSTALL_REGISTRY_KEY2}" "DisplayVersion" "${VERSION}"
	WriteRegStr SHCTX "${MULTIUSER_INSTALLMODE_UNINSTALL_REGISTRY_KEY2}" "DisplayIcon" "$INSTDIR\${PROGEXE},0"
	WriteRegStr SHCTX "${MULTIUSER_INSTALLMODE_UNINSTALL_REGISTRY_KEY2}" "Publisher" "${COMPANY_NAME}"
	WriteRegDWORD SHCTX "${MULTIUSER_INSTALLMODE_UNINSTALL_REGISTRY_KEY2}" "NoModify" 1
	WriteRegDWORD SHCTX "${MULTIUSER_INSTALLMODE_UNINSTALL_REGISTRY_KEY2}" "NoRepair" 1
	${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2 ; get folder size, convert to KB
	IntFmt $0 "0x%08X" $0
	WriteRegDWORD SHCTX "${MULTIUSER_INSTALLMODE_UNINSTALL_REGISTRY_KEY2}" "EstimatedSize" "$0"

	!verbose pop 
!macroend

!macro MULTIUSER_RegistryRemoveInstallInfo
	!verbose push
	!verbose 3

	; Remove registry keys
	DeleteRegKey SHCTX "${MULTIUSER_INSTALLMODE_UNINSTALL_REGISTRY_KEY2}"
	DeleteRegKey SHCTX "${MULTIUSER_INSTALLMODE_INSTALL_REGISTRY_KEY2}"
 
	!verbose pop 
!macroend

!verbose pop