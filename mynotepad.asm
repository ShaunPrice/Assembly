; Notepad like application developed in x86 assembly language (MASM) for Windows
;===============================================================================
; This program is a simple text editor that allows the user to open, save, and save as text files.
; The program uses the Windows API to create a window, menu, edit control, and status bar.
; The user can open a text file, edit the text, and save the changes.
; The program uses the Courier New font for the text editor.
;===============================================================================
; To compile and run this program, you need the MASM32 SDK installed.
; You can download the MASM32 SDK from http://www.masm32.com/download.htm
;===============================================================================
; To compile and link the program, use the masm32 editor qedit or install
; Visual Sytudio and following commands in the developer command prompt:
;
; ml /coff mynotepad.asm /link /SUBSYSTEM:WINDOWS user32.lib gdi32.lib kernel32.lib comctl32.lib
;===============================================================================

.486
.model flat, stdcall
option casemap:none

; Include files
include \masm32\include\windows.inc
include \masm32\include\user32.inc
include \masm32\include\kernel32.inc
include \masm32\include\gdi32.inc
include \masm32\include\comctl32.inc
include \masm32\include\comdlg32.inc
include \masm32\include\shell32.inc

includelib \masm32\lib\user32.lib
includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\gdi32.lib
includelib \masm32\lib\comctl32.lib
includelib \masm32\lib\comdlg32.lib
includelib \masm32\lib\shell32.lib

; Forward declarations
UpdateMenuItems PROTO :DWORD
DoOpenFile PROTO :DWORD
DoSaveFile PROTO :DWORD, :DWORD
CloseFile PROTO

; Constants
.data
format db "%d", 0
ClassName db "MyWindowClass",0

AppName db "Shaun's Notepad",0
AboutText db "This is a simple text editor created in x86 assembly language by Shaun Price", 0

; Flags
fileIsOpen dd 0   ; 0 = No file open, 1 = File open

; Menu items
File db "&File", 0 ; Menu item for "File" menu
Open db "&Open", 9, "Ctrl+O", 0 ; Menu item for "Open" menu
Save db "&Save", 9, "Ctrl+S",0 ; Menu item for "Save" menu
SaveAs db "Save As", 9, "Ctrl+Shift+S", 0 ; Menu item for "Save As" menu
Exit db "E&xit", 0 ; Menu item for "Exit" menu
Font db "Font", 0 ; Menu item for "Font" menu
Edit db "&Edit", 0 ; Menu item for "Edit" menu
Help db "&Help", 0 ; Menu item for "Help" menu
About db "About", 9, "F1", 0 ; Menu item for "About" menu

; IDs for the menu items
IDM_FILE equ 1000
IDM_OPEN equ 1010
IDM_SAVE equ 1030
IDM_SAVEAS equ 1031
IDM_EXIT equ 1090
IDM_EDIT equ 2000
IDM_FONT equ 2010
IDM_HELP equ 9000
IDM_ABOUT equ 9010


; ID for the accelerator table
IDA_OPEN equ 101
IDA_SAVE equ 102
IDA_SAVEAS equ 103
IDA_EXIT equ 104
IDA_ABOUT equ 105

; Define ACCEL structures
accelTable      ACCEL   <FVIRTKEY + FCONTROL, 'O', IDA_OPEN>, \
                        <FVIRTKEY + FCONTROL, 'S', IDA_SAVE>, \
                        <FVIRTKEY + FCONTROL + FSHIFT, 'S', IDA_SAVEAS>, \
                        <FVIRTKEY + FCONTROL, 'X', IDA_EXIT>, \
                        <FVIRTKEY, VK_F1, IDA_ABOUT>

OpenFileNameTitle db "Open Text File", 0
FilterString db "Text files (*.txt)",0, "*.txt",0, "All files",0, "*.*",0, 0
buffer db 256 dup(?)  ; Define a buffer for 256 characters
nChars dd ?  ; Number of characters in the buffer

EditClassName db "EDIT",0  ; Class name for edit control
CourierFontName db "Courier New",0

STATUSCLASSNAME db "msctls_statusbar32", 0
StatusBarText db " ", 0
statusBarHeight dd 20
rect RECT <>

