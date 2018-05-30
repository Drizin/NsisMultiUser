!insertmacro DeleteRetryAbortFunc "un."

Section "un.Program Files" SectionUninstallProgram
	SectionIn RO

	; Try to delete the EXE as the first step - if it's in use, don't remove anything else
	!insertmacro un.DeleteRetryAbort "$INSTDIR\${PROGEXE}"
	!ifdef LICENSE_FILE
		!insertmacro un.DeleteRetryAbort "$INSTDIR\${LICENSE_FILE}"
	!endif

	; Clean up "Documentation"
	!insertmacro un.DeleteRetryAbort "$INSTDIR\readme.txt"

	; Clean up "Program Group"
	!insertmacro MULTIUSER_GetCurrentUserString $0
	RMDir /r "$SMPROGRAMS\${PRODUCT_NAME}$0"

	; Clean up "Dektop Icon"
	!insertmacro MULTIUSER_GetCurrentUserString $0
	!insertmacro un.DeleteRetryAbort "$DESKTOP\${PRODUCT_NAME}$0.lnk"

	; Clean up "Start Menu Icon"
	!insertmacro MULTIUSER_GetCurrentUserString $0
	!insertmacro un.DeleteRetryAbort "$STARTMENU\${PRODUCT_NAME}$0.lnk"

	; Clean up "Quick Launch Icon"
	!insertmacro un.DeleteRetryAbort "$QUICKLAUNCH\${PRODUCT_NAME}.lnk"
SectionEnd

Section /o "un.Program Settings" SectionRemoveSettings
	; this section is executed only explicitly and shouldn't be placed in SectionUninstallProgram
	DeleteRegKey HKCU "Software\${PRODUCT_NAME}"
SectionEnd

Section "-Uninstall" ; hidden section, must always be the last one!
	Delete "$INSTDIR\${UNINSTALL_FILENAME}" ; we cannot use un.DeleteRetryAbort here - when using the _? parameter the uninstaller cannot delete itself and Delete fails, which is OK
	; remove the directory only if it is empty - the user might have saved some files in it
	RMDir "$INSTDIR"
	
	; Remove the uninstaller from registry as the very last step - if sth. goes wrong, let the user run it again
	!insertmacro MULTIUSER_RegistryRemoveInstallInfo ; Remove registry keys	
SectionEnd

; Callbacks
Function un.onInit
	${GetParameters} $R0

	${GetOptions} $R0 "/uninstall" $R1
	${ifnot} ${errors}
		StrCpy $RunningFromInstaller 1
	${else}
		StrCpy $RunningFromInstaller 0
	${endif}

	${GetOptions} $R0 "/SS" $R1
	${ifnot} ${errors}
		StrCpy $SemiSilentMode 1
		SetAutoClose true ; auto close (if no errors) if we are called from the installer; if there are errors, will be automatically set to false
	${else}
		StrCpy $SemiSilentMode 0
	${endif}

	${ifnot} ${UAC_IsInnerInstance}
		${andif} $RunningFromInstaller$SemiSilentMode == "00"
		!insertmacro CheckSingleInstance "${SINGLE_INSTANCE_ID}"
	${endif}

	!insertmacro MULTIUSER_UNINIT
	
	ReadRegStr $LANGUAGE ${LANGDLL_REGISTRY_ROOT} "${LANGDLL_REGISTRY_KEY}" "${LANGDLL_REGISTRY_VALUENAME}" ; we always get the language, since the outer and inner instance might have different language
	${if} "$LANGUAGE" == ""
		${if} ${silent}
		    StrCpy $LANGUAGE ${LANG_ENGLISH}
		${else}
		    ; languages will be alphabetically sorted, first alpabetical will be selected
			Push ""
			Push ${LANG_ENGLISH}
			Push "English"
			Push ${LANG_BULGARIAN}
			Push "Bulgarian"
			Push "A" ; A means auto count languages; for the auto count to work the first empty push (Push "") must remain
			LangDLL::LangDialog "Installer Language" "Please select the language of the installer"

			Pop $LANGUAGE
			${if} "$LANGUAGE" == "cancel"
				Abort
			${endif}
		${endif}
	${endif}
FunctionEnd

Function un.EmptyCallback
FunctionEnd

Function un.PageComponentsPre
	${if} $SemiSilentMode = 1
		Abort ; if user is installing, no use to remove program settings anyway (should be compatible with all versions)
	${endif}
FunctionEnd

Function un.PageComponentsShow
	; Show/hide the Back button
	GetDlgItem $0 $HWNDPARENT 3
	ShowWindow $0 $UninstallShowBackButton
FunctionEnd

Function un.onUserAbort
	MessageBox MB_YESNO|MB_ICONEXCLAMATION "Are you sure you want to quit $(^Name) Uninstall?" IDYES mui.quit

	Abort
	mui.quit:
FunctionEnd

Function un.onUninstFailed
	${if} $SemiSilentMode = 0
		MessageBox MB_ICONSTOP "${PRODUCT_NAME} ${VERSION} could not be fully uninstalled.$\r$\nPlease, restart Windows and run the uninstaller again." /SD IDOK
	${else}
		MessageBox MB_ICONSTOP "${PRODUCT_NAME} could not be fully installed.$\r$\nPlease, restart Windows and run the setup program again." /SD IDOK
	${endif}
FunctionEnd
