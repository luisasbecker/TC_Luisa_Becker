@echo off
chcp 65001 >nul
title Pipeline Bucal - acesso no celular
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\iniciar_pipeline_mobile.ps1"
if errorlevel 1 (
  echo.
  echo Nao foi possivel iniciar o Pipeline Bucal. Leia a mensagem acima.
  echo.
  pause
)