; Error message captions
szErrorCaptionNoOpen db "Could not open file", 0
szErrorCaptionNoRead db "Could not read file", 0
szErrorCaptionNoWrite db "Could not write file", 0
szErrorCaptionNoMemory db "Could not allocated mmemory", 0
szErrorCaptionNoText db "No text to save", 0

; Variables
.data?

; Window variables
hInstance HINSTANCE ?
m_hWnd HWND ?
hMenu HMENU ?
hEdit HWND ?
hAccelTable HANDLE ?

; Menu handles
hFileMenu HMENU ?
hOpenMenu HMENU ?
hSaveMenu HMENU ?
hSaveAsMenu HMENU ?
hExitMenu HMENU ?

hEditMenu HMENU ?
hFontMenu HMENU ?

hHelpMenu HMENU ?
hAboutMenu HMENU ?

; Status bar handle
hStatusBar HWND ?

hFont HANDLE ?      ; Handle to the font
msg MSG <>          ; Message structure
m_uMsg dd ?         ; Message ID
wc WNDCLASSEX <>    ; Window class structure

; File handling variables
ofn OPENFILENAME <>
szFileName db MAX_PATH dup(?)
szFileTitle db MAX_PATH dup(?)
fileHandle HANDLE ?
fileSize DWORD ?
fileSize16 DWORD ?
hFileMap HANDLE ?
hFile HANDLE ?
lpFileBase LPVOID ?
lpFileBase16 LPVOID ?
bytesRead DWORD ?
dwWritten DWORD ?

