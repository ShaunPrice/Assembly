; Notepad like application developed in MACRO ASSEMBLY LANGUAGE (MASM) for Windows
;===============================================================================
; This program is a simple text editor that allows the user to open, save, and save as text files.
; The program uses the Windows API to create a window, menu, edit control, and status bar.
; The user can open a text file, edit the text, and save the changes.
; The program uses the Courier New font for the text editor.
;===============================================================================
; To compile and run this program, you need the MASM32 SDK installed.
; You can download the MASM32 SDK from http://www.masm32.com/download.htm
;===============================================================================
; To compile and link the program, use the following commands:
; Run under the developer command prompt for Visual Studio 2022 where ml and link are available
;
; ml /coff mywin.asm /link /SUBSYSTEM:WINDOWS user32.lib gdi32.lib kernel32.lib comctl32.lib
;===============================================================================

.386
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
File db "File", 0 ; Menu item for "File" menu
Open db "Open", 0 ; Menu item for "Open" menu
Save db "Save", 0 ; Menu item for "Save" menu
SaveAs db "Save As", 0 ; Menu item for "Save As" menu
Exit db "Exit", 0 ; Menu item for "Exit" menu
fileIsOpen dd 0   ; 0 = No file open, 1 = File open

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
hInstance HINSTANCE ?
m_hWnd HWND ?
hMenu HMENU ?
hEdit HWND ?

hFileMenu HMENU ?
hOpenMenu HMENU ?
hSaveMenu HMENU ?
hSaveAsMenu HMENU ?
hExitMenu HMENU ?
hStatusBar HWND ?

