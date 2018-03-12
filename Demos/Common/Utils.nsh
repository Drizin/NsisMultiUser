!include LogicLib.nsh
!include x64.nsh

!define ERROR_ALREADY_EXISTS 0x000000b7
!define ERROR_ACCESS_DENIED 0x5

!macro CheckPlatform PLATFORM
	${if} ${RunningX64}
		!if ${PLATFORM} == "Win32"
			MessageBox MB_ICONSTOP "Please, run the 64-bit installer of ${PRODUCT_NAME} on this version of Windows." /SD IDOK
			Quit ; will SetErrorLevel 2 - Installation aborted by script
		!endif
	${else}
		!if ${PLATFORM} == "Win64"
			MessageBox MB_ICONSTOP "Please, run the 32-bit installer of ${PRODUCT_NAME} on this version of Windows." /SD IDOK
			Quit ; will SetErrorLevel 2 - Installation aborted by script
		!endif
	${endif}		
!macroend

!macro CheckMinWinVer MIN_WIN_VER
	${ifnot} ${AtLeastWin${MIN_WIN_VER}}	
		MessageBox MB_ICONSTOP "This program requires at least Windows ${MIN_WIN_VER}." /SD IDOK
		Quit ; will SetErrorLevel 2 - Installation aborted by script
	${endif}	
!macroend

!macro CheckSingleInstance SINGLE_INSTANCE_ID
	Push "$0"
	Push "$1"
	
	System::Call 'kernel32::CreateMutex(i 0, i 0, t "Global\${SINGLE_INSTANCE_ID}") i .r0 ?e'	
	Pop $1 ; the stack contains the result of GetLastError
	${if} $1 == "${ERROR_ALREADY_EXISTS}"
		${orif} $1 == "${ERROR_ACCESS_DENIED}"	; ERROR_ACCESS_DENIED means the mutex was created by another user and we don't have access to open it, so application is running
		System::Call 'kernel32::CloseHandle(i $0)' ; if the user closes the already running instance, allow to start a new one without closing the MessageBox

		; will display NSIS taskbar button, no way to hide it before GUIInit, $HWNDPARENT is 0
		MessageBox MB_ICONSTOP "The setup of ${PRODUCT_NAME} is already running." /SD IDOK
		
		Quit ; will SetErrorLevel 2 - Installation aborted by script
	${endif}
	
	Pop $1 
	Pop $0
!macroend

!macro DeleteRetryAbortFunc UNINSTALLER_PREFIX
	Function ${UNINSTALLER_PREFIX}DeleteRetryAbort
		; unlike the File instruction, Delete doesn't abort (un)installation on error - it just sets the error flag and skips the file as if nothing happened
		try:
		ClearErrors
		Delete "$0"
		${if} ${errors}
			MessageBox MB_RETRYCANCEL|MB_ICONSTOP "Error deleting file:$\r$\n$\r$\n$0$\r$\n$\r$\nClick Retry to try again, or$\r$\nCancel to stop the uninstall." /SD IDCANCEL IDRETRY try		
			Abort "Error deleting file $0" ; when called from section, will SetErrorLevel 2 - Installation aborted by script
		${endif}
	FunctionEnd
!macroend

!insertmacro DeleteRetryAbortFunc "un."

!macro DeleteRetryAbort filename
	Push "$0"
	
	StrCpy $0 "${filename}"
	Call DeleteRetryAbort
	
	Pop $0
!macroend

!macro un.DeleteRetryAbort filename
	Push "$0"	
	
	StrCpy $0 "${filename}"
	Call un.DeleteRetryAbort
	
	Pop $0	
!macroend