.code
; Entry point
start:
    ; Initialize the variables
    mov fileIsOpen, 0
    mov hFile, NULL
    mov hFileMap, NULL
    mov lpFileBase, NULL
    mov bytesRead, 0
    mov dwWritten, 0
    mov fileSize, 0
    mov nChars, 0
    mov m_uMsg, 0
    mov szFileName, 0
    mov szFileTitle, 0
    mov ofn.lStructSize, SIZEOF OPENFILENAME
    mov ofn.hwndOwner, NULL 
    mov ofn.hInstance, NULL
    mov ofn.lpstrFilter, OFFSET FilterString
    mov ofn.lpstrCustomFilter, NULL
    mov ofn.nMaxCustFilter, 0
    mov ofn.nFilterIndex, 0
    mov ofn.lpstrFile, OFFSET szFileName
    mov ofn.nMaxFile, MAX_PATH
    mov ofn.lpstrFileTitle, OFFSET szFileTitle
    mov ofn.nMaxFileTitle, MAX_PATH
    mov ofn.lpstrInitialDir, NULL
    mov ofn.lpstrTitle, OFFSET OpenFileNameTitle
    mov ofn.Flags, OFN_FILEMUSTEXIST or OFN_PATHMUSTEXIST or OFN_HIDEREADONLY
    mov ofn.nFileOffset, 0
    mov ofn.nFileExtension, 0
    mov ofn.lpstrDefExt, NULL
    mov ofn.lCustData, 0
    mov ofn.lpfnHook, NULL
    mov ofn.lpTemplateName, NULL
    mov ofn.lpstrFileTitle, OFFSET szFileTitle
    mov ofn.nMaxFileTitle, MAX_PATH
    mov ofn.lpstrInitialDir, NULL

    ; Register the window class
    invoke GetModuleHandle, NULL
    mov hInstance, eax

    mov wc.cbSize, sizeof WNDCLASSEX
    mov wc.style, CS_HREDRAW or CS_VREDRAW
    lea eax, WndProc
    mov wc.lpfnWndProc, eax
    mov wc.cbClsExtra, 0
    mov wc.cbWndExtra, 0
    mov eax, hInstance
    mov wc.hInstance, eax
    invoke LoadCursor, NULL, IDC_ARROW
    mov wc.hCursor, eax
    mov wc.hbrBackground, COLOR_WINDOW + 1
    mov wc.lpszMenuName, NULL
    mov wc.lpszClassName, OFFSET ClassName
    invoke LoadIcon, NULL, IDI_APPLICATION
    mov wc.hIcon, eax
    mov wc.hIconSm, eax

    ; Create a menu for the window
    invoke CreateMenu
    mov hMenu, eax

    ; File menu
    invoke CreatePopupMenu
    mov hFileMenu, eax

    ; Open menu
    invoke CreatePopupMenu
    mov hOpenMenu, eax

    ; Save menu
    invoke CreatePopupMenu
    mov hSaveMenu, eax

    ; Save As menu
    invoke CreatePopupMenu
    mov hSaveAsMenu, eax

    ; Exit menu
    invoke CreatePopupMenu
    mov hExitMenu, eax

    ; Edit menu
    invoke CreatePopupMenu
    mov hEditMenu, eax

    ; Font menu
    invoke CreatePopupMenu
    mov hFontMenu, eax

    ; Help menu
    invoke CreatePopupMenu
    mov hHelpMenu, eax

    ; About menu
    invoke CreatePopupMenu
    mov hAboutMenu, eax

    ; Add menu items to the menus
    invoke AppendMenu, hFileMenu, MF_STRING, IDM_OPEN, addr Open
    invoke AppendMenu, hFileMenu, MF_SEPARATOR, 0, NULL
    invoke AppendMenu, hFileMenu, MF_STRING, IDM_SAVE, addr Save
    invoke AppendMenu, hFileMenu, MF_STRING, IDM_SAVEAS, addr SaveAs
    invoke AppendMenu, hFileMenu, MF_SEPARATOR, 0, NULL
    invoke AppendMenu, hFileMenu, MF_STRING, IDM_EXIT, addr Exit
    invoke AppendMenu, hMenu, MF_POPUP, hFileMenu, addr File

    invoke AppendMenu, hEditMenu, MF_STRING, IDM_FONT, addr Font
    invoke AppendMenu, hMenu, MF_POPUP, hEditMenu, addr Edit
    
    ; Add the Help menu to the right
    invoke AppendMenu, hHelpMenu, MF_STRING, IDM_ABOUT, addr About
    invoke AppendMenu, hMenu, MF_POPUP, hHelpMenu, addr Help

    ; Set the menu for the window
    invoke RegisterClassEx, ADDR wc
    invoke CreateWindowEx, 0, ADDR ClassName, ADDR AppName, WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT, 400, 300, NULL, hMenu, hInstance, NULL
    mov m_hWnd, eax
    invoke UpdateMenuItems, m_hWnd
    invoke ShowWindow, m_hWnd, SW_SHOWNORMAL
    invoke UpdateWindow, m_hWnd

    ; Create the accelerator table
    invoke CreateAcceleratorTable, ADDR accelTable, 5
    mov hAccelTable, eax

    ; Message loop
    .WHILE TRUE
        invoke GetMessage, ADDR msg, NULL, 0, 0 ; Get the next message
        .BREAK .IF !eax                         ; Exit if WM_QUIT received
        ; Use TranslateAccelerator to handle accelerator keys
        invoke TranslateAccelerator, m_hWnd, hAccelTable, ADDR msg
        .CONTINUE .IF eax  ; If non-zero, the message was handled
        invoke TranslateMessage, ADDR msg       ; Translate the message
        invoke DispatchMessage, ADDR msg        ; Dispatch the message
    .ENDW

    ; Exit the application
    invoke ExitProcess, msg.wParam

; Update the menu items based on the fileIsOpen flag
UpdateMenuItems PROC hWnd:HWND
    LOCAL menu:DWORD

    ; Get the menu handle
    invoke GetMenu, hWnd
    mov menu, eax

    .IF fileIsOpen == 0
        ; Disable the "Save" menu item
        invoke EnableMenuItem, menu, 1030, MF_BYCOMMAND or MF_GRAYED   ; 1030 is the ID for "Save"
    .ELSE
        ; Enable the "Save" menu item
        invoke EnableMenuItem, menu, 1030, MF_BYCOMMAND or MF_ENABLED
    .ENDIF
    ret
UpdateMenuItems ENDP

