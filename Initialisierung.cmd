REM %1 Name des aufrufenden Scripts

@ECHO OFF
::SETLOCAL ENABLEEXTENSIONS

SET /A errno=0
SET /A ERROR_KEY1=1
SET /A ERROR_KEY2=2

REM ****************************************************************************************
REM Die beiden Parameter, die für den sqlcmd Aufruf nötig sind aus der Parameterdatei lesen
REM ****************************************************************************************
FOR /f "tokens=2 delims=;" %%a IN ( 'findstr /b /i /c:"SQLSERVER;" parameter.csv' ) DO SET "SQLSERVER=%%a" 
FOR /f "tokens=2 delims=;" %%a IN ( 'findstr /b /i /c:"DB_WORK;"   parameter.csv' ) DO SET   "DB_WORK=%%a" 

ECHO.
ECHO "Server: -%SQLSERVER%- DB: -%DB_WORK%-"
ECHO.

if not defined SQLSERVER ( echo Der Key: SQLSERVER wurde nicht gefunden! & echo. & pause & SET /A errno^|=%ERROR_KEY1% )
if not defined DB_WORK   ( echo Der Key: DB_WORK   wurde nicht gefunden! & echo. & pause & SET /A errno^|=%ERROR_KEY2% )

REM *************************************************
REM ISODATE im Format 2018-01-25_165818.697 erzeugen
REM *************************************************
FOR /f "tokens=2 delims==" %%a in ( 'wmic OS Get localdatetime /value' ) do set "Z=%%a"
SET ISODATE=%Z:~0,4%-%Z:~4,2%-%Z:~6,2%_%Z:~8,2%%Z:~10,2%%Z:~12,6%

REM ***********************************************************************************
REM Stelle sicher, dass die gewünschte Version der Client SDK (sqlcmd) verwendet wird:
REM ***********************************************************************************
SET "PATH=C:\Program Files (x86)\Microsoft SQL Server\Client SDK\ODBC\130\Tools\Binn\;%PATH%"

REM ***********************************************************************************
REM Tabelle tp_dim_parameter bewusst ohne Protokollierung droppen und neu leer anlegen
REM ***********************************************************************************
sqlcmd -r0 -m-1 -V11 -Q "DROP TABLE dbo.tp_dim_parameter" -S %SQLSERVER% -d %DB_WORK% > NUL 2> %ISODATE%.err
sqlcmd -r0 -m-1 -V11 -Q "CREATE TABLE dbo.tp_dim_parameter ( schluessel VARCHAR(80) NOT NULL, wert VARCHAR(80) NOT NULL )" -S %SQLSERVER% -d %DB_WORK% > NUL 2>> %ISODATE%.err

REM **************************************************
REM SQL Protokollierprozedur in die Datenbank bringen
REM **************************************************
CALL SQLCmd_plus.cmd -i up_dim_protokoll.sql

REM *******************************************
REM Parameterdatei in eine Tabelle importieren
REM *******************************************
(
bcp dbo.tp_dim_parameter IN parameter.csv -t ";" -r 0x0d0a -c -T -C 65001 -F 2 -S %SQLSERVER% -d %DB_WORK%
) >> %ISODATE%.out 2>> %ISODATE%.err
CALL SQLCmd_plus.cmd -F Bulk_Insert_Parametertabelle

EXIT /B %errno%