hFont HANDLE ?
msg MSG <>
m_uMsg dd ?
wc WNDCLASSEX <>

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

    invoke CreatePopupMenu
    mov hFileMenu, eax

    invoke CreatePopupMenu
    mov hOpenMenu, eax

    invoke CreatePopupMenu
    mov hSaveMenu, eax

    invoke CreatePopupMenu
    mov hSaveAsMenu, eax

    invoke CreatePopupMenu
    mov hExitMenu, eax

    invoke AppendMenu, hFileMenu, MF_STRING, 1010, addr Open
    invoke AppendMenu, hFileMenu, MF_SEPARATOR, 0, NULL
    invoke AppendMenu, hFileMenu, MF_STRING, 1030, addr Save
    invoke AppendMenu, hFileMenu, MF_STRING, 1031, addr SaveAs
    invoke AppendMenu, hFileMenu, MF_SEPARATOR, 0, NULL
    invoke AppendMenu, hFileMenu, MF_STRING, 1001, addr Exit
    invoke AppendMenu, hMenu, MF_POPUP, hFileMenu, addr File

    invoke RegisterClassEx, ADDR wc
    invoke CreateWindowEx, 0, ADDR ClassName, ADDR AppName, WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT, 400, 300, NULL, hMenu, hInstance, NULL
    mov m_hWnd, eax
    invoke UpdateMenuItems, m_hWnd
    invoke ShowWindow, m_hWnd, SW_SHOWNORMAL
    invoke UpdateWindow, m_hWnd

    ; Message loop
    .WHILE TRUE
        invoke GetMessage, ADDR msg, NULL, 0, 0 ; Get the next message
        .BREAK .IF !eax                         ; Exit if WM_QUIT received
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
                        ; Handle the error

                        ; Get the error code
                        invoke GetLastError

                        ; Format the error message
                        invoke FormatMessage, FORMAT_MESSAGE_FROM_SYSTEM, NULL, eax, 0, ADDR buffer, SIZEOF buffer, NULL
                        
                        ; Display the error message
                        invoke MessageBox, hWnd, ADDR buffer, ADDR szErrorCaptionNoRead, MB_ICONERROR
                        
                        ; Free the buffer
                        invoke GlobalFree, lpFileBase
                    .ELSE
                        ; Set the text in the edit control
                        invoke SendMessage, hEdit, WM_SETTEXT, 0, lpFileBase

                        ; Free the buffer
                        invoke GlobalFree, lpFileBase
                    .ENDIF
                .ELSE
                    ; Handle the error

                    ; Get the error code
                    invoke GetLastError

                    ; Format the error message
                    invoke FormatMessage, FORMAT_MESSAGE_FROM_SYSTEM, NULL, eax, 0, ADDR buffer, SIZEOF buffer, NULL
                    
                    ; Display the error message
                    invoke MessageBox, hWnd, ADDR buffer, ADDR szErrorCaptionNoOpen, MB_ICONERROR

                    ret
                .ENDIF
            .ELSE
                ; Handle the error

                ; Get the error code
                invoke GetLastError

                ; Format the error message
                invoke FormatMessage, FORMAT_MESSAGE_FROM_SYSTEM, NULL, eax, 0, ADDR buffer, SIZEOF buffer, NULL
                
                ; Display the error message
                invoke MessageBox, hWnd, ADDR buffer, ADDR szErrorCaptionNoOpen, MB_ICONERROR

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

                ; Get the error code
                invoke GetLastError

                ; Format the error message
                invoke FormatMessage, FORMAT_MESSAGE_FROM_SYSTEM, NULL, eax, 0, ADDR buffer, SIZEOF buffer, NULL
                
                ; Display the error message
                invoke MessageBox, hWnd, ADDR buffer, ADDR szErrorCaptionNoOpen, MB_ICONERROR

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
        ; Handle the error

        ; Get the error code
        invoke GetLastError
        
        ; Format the error message
        invoke FormatMessage, FORMAT_MESSAGE_FROM_SYSTEM, NULL, eax, 0, ADDR buffer, SIZEOF buffer, NULL
        
        ; Display the error message
        invoke MessageBox, hWnd, ADDR buffer, ADDR szErrorCaptionNoMemory, MB_ICONERROR

        ret
    .ENDIF

    ; Get the text from the edit control.
    invoke SendMessage, hEdit, WM_GETTEXT, fileSize + 1, lpFileBase

    ; Check if the text was retrieved.
    .IF eax == 0
        ; Handle the error

        ; Get the error code
        invoke GetLastError

        ; Format the error message
        invoke FormatMessage, FORMAT_MESSAGE_FROM_SYSTEM, NULL, eax, 0, ADDR buffer, SIZEOF buffer, NULL

        ; Display the error message
        invoke MessageBox, hWnd, ADDR buffer, ADDR szErrorCaptionNoText, MB_ICONERROR

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
            ; Handle the error

            ; Get the error code
            invoke GetLastError

            ; Format the error message
            invoke FormatMessage, FORMAT_MESSAGE_FROM_SYSTEM, NULL, eax, 0, ADDR buffer, SIZEOF buffer, NULL
        
            ; Display the error message
            invoke MessageBox, hWnd, ADDR buffer, ADDR szErrorCaptionNoWrite, MB_ICONERROR

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
CloseFile proc
    .IF hFile != NULL
        invoke CloseHandle, hFile
        mov hFile, NULL
    .ENDIF
    ret
CloseFile endp

; Window procedure
WndProc proc hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
    .IF uMsg == WM_COMMAND
        mov eax, wParam
        shr eax, 16 ; Move the high-order word to the low-order word
        .IF ax == 0 ; The message is from a menu
            mov eax, wParam
            .IF ax == 1000 ; "File" menu item
                ; Do nothing

            .ELSEIF ax == 1001 ; "Exit" menu item
                ; Exit the application
                invoke CloseFile

                ; Close the window
                invoke PostQuitMessage, 0
            .ELSEIF ax == 1010  ; Open
                ; Open a file
                invoke DoOpenFile, hWnd

            .ELSEIF ax == 1030  ; Save
                ; Save the file
                invoke DoSaveFile, hWnd, FALSE

            .ELSEIF ax == 1031  ; Save As
                ; Save the file as a new file
                invoke DoSaveFile, hWnd, TRUE

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
        mov eax,lParam
        and eax, 0FFFFh ; LOWORD(l_lParam)
        mov ecx, lParam
        shr ecx, 16 ; HIWORD(l_lParam)
        sub ecx, statusBarHeight ; Subtract the height of the status bar
        invoke MoveWindow, hEdit, 0, 0, eax, ecx, TRUE

    .ELSEIF uMsg == WM_DESTROY
        invoke CloseFile
        invoke PostQuitMessage, 0

    .ELSE
        invoke DefWindowProc, hWnd, uMsg, wParam, lParam

    .ENDIF
    ret
WndProc endp

end start