; Display Last Error Message
DisplayError PROC hWnd:HWND, dwError:DWORD, szCaption:LPSTR
    LOCAL msgBuffer[256]:BYTE

    ; Format the error message
    invoke FormatMessage, FORMAT_MESSAGE_FROM_SYSTEM, NULL, dwError, 0, ADDR msgBuffer, SIZEOF msgBuffer, NULL
                
    ; Display the error message
    invoke MessageBox, hWnd, ADDR msgBuffer, ADDR szCaption, MB_ICONERROR

    ret
DisplayError ENDP

; Open a file
DoOpenFile PROC hWnd:HWND

    ; Close the file if one is already open
    invoke CloseHandle, hFile  ; Close old handle if needed

    ; Setup the OPENFILENAME structure
    mov ofn.lStructSize, SIZEOF OPENFILENAME
    push hWnd
    pop ofn.hwndOwner
    lea eax, szFileName
    mov ofn.lpstrFile, eax
    mov byte ptr [eax], 0  ; Ensure the string is initially empty
    mov eax, MAX_PATH
    mov ofn.nMaxFile, eax
    lea eax, szFileTitle
    mov ofn.lpstrFileTitle, eax
    mov eax, MAX_PATH
    mov ofn.nMaxFileTitle, eax
    lea eax, FilterString
    mov ofn.lpstrFilter, eax
    mov ofn.Flags, OFN_FILEMUSTEXIST or OFN_HIDEREADONLY

    ; Show the Open dialog box
    invoke GetOpenFileName, ADDR ofn
    .IF eax != 0
        ; Open the file and store the handle
        invoke CreateFile, ADDR szFileName, GENERIC_READ or GENERIC_WRITE, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL
        mov hFile, eax  ; Store handle globally

        .IF eax != INVALID_HANDLE_VALUE
            mov fileIsOpen, 1  ; Indicate that a file is now open

            ; Get the file size
            invoke GetFileSize, eax, NULL
            mov fileSize, eax            

            .IF fileSize != 0
                ; Allocate memory for the file content + 1 for null terminator
                invoke GlobalAlloc, GMEM_FIXED or GMEM_ZEROINIT, fileSize + 2 
                mov lpFileBase, eax

                .IF eax != NULL
                    ; Read file content into the buffer
                    invoke ReadFile, hFile, lpFileBase, fileSize, ADDR bytesRead, NULL

                    .IF eax == 0
                        ; Display the error message
                        invoke GetLastError
                        invoke DisplayError, hWnd, eax, ADDR szErrorCaptionNoRead
                        
                        ; Free the buffer
                        invoke GlobalFree, lpFileBase
                    .ELSE
                        ; Set the text in the edit control
                        invoke SendMessage, hEdit, WM_SETTEXT, 0, lpFileBase

                        ; Free the buffer
                        invoke GlobalFree, lpFileBase
                    .ENDIF
                .ELSE
                    ; Display the error message
                    invoke GetLastError
                    invoke DisplayError, hWnd, eax, ADDR szErrorCaptionNoOpen

                    ret
                .ENDIF
            .ELSE
                ; Display the error message
                invoke GetLastError
                invoke DisplayError, hWnd, eax, ADDR szErrorCaptionNoOpen

                ret
            .ENDIF
            invoke UpdateMenuItems, hWnd ; Update the menu items
            invoke SendMessage, hStatusBar, SB_SETTEXT, 0, ADDR szFileName ; Update the status bar     
        .ENDIF
    .ENDIF
    ret
DoOpenFile ENDP

