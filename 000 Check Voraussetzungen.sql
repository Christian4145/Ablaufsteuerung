SET NOCOUNT ON;
SET	TRANSACTION	ISOLATION	LEVEL	READ	UNCOMMITTED;
--set statistics time on
--set statistics io on

/*
Überprüfe die Voraussetzungen, um die weiteren SQL-Skripte starten zu können:

1. Quelldatenbank ist vorhanden
2. Zieldatenbank ist leer

*/

DECLARE
	@db_dwh			SYSNAME			=	( SELECT wert FROM dbo.tp_dim_parameter WHERE schluessel = 'DB_DWH')
,	@sy_gebiet_ba	SYSNAME			=	( SELECT wert FROM dbo.tp_dim_parameter WHERE schluessel = 'sy_gebiet_ba')
,	@sy_betriebe	SYSNAME			=	( SELECT wert FROM dbo.tp_dim_parameter WHERE schluessel = 'sy_betriebe')
,	@sy_vdr			SYSNAME			=	( SELECT wert FROM dbo.tp_dim_parameter WHERE schluessel = 'sy_vdr')
,	@kontext 		VARCHAR (MAX) 	=	'000 Check Voraussetzungen'
,	@sql_handle 	VARBINARY (64) 	=	( SELECT sql_handle FROM sys.dm_exec_requests WHERE session_id = @@SPID )
,	@abbruch		TINYINT			=	0;

BEGIN	TRY

EXEC up_dim_protokoll	@nr			=	1
					,	@kontext	=	@kontext
					,	@descr		=	'*** Start';

EXEC up_dim_protokoll	@nr			=	2
					,	@typ		=	'S'
					,	@kontext	=	@kontext
					,	@sql_handle	=	@sql_handle;

---------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------------------------
--	überprüfe das Kriterium 1 "Quelldatenbank vorhanden" und breche das Skript (=weitere Überprüfungen) ab, 
--	wenn das Kriterium nicht erfüllt ist
---------------------------------------------------------------------------------------------------------------------

IF EXISTS
	( SELECT name FROM master.sys.databases WHERE name = @db_dwh)  --Kriterium 1
	EXEC up_dim_protokoll	@nr			=	3
						,	@kontext	=	@kontext
						,	@descr		=	'Kriterium 1 geprüft, Quelldatenbank ist vorhanden.';
ELSE
BEGIN
	EXEC up_dim_protokoll	@nr			=	4
						,	@kontext	=	@kontext
						,	@descr		=	'Kriterium 1 nicht erfüllt, Quelldatenbank nicht vorhanden.';
	SET	@abbruch	=	1;
END;
---------------------------------------------------------------------------------------------------------------------
--	überprüfe das Kriterium 2 "Gebietsstand existiert" und breche das Skript (=weitere Überprüfungen) ab, 
--	wenn das Kriterium nicht erfüllt ist
---------------------------------------------------------------------------------------------------------------------
DROP	SYNONYM	IF	EXISTS	dbo.sy_gebiet_ba;
EXECUTE('CREATE SYNONYM dbo.sy_gebiet_ba	FOR	' + @sy_gebiet_ba);

IF EXISTS
	( SELECT	TOP	1	* FROM dbo.sy_gebiet_ba)  --Kriterium 2
	EXEC up_dim_protokoll	@nr			=	5
						,	@kontext	=	@kontext
						,	@descr		=	'Kriterium 2 geprüft, Tabelle Gebietsstand ist vorhanden.';
ELSE
BEGIN
	EXEC up_dim_protokoll	@nr			=	6
						,	@kontext	=	@kontext
						,	@descr		=	'Kriterium 2 ist nicht erfüllt, Tabelle Gebietsstand ist nicht vorhanden.';
	SET	@abbruch	=	1;
END;
---------------------------------------------------------------------------------------------------------------------
--	überprüfe das Kriterium 3 "Betriebe Tabelle vorhanden" und breche das Skript (=weitere Überprüfungen) ab, 
--	wenn das Kriterium nicht erfüllt ist
---------------------------------------------------------------------------------------------------------------------
DROP	SYNONYM	IF	EXISTS	dbo.sy_betriebe;
EXECUTE('CREATE SYNONYM dbo.sy_betriebe	FOR	' + @sy_betriebe);

IF EXISTS
	( SELECT TOP	1	* FROM dbo.sy_betriebe)  --Kriterium 3
	EXEC up_dim_protokoll	@nr			=	7
						,	@kontext	=	@kontext
						,	@descr		=	'Kriterium 3 geprüft, Tabelle Betriebe ist vorhanden.';
ELSE
BEGIN
	EXEC up_dim_protokoll	@nr			=	8
						,	@kontext	=	@kontext
						,	@descr		=	'Kriterium 3 nicht erfüllt, Tabelle Betriebe ist nicht vorhanden.';
	SET	@abbruch	=	1;
END;
---------------------------------------------------------------------------------------------------------------------
--	überprüfe das Kriterium 4 "VDR Korrektur Tabelle" und breche das Skript (=weitere Überprüfungen) ab, 
--	wenn das Kriterium nicht erfüllt ist
---------------------------------------------------------------------------------------------------------------------
DROP	SYNONYM	IF	EXISTS	dbo.sy_vdr;
EXECUTE('CREATE SYNONYM dbo.sy_vdr	FOR	' + @sy_vdr);

IF EXISTS
	( SELECT TOP	1	* FROM dbo.sy_vdr)  --Kriterium 4
	EXEC up_dim_protokoll	@nr			=	9
						,	@kontext	=	@kontext
						,	@descr		=	'Kriterium 4 geprüft, Tabelle VDR Korrektur ist vorhanden.';
ELSE
BEGIN
	EXEC up_dim_protokoll	@nr			=	10
						,	@kontext	=	@kontext
						,	@descr		=	'Kriterium 4 nicht erfüllt, Tabelle VDR Korrektur ist nicht vorhanden.';
	SET	@abbruch	=	1;
END;

IF	@abbruch	=	1	
	RAISERROR ('Mindestens eine Voraussetzung ist nicht erfüllt.', -- Message text.
               13, -- Severity.
               1 -- State.
               );

---------------------------------------------------------------------------------------------------------------------
--alle Kriterien sind erfüllt (sonst wäre das Skript abgebrochen worden und nicht hierher gekommen)
---------------------------------------------------------------------------------------------------------------------
EXEC up_dim_protokoll	@nr			=	11
					,	@kontext	=	@kontext
					,	@descr		=	'Alle Kriterien sind erfüllt';
EXEC up_dim_protokoll	@nr			=	12
					,	@typ		=	'P'
					,	@kontext	=	@kontext
					,	@sql_handle	=	@sql_handle;

EXEC up_dim_protokoll	@nr			=	13
					,	@kontext	=	@kontext
					,	@descr		=	'*** Ende';
END	TRY

BEGIN CATCH
EXEC up_dim_protokoll	@nr			= 99
					,	@typ		= 'E'
					,	@kontext	= @kontext
					,	@descr		= '*** Catched : '
;
THROW 50000 , 'Abbruch durch CATCH', 13
END CATCH
