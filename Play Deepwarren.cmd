@echo off
title Deepwarren
rem Double-click this file. It runs the setup script for this window only; no system setting changes.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Play-Deepwarren.ps1"
echo.
if errorlevel 1 (
  echo Setup stopped. Read the message above, then double-click Play Deepwarren to try again.
) else (
  echo You can close this window. The game keeps running in the emulator.
)
pause