; Save a file
DoSaveFile PROC hWnd:HWND, bSaveAs:BOOL

    .IF bSaveAs == TRUE || szFileName[0] == 0
        ; Use a file dialog to get a new filename if saving for the first time or if Save As is requested
        mov ofn.lStructSize, SIZEOF OPENFILENAME
        push hWnd
        pop ofn.hwndOwner
        lea eax, szFileName
        mov ofn.lpstrFile, eax
        mov dword ptr [eax], 0  ; Ensure the string is initially empty
        mov eax, MAX_PATH
        mov ofn.nMaxFile, eax
        lea eax, szFileTitle
        mov ofn.lpstrFileTitle, eax
        mov eax, MAX_PATH
        mov ofn.nMaxFileTitle, eax
        lea eax, FilterString
        mov ofn.lpstrFilter, eax
        mov ofn.Flags, OFN_OVERWRITEPROMPT or OFN_HIDEREADONLY
        invoke GetSaveFileName, ADDR ofn ; Show the Save As dialog

        ; Check if the user canceled the dialog
        .IF eax == 0
            ret
        .ELSE
            ; Assume file handle needs to be reopened or adjusted here
            invoke CloseHandle, hFile  ; Close old handle if needed

            ; Create a new file
            invoke CreateFile, ADDR szFileName, GENERIC_WRITE, FILE_SHARE_READ or FILE_SHARE_WRITE, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL
            
            mov hFile, eax  ; Update handle globally

            ; Ensure the file was created
            .IF eax == INVALID_HANDLE_VALUE
                ; Handle the error

                ; Set fileIsOpen to 0 to indicate that no file is open
                mov fileIsOpen, 0

                ; Set the file handle to NULL
                mov hFile, NULL

                ; Display the error message
                invoke GetLastError
                invoke DisplayError, hWnd, eax, ADDR szErrorCaptionNoOpen

                ; Clear the file name
                mov szFileName, 0

                ; Clear the status bar
                invoke SendMessage, hStatusBar, SB_SETTEXT, 0, ADDR StatusBarText

                ; Clear the text in the edit control
                invoke SendMessage, hEdit, WM_SETTEXT, 0, ADDR buffer

                ret
            .ELSE
                mov fileIsOpen, 1  ; Indicate that a file is now open
                invoke UpdateMenuItems, m_hWnd ; Update the menu items
                invoke SendMessage, hStatusBar, SB_SETTEXT, 0, ADDR szFileName  ; Update the status bar
            .ENDIF
        .ENDIF
    .ENDIF

    ; Get the length of the text to be saved.
    invoke SendMessage, hEdit, WM_GETTEXTLENGTH, 0, 0
    mov fileSize, eax  ; Store the length of the text.

    ; Calculate the file size in UTF-16
    shl eax, 1
    mov fileSize16, eax

    ; Allocate memory for the text.
    invoke GlobalAlloc, GMEM_FIXED or GMEM_ZEROINIT, fileSize + 1
    mov lpFileBase, eax  ; Store the address of the allocated memory.

        ; Check if the memory was allocated.
    .IF lpFileBase == NULL
        ; Display the error message
        invoke GetLastError
        invoke DisplayError, hWnd, eax, ADDR szErrorCaptionNoMemory

        ret
    .ENDIF

    ; Get the text from the edit control.
    invoke SendMessage, hEdit, WM_GETTEXT, fileSize + 1, lpFileBase

    ; Check if the text was retrieved.
    .IF eax == 0
        ; Display the error message
        invoke GetLastError
        invoke DisplayError, hWnd, eax, ADDR szErrorCaptionNoText

        ; Free the allocated memory.
        invoke GlobalFree, lpFileBase

        ret
    .ELSE
        ; Set the file pointer to the start of the file.
        invoke SetFilePointer, hFile, 0, NULL, FILE_BEGIN

        ; Truncate the file to the new size.
        invoke SetEndOfFile, hFile

        ; Write the text to the file and resize the file.
        invoke WriteFile, hFile, lpFileBase, fileSize, ADDR dwWritten, NULL

        ; Move dwWritten to ebx
        mov ebx, dwWritten

        ; Check if the text was written.
        .IF eax == 0 || ebx != fileSize
            ; Display the error message
            invoke GetLastError
            invoke DisplayError, hWnd, eax, ADDR szErrorCaptionNoWrite

            ; Free the allocated memory.
            invoke GlobalFree, lpFileBase

            ret
        .ELSEIF 
        .ENDIF
    .ENDIF

    ; Free the allocated memory.
    invoke GlobalFree, lpFileBase

    ret
DoSaveFile ENDP

; Close the file
CloseFile PROC
    ; Check if a file is open
    .IF hFile != NULL
        ; Close the file handle
        invoke CloseHandle, hFile
        mov hFile, NULL
    .ENDIF
    
    ret
