; Variables
Var SemiSilentMode ; installer started uninstaller in semi-silent mode using /SS parameter
Var RunningFromInstaller ; installer started uninstaller using /uninstall parameter

; Installer Attributes
ShowUninstDetails show 

; Pages
!insertmacro MULTIUSER_UNPAGE_INSTALLMODE

UninstPage components un.PageComponentsPre un.PageComponentsShow un.EmptyCallback

UninstPage instfiles
