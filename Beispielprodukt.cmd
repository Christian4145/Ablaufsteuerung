@echo off
CALL Initialisierung.cmd

CALL SQLCmd_plus.cmd -i "Beispielprodukt SQL-Skript Nr. 1.sql"

PowerShell.exe -ExecutionPolicy Bypass -File ProtokollExport.ps1 -SQLSERVER '%SQLSERVER%' -DB_WORK '%DB_WORK%'
pause