CloseFile endp

; Font dialog
DoFont PROC hWnd:HWND
    LOCAL cf:CHOOSEFONT
    LOCAL lf:LOGFONT

    ; Initialize the LOGFONT structure
    mov lf.lfHeight, -16
    mov lf.lfWidth, 0
    mov lf.lfEscapement, 0
    mov lf.lfOrientation, 0
    mov lf.lfWeight, FW_NORMAL
    mov lf.lfItalic, FALSE
    mov lf.lfUnderline, FALSE
    mov lf.lfStrikeOut, FALSE
    mov lf.lfCharSet, DEFAULT_CHARSET
    mov lf.lfOutPrecision, OUT_DEFAULT_PRECIS
    mov lf.lfClipPrecision, CLIP_DEFAULT_PRECIS
    mov lf.lfQuality, DEFAULT_QUALITY
    mov lf.lfPitchAndFamily, FIXED_PITCH or FF_DONTCARE
    lea esi, CourierFontName       ; Load the address of the source string into ESI
    lea edi, lf.lfFaceName         ; Load the address of the destination in the LOGFONT structure into EDI
    mov ecx, 32                    ; Maximum number of characters to copy (size of lfFaceName)
    cld                            ; Clear the direction flag for forward movement
    rep movsb                      ; Copy string byte by byte from [ESI] to [EDI] using ECX as the counter

    ; Initialize the CHOOSEFONT structure
    mov cf.lStructSize, SIZEOF CHOOSEFONT
    push hWnd
    pop cf.hwndOwner
    mov cf.hDC, NULL
    lea eax, lf
    mov cf.lpLogFont, eax
    mov cf.iPointSize, 0
    mov cf.Flags, CF_SCREENFONTS or CF_INITTOLOGFONTSTRUCT
    mov cf.rgbColors, 0
    mov cf.lCustData, 0
    mov cf.lpfnHook, NULL
    mov cf.lpTemplateName, NULL
    mov cf.hInstance, NULL
    mov cf.lpszStyle, NULL
    mov cf.nFontType, SCREEN_FONTTYPE
    mov cf.nSizeMin, 0
    mov cf.nSizeMax, 0

    ; Show the font dialog
    invoke ChooseFont, ADDR cf

    ; Check if the user clicked OK
    .IF eax != 0
        ; Create a new font
        invoke CreateFontIndirect, ADDR lf
        mov hFont, eax

        ; Set the font of the edit control
        invoke SendMessage, hEdit, WM_SETFONT, hFont, TRUE
    .ENDIF

    ret
DoFont endp

; Resize the edit control to fill the main window
ResizeEditControl PROC hWnd:HWND, leftMargin:DWORD, rightMargin:DWORD, topMargin:DWORD, bottomMargin:DWORD, newWidth:DWORD, newHeight:DWORD
    LOCAL editRect:RECT

    ; Get the client area of the main window
    invoke GetClientRect, hWnd, ADDR editRect

    ; Calculate the new width and height of the edit control
    mov eax, editRect.right
    sub eax, editRect.left
    sub eax, leftMargin
    sub eax, rightMargin
    mov ecx, editRect.bottom
    sub ecx, editRect.top
    sub ecx, topMargin
    sub ecx, bottomMargin

    ; Resize the edit control
    invoke MoveWindow, hEdit, leftMargin, topMargin, eax, ecx, TRUE

    ret
ResizeEditControl ENDP

; Show an About box with information about the program
ShowAboutBox PROC hWnd:HWND
    ; Display the About box
    invoke MessageBox, hWnd, ADDR AboutText, ADDR AppName, MB_ICONINFORMATION or MB_OK

    ret
ShowAboutBox ENDP

