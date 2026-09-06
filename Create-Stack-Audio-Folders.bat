@echo off
title Streamer.bot Stack Audio Folder Setup
echo ==========================================
echo     Creating Stack Audio Folders
echo ==========================================
echo.

mkdir "C:\streaming\audio\1" 2>nul
mkdir "C:\streaming\audio\2-9" 2>nul
mkdir "C:\streaming\audio\10-99" 2>nul
mkdir "C:\streaming\audio\100-999" 2>nul
mkdir "C:\streaming\audio\1000-plus" 2>nul

echo Created:
echo   C:\streaming\audio\1
echo   C:\streaming\audio\2-9
echo   C:\streaming\audio\10-99
echo   C:\streaming\audio\100-999
echo   C:\streaming\audio\1000-plus
echo.
echo Opening audio folder...
start "" "C:\streaming\audio"
echo.
echo Done.
pause
