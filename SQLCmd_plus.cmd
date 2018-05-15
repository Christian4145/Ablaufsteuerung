@ECHO OFF
::SETLOCAL ENABLEEXTENSIONS
SETLOCAL EnableDelayedExpansion

REM Parameter
REM %1   -i  SQL-Script ausführen
REM      -Q  SQL-Kommando ausführen
REM      -F  nur Fehlerbehandlung 
REM %2   bei -i SqlScript
REM      bei -Q das SQL-Kommando in ""
REM      bei -F Informativer Text der in "kontext" protokolliert wird

IF [%1]==[-i] GOTO :weiter
IF [%1]==[-Q] GOTO :weiter
IF [%1]==[-F] GOTO :nur_fehlerbehandlung

ECHO.
ECHO Fehlerhafter Aufruf
ECHO möglich:
ECHO CALL SQLCMD_plus.cmd -i  \<SQL-Script\>
ECHO CALL SQLCMD_plus.cmd -Q ^"\<SQL-Kommando\>^"
ECHO CALL SQLCMD_plus.cmd -F ^"\<Informativer Text\>^"
PAUSE
EXIT

:weiter
REM Rufe ein SQL-Skript auf und schreibe die normalen Ausgaben (stdout) in %ISODATE%.out (normalerweise nichts)
REM und die Fehler (stderr) in %ISODATE%.err (diese Datei wird immer angelegt, auch wenn kein Fehler kommt).

REM -r0: Redirects the error message output to the screen (stderr). only error messages that have a severity level of 11 or higher are redirected.
REM Also: Alles ab 11 kommt auf stderr
REM Kanal 2 ist stderr (Es wird aber anscheinend 0 (stdin?) genommen Christian fragen)

REM -m-1: Controls which error messages are sent to stdout. Messages that have a severity level greater than or equal to this level are sent. When this value is set to -1, all messages including informational messages, are sent.
REM Also: Alles ab Level 0 (bis inkl. 10), also auch einfache prints kommen auf stdout.
REM Kanal 1 ist stdout 

REM -V11: Error messages that have severity levels greater than or equal to this value set ERRORLEVEL. 

REM Start protokollieren
sqlcmd -r0 -m-1 -V11 -Q "exec up_dim_protokoll @nr = 1, @kontext = '%~1 %~2', @descr = '*** Start.'" -S %SQLSERVER% -d %DB_WORK% > NUL

ECHO %time%: Start %~2
ECHO.

sqlcmd -r0 -m-1 -V11 %1 %2 -S %SQLSERVER% -d %DB_WORK% > %ISODATE%.out 2> %ISODATE%.err

:nur_fehlerbehandlung
IF %ERRORLEVEL% NEQ 0 (

	REM Fehlerzweig: Schreibe die Fehlermeldung aus %ISODATE%.err im passenden Format in das Protokoll. Das Fehlerprotokoll wird nicht geloescht.
	REM ' in Fehlermeldung wird zu '' maskiert
	REM dummy.sql nötig, weil es irgendwie nicht direkt funktioniert hat
	(
	ECHO exec up_dim_protokoll @typ = 'F', @nr = 999, @kontext = '%~1 %~2', @descr = '*** Fehlerhaftes Ende.
	FOR %%R IN ("%ISODATE%.out") DO IF /i %%~zR NEQ 0 (
	ECHO StdOut:
	FOR /F "delims=" %%G IN ( %ISODATE%.out ) DO ( 
		SET AA=%%G
		SET BB=!AA:'=''!
		ECHO !BB!
		)
	)
	FOR %%R IN ("%ISODATE%.err") DO IF /i %%~zR NEQ 0 (
	ECHO StdErr:
	FOR /F "delims=" %%G IN ( %ISODATE%.err ) DO ( 
		SET AA=%%G
		SET BB=!AA:'=''!
		ECHO !BB!
		)
	)
	ECHO '
	) > dummy.sql 
	cat dummy.sql | sqlcmd -r0 -m-1 -V11 -S %SQLSERVER% -d %DB_WORK% > NUL 2> NUL
	
	REM Rot
	color cf
	ECHO Es liegt eine Fehlermeldungen vor! Programm wird abgebrochen.
	PowerShell.exe -ExecutionPolicy Bypass -File ProtokollExport.ps1 -SQLSERVER '%SQLSERVER%' -DB_WORK '%DB_WORK%'
	PAUSE
	EXIT

) ELSE (
  
	REM Gutzweig (Achtung DO IF nicht trennen DO ^ IF)
	FOR %%R IN ("%ISODATE%.err") DO IF /i %%~zR EQU 0 (
		REM IF

			REM Gruen
			color 2f
			
			REM Loesche leeres oder nicht vorhandenes Fehlerprotokoll
			DEL /F %ISODATE%.err
			
			(
			ECHO exec up_dim_protokoll @nr = 999, @kontext = '%~1 %~2', @descr = '--- Erfolgreiches Ende.
			FOR %%R IN ("%ISODATE%.out") DO IF /i %%~zR NEQ 0 (
			ECHO StdOut:
			FOR /F "delims=" %%G IN ( %ISODATE%.out ) DO (
				SET AA=%%G
				SET BB=!AA:'=''!
				ECHO !BB!
				)
			)
			ECHO '
			) > dummy.sql
			cat dummy.sql | sqlcmd -r0 -m-1 -V11 -S %SQLSERVER% -d %DB_WORK% > NUL 2> NUL

		) ELSE (

			REM Rot
			color cf
			ECHO Es liegen Eintraege im Fehlerprotokoll vor! Programm wird abgebrochen.

			(
			ECHO exec up_dim_protokoll @typ = 'F', @nr = 999, @kontext	= '%~1 %~2', @descr = '*** Fehlerhaftes Ende.
			FOR %%R IN ("%ISODATE%.out") DO IF /i %%~zR NEQ 0 (
			ECHO StdOut:
			FOR /F "delims=" %%G IN ( %ISODATE%.out ) DO (
				SET AA=%%G
				SET BB=!AA:'=''!
				ECHO !BB!
				)
			)
			ECHO StdErr:
			FOR /F "delims=" %%G IN ( %ISODATE%.err ) DO (
				SET AA=%%G
				SET BB=!AA:'=''!
				ECHO !BB!
				)
			ECHO '
			) > dummy.sql
			cat dummy.sql | sqlcmd -r0 -m-1 -V11 -S %SQLSERVER% -d %DB_WORK% > NUL 2> NUL
			

			PowerShell.exe -ExecutionPolicy Bypass -File ProtokollExport.ps1 -SQLSERVER '%SQLSERVER%' -DB_WORK '%DB_WORK%'
			PAUSE
			REM In diesm Fall auch ein harter Abbruch und nicht die Rueckkehr
			EXIT
		)
)

EXIT /b

REM ToDo evtl. die Protokollierung mit up_dim_protokoll als inScript-UP mit CALL