; Window procedure
WndProc proc hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
    .IF uMsg == WM_COMMAND
        ; Extract the command identifier and the notification code
        mov eax, wParam
        mov ecx, eax
        shr ecx, 16         ; HIWORD(wParam) - Notification code or source
        and eax, 0FFFFh     ; LOWORD(wParam) - Command identifier

        ; Check if the message is from a menu or an accelerator
        .IF ecx == 0
            ; Handle the menu command
            .IF eax == IDM_OPEN
                ; Handle Open from menu
                invoke DoOpenFile, hWnd
            .ELSEIF eax == IDM_SAVE
                ; Handle Save from menu
                invoke DoSaveFile, hWnd, FALSE
            .ELSEIF eax == IDM_SAVEAS
                ; Handle Save As from menu
                invoke DoSaveFile, hWnd, TRUE
            .ELSEIF eax == IDM_EXIT
                ; Handle Exit from menu
                invoke CloseFile
                invoke PostQuitMessage, 0
            .ELSEIF eax == IDM_FONT
                ; Handle Font from menu
                invoke DoFont, hWnd
            .ELSEIF eax == IDM_ABOUT
                ; Handle About from menu
                invoke ShowAboutBox, hWnd
            .ENDIF
        .ELSEIF ecx == 1
            ; Handle the accelerator command
            .IF eax == IDA_OPEN
                ; Handle Open (Ctrl+O or Menu)
                invoke DoOpenFile, hWnd
            .ELSEIF eax == IDA_SAVE
                ; Handle Save (Ctrl+S or Menu)
                invoke DoSaveFile, hWnd, FALSE
            .ELSEIF eax == IDA_SAVEAS
                ; Handle Save As (Ctrl+Shift+S or Menu)
                invoke DoSaveFile, hWnd, TRUE
            .ELSEIF eax == IDA_EXIT
                ; Handle Exit (Ctrl+X or Menu)
                invoke CloseFile
                invoke PostQuitMessage, 0
            .ELSEIF eax == IDA_ABOUT
                ; Handle About (F1 or Menu)
                invoke ShowAboutBox, hWnd
            .ENDIF
        .ENDIF
    .ELSEIF uMsg == WM_CREATE
        ; Create an Edit Control
        invoke CreateWindowEx, WS_EX_CLIENTEDGE, ADDR EditClassName, NULL, WS_CHILD or WS_VISIBLE or WS_VSCROLL or ES_LEFT or ES_MULTILINE or ES_AUTOVSCROLL, 0, 0, 100, 100, hWnd, NULL, hInstance, NULL
        mov hEdit, eax

        ; Create a Status Bar
        invoke CreateWindowEx, 0, ADDR STATUSCLASSNAME, NULL, WS_CHILD or WS_VISIBLE or SBARS_SIZEGRIP, 0, 0, 0, 0, hWnd, NULL, hInstance, NULL
        mov hStatusBar, eax

        ; Resize the Edit Control to fill the main window, accounting for the status bar
        invoke GetClientRect, hWnd, ADDR rect
        mov eax, rect.right
        sub eax, rect.left
        mov ecx, rect.bottom
        sub ecx, rect.top
        sub ecx, statusBarHeight
        invoke MoveWindow, hEdit, 0, 0, eax, ecx, TRUE

        ; Create a Courier New font
        invoke CreateFont, -16, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
                OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY,
                FIXED_PITCH or FF_DONTCARE, ADDR CourierFontName
        mov hFont, eax

        ; Set the font of the edit control
        invoke SendMessage, hEdit, WM_SETFONT, eax, TRUE

    .ELSEIF uMsg == WM_SIZE
        ; Resize the Edit Control to fill the main window, accounting for the status bar
        mov eax,lParam ; lParam contains the new width and height of the window
        and eax, 0FFFFh ; LOWORD(l_lParam) ; Get the width of the window
        mov ecx, lParam ;
        shr ecx, 16 ; HIWORD(l_lParam) ; Get the height of the window
        sub ecx, statusBarHeight ; Subtract the height of the status bar
        invoke MoveWindow, hEdit, 0, 0, eax, ecx, TRUE ; Resize the Edit Control

        ; Resize the status bar
        invoke MoveWindow, hStatusBar, 0, ecx, eax, statusBarHeight, TRUE

    .ELSEIF uMsg == WM_DESTROY
        invoke CloseFile
        invoke PostQuitMessage, 0
    .ELSE
        invoke DefWindowProc, hWnd, uMsg, wParam, lParam
    .ENDIF
    ret
WndProc endp

end start
