!insertmacro DeleteRetryAbortFunc "un."

Var RunningFromInstaller ; installer started uninstaller using /uninstall parameter

; Installer Attributes
ShowUninstDetails show

; Pages
!define MUI_UNABORTWARNING ; Show a confirmation when cancelling the installation

!define MULTIUSER_INSTALLMODE_CHANGE_MODE_FUNCTION un.PageInstallModeChangeMode
!insertmacro MULTIUSER_UNPAGE_INSTALLMODE

!define MUI_PAGE_CUSTOMFUNCTION_SHOW un.PageComponentsShow
!insertmacro MUI_UNPAGE_COMPONENTS

!insertmacro MUI_UNPAGE_INSTFILES