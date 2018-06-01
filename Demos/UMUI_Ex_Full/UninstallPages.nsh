; Installer Attributes
ShowUninstDetails show 

; Interface settings
!define MUI_UNABORTWARNING ; Show a confirmation when cancelling the installation

; Pages
!insertmacro UMUI_UNPAGE_MULTILANGUAGE

!define MULTIUSER_INSTALLMODE_CHANGE_MODE_FUNCTION un.PageInstallModeChangeMode
!insertmacro MULTIUSER_UNPAGE_INSTALLMODE

!define MUI_PAGE_CUSTOMFUNCTION_PRE un.PageComponentsPre
!define MUI_PAGE_CUSTOMFUNCTION_SHOW un.PageComponentsShow
!insertmacro MUI_UNPAGE_COMPONENTS

!insertmacro MUI_UNPAGE_INSTFILES
