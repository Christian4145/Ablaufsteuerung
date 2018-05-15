/***************************************************************************************************
$Rev:: 2592                                         $: Revision des letzten commit
$Author:: wolfa015                                  $:    Autor des letzten commit
$Date:: 2018-04-03 17:04:31 +0200 (Di, 03. Apr 2018#$:    Datum des letzten commit
****************************************************************************************************
Dieses Modul enthält SQL-Prozeduren zur Protokollierung.

Es ist eine Möglichkeit vorgesehen Aurufhierarchien von Prozeduren zu erkennen




***************************************************************************************************/

-- =======================================
-- Löschen der Prozeduren falls vorhanden
-- =======================================
IF OBJECT_ID ( 'dbo.up_dim_protokoll_InitCallStack', 'P' ) IS NOT NULL DROP PROCEDURE dbo.up_dim_protokoll_InitCallStack;
GO
IF OBJECT_ID ( 'dbo.up_dim_protokoll_PushCallStack', 'P' ) IS NOT NULL DROP PROCEDURE dbo.up_dim_protokoll_PushCallStack;
GO
IF OBJECT_ID ( 'dbo.up_dim_protokoll_PopCallStack' , 'P' ) IS NOT NULL DROP PROCEDURE dbo.up_dim_protokoll_PopCallStack;
GO
IF OBJECT_ID ( 'dbo.up_dim_protokoll_GetCallStack' , 'P' ) IS NOT NULL DROP PROCEDURE dbo.up_dim_protokoll_GetCallStack;
GO
-- =======================================
-- Anlegen der Prozeduren zum Erzeugen eines SP-CallStacks
-- =======================================
CREATE PROCEDURE dbo.up_dim_protokoll_InitCallStack
AS
SET CONTEXT_INFO 0x0;
GO
-- =======================================
-- Anlegen der Prozeduren zum Erzeugen eines SP-CallStacks
-- =======================================
CREATE PROCEDURE dbo.up_dim_protokoll_PushCallStack ( @PROCID INTEGER ) --, @b varbinary(128) output )
AS
DECLARE @b VARBINARY (128)
SET @b = CONVERT ( BINARY (4), @PROCID ) + ISNULL ( CONTEXT_INFO (), 0x0 );
SET CONTEXT_INFO @b;
GO
-- =======================================
CREATE PROCEDURE dbo.up_dim_protokoll_PopCallStack
AS
DECLARE @b VARBINARY (128)
SET @b = SUBSTRING ( ISNULL ( CONTEXT_INFO (), 0x0 ), 5, LEN ( CONTEXT_INFO () ) )
SET CONTEXT_INFO @b;
GO
-- =======================================
CREATE PROCEDURE dbo.up_dim_protokoll_GetCallStack ( @CallStack VARCHAR (MAX) OUTPUT )
AS
DECLARE @b VARBINARY (128)
SET @CallStack = '';
SET @b = CONTEXT_INFO ();
WHILE @b <> 0x0
	BEGIN
	SET @CallStack = OBJECT_NAME ( CONVERT ( INTEGER, SUBSTRING ( @b, 1, 4 ) ) ) + '/' + @CallStack
	SET @b = SUBSTRING ( @b, 5, LEN ( @b ) )
	END
GO
-- =======================================
-- Löschen der Prozedur falls vorhanden
-- =======================================
IF OBJECT_ID ( 'dbo.up_dim_protokoll', 'P' ) IS NOT NULL DROP PROCEDURE dbo.up_dim_protokoll;
GO
-- =======================================
-- Anlegen der Prozedur zum Protokollieren
-- =======================================
CREATE PROCEDURE dbo.up_dim_protokoll
	@lauf		VARCHAR (27)	= ''
,	@nr			SMALLINT		= 1			OUTPUT
,	@typ		CHAR    (1)		= 'M'
,	@kontext	NVARCHAR (MAX)	= ''
,	@anzahl		BIGINT			= 0
,	@descr		NVARCHAR (MAX)	= ''
,	@sql_handle VARBINARY(64)	= NULL
WITH EXECUTE AS CALLER
AS
DECLARE
	@CallStack	VARCHAR (MAX)
,	@WRK_TEXT	VARCHAR (MAX);

IF @typ = 'E'
	BEGIN
	-- ############################################################
	-- Für den Fall eines Fehlers die Fehlerinfo zwischenspeichern
	-- Das muss als erstes passieren, das sonst die Fehlerinfo verloren geht
	-- ############################################################
	SELECT
		SYSDATETIME()		AS ErrorTime
	,	ERROR_NUMBER()		AS ErrorNumber
	,	ERROR_SEVERITY()	AS ErrorSeverity
	,	ERROR_STATE()		AS ErrorState
	,	ERROR_PROCEDURE()	AS ErrorProcedure
	,	ERROR_LINE()		AS ErrorLine
	,	ERROR_MESSAGE()		AS ErrorMessage
	INTO #tmp_error

	-- SEVERITY bis 10 sind Warnungen
	-- SEVERITY ab 11 läuft hier rein
	-- SEVERITY ab 20 bricht ohne CATCH ab, wenn die Verbindung zur DB getrennt wurde
	SET @descr	= @descr
				+ '*** Error: '	+ ISNULL ( CAST   ( ( SELECT ErrorNumber	FROM #tmp_error ) AS VARCHAR ), '-' ) + ' '
								+ ISNULL ( CAST   ( ( SELECT ErrorMessage	FROM #tmp_error ) AS VARCHAR(MAX) ), '-' ) + ' '
				+ 'SEVERITY: '	+ ISNULL ( CAST   ( ( SELECT ErrorSeverity	FROM #tmp_error ) AS VARCHAR ), '-' ) + ' '
				+ 'STATE: '		+ ISNULL ( CAST   ( ( SELECT ErrorState		FROM #tmp_error ) AS VARCHAR ), '-' ) + ' '
				+ 'LINE: '		+ ISNULL ( CAST   ( ( SELECT ErrorLine		FROM #tmp_error ) AS VARCHAR ), '-' ) + ' '
				+ 'PROCEDURE: '	+ ISNULL ( CAST   ( ( SELECT ErrorProcedure	FROM #tmp_error ) AS VARCHAR ), '-' ) + ' '
				;

	EXECUTE up_dim_protokoll_GetCallStack @CallStack OUTPUT;
	SET @kontext = ISNULL ( @CallStack, '' ) + @kontext;

	END

-- ###################################################
-- @LAUF aus der Parametertabelle holen, wenn leer ''
-- @LAUF ist über einen gesamten Batchlauf gleich
-- Normalerweise steht hier die Startzeit drin
-- Format: 2018-03-01 17:47:50.5413865
-- ###################################################
IF @LAUF = ''
	BEGIN
	IF          ( SELECT wert FROM tp_dim_parameter WHERE schluessel = 'LAUF' ) IS NULL INSERT INTO tp_dim_parameter VALUES ( 'LAUF', SYSDATETIME() );
	SET @LAUF = ( SELECT wert FROM tp_dim_parameter WHERE schluessel = 'LAUF' );
	END;

-- #######################
-- UMGEBUNG VORBEREITEN
-- #######################

-- DROP TABLE dbo.tp_dim_protokoll 
IF OBJECT_ID ( 'dbo.tp_dim_protokoll', 'U' ) IS NULL 
	CREATE TABLE dbo.tp_dim_protokoll (
		lauf			VARCHAR (27)		NOT NULL,	-- Identifizierer des aktuellen Laufes
		stamp			DATETIME			NOT NULL,	-- Zeitstempel Protokollierungszeit
		nr				SMALLINT			NOT NULL,	-- Lfd Nr im Code, um die Position im Code zu identifizieren DATETIME damit sekundengenau
		typ				CHAR    (1)			NOT NULL,	-- Typ des Protokolleintrags
												-- I = Information
												-- W = Warnung
												-- F = Fehler
												-- M = Meldung
												-- S = SQLCode (kompletter sql_handle) 
												-- P = SQLCode (Performance Info) 
												-- L = SQLCode (Performance Info) des zuletzt ausgeführten Kommandos
												-- E = Error aus TRY CATCH
		kontext			NVARCHAR (MAX),					-- Tabelle Spalte Prozedur etc.
		anzahl			BIGINT,							-- Anzahl (der von einer Anweisung betroffenen Datensätze) @@ROWCOUNT
		cpu				BIGINT,
		descr			NVARCHAR (MAX)					-- beschreibender Text (SQL Code)
		)


-- Parameter prüfen (sollte eigentlich nie NULL sein)
IF @nr IS NULL SET @nr = 1;

--#########################
-- PROTOKOLLIERUNG STARTEN
--#########################

-- Protokolleintrag

IF @typ = 'S'
	BEGIN
	SELECT @descr = [text] FROM sys.dm_exec_sql_text ( @sql_handle );
	
	INSERT INTO dbo.tp_dim_protokoll	(  lauf, stamp            ,  nr,  typ,  kontext,  anzahl,  descr )
								VALUES	( @lauf, CURRENT_TIMESTAMP, @nr, @typ, @kontext, @anzahl, @descr );
	END
ELSE IF @typ = 'P' 
	BEGIN
	DECLARE cur_erstel CURSOR FOR 
	SELECT
	SUBSTRING (	b.text
			,	a.statement_start_offset / 2 + 1
			,	( CASE WHEN a.statement_end_offset = -1	THEN DATALENGTH ( b.text )
														ELSE a.statement_end_offset	END - a.statement_start_offset ) / 2 + 1
			  )										AS sql_text
	,	a.last_rows
	,	'R/W (lRead/pRead/lWrite): ('			 + CONVERT ( VARCHAR, a.last_logical_reads	  )					+ '/' + CONVERT ( VARCHAR, a.last_logical_writes ) + '/' + CONVERT ( VARCHAR, a.last_physical_reads ) + ') '
	+	'Threads (reserved/used): ('			 + CONVERT ( VARCHAR, a.last_reserved_threads )					+ '/' + CONVERT ( VARCHAR, a.last_used_threads	 ) + ') '
	+	'Time (execution/elapsed/worker/clr): (' + FORMAT ( a.last_execution_time, N'yyyy\.MM\.dd HH\:MM\:ss' )	+ '/' + CONVERT ( VARCHAR, a.last_elapsed_time	 ) + '/' + CONVERT ( VARCHAR, a.last_worker_time	) + '/' + CONVERT ( VARCHAR, a.last_clr_time ) + ') '
	+	'Grant kb (ideal/real/used): ('			 + CONVERT ( VARCHAR, a.last_ideal_grant_kb	  )					+ '/' + CONVERT ( VARCHAR, a.last_grant_kb		 ) + '/' + CONVERT ( VARCHAR, a.last_used_grant_kb	) + ') '
	+	'DOP ' + CONVERT ( VARCHAR, a.last_dop )	 AS info
	FROM			sys.dm_exec_query_stats					a
		CROSS APPLY	sys.dm_exec_sql_text ( @sql_handle )	b
	WHERE sql_handle = @sql_handle
	ORDER BY a.statement_start_offset
	;

	OPEN cur_erstel;

	FETCH NEXT FROM cur_erstel 
	INTO 
		@descr
	,	@anzahl
	,	@kontext
	;

	-- 2:32 Min
	WHILE @@FETCH_STATUS = 0
		BEGIN
		INSERT INTO dbo.tp_dim_protokoll	(  lauf, stamp            ,  nr,  typ,  kontext,  anzahl,  descr )
									VALUES	( @lauf, CURRENT_TIMESTAMP, @nr, @typ, @kontext, @anzahl, @descr );
		SET @NR += 1;
		FETCH NEXT FROM cur_erstel 
		INTO 
			@descr
		,	@anzahl
		,	@kontext
		;
		END 

	CLOSE cur_erstel;
	DEALLOCATE cur_erstel;
	END
ELSE IF @typ = 'L' -- Info zum zuletzt ausgeführten SQL-Befehl um SQL-Handle
	BEGIN
	DECLARE cur_erstel CURSOR FOR 
	SELECT
	SUBSTRING (	b.text
			,	a.statement_start_offset / 2 + 1
			,	( CASE WHEN a.statement_end_offset = -1	THEN DATALENGTH ( b.text )
														ELSE a.statement_end_offset	END - a.statement_start_offset ) / 2 + 1
			  )										AS sql_text
	,	a.last_rows
	,	'R/W (lRead/pRead/lWrite): ('			 + CONVERT ( VARCHAR, a.last_logical_reads	  )					+ '/' + CONVERT ( VARCHAR, a.last_logical_writes ) + '/' + CONVERT ( VARCHAR, a.last_physical_reads ) + ') '
	+	'Threads (reserved/used): ('			 + CONVERT ( VARCHAR, a.last_reserved_threads )					+ '/' + CONVERT ( VARCHAR, a.last_used_threads	 ) + ') '
	+	'Time (execution/elapsed/worker/clr): (' + FORMAT ( a.last_execution_time, N'yyyy\.MM\.dd HH\:MM\:ss' )	+ '/' + CONVERT ( VARCHAR, a.last_elapsed_time	 ) + '/' + CONVERT ( VARCHAR, a.last_worker_time	) + '/' + CONVERT ( VARCHAR, a.last_clr_time ) + ') '
	+	'Grant kb (ideal/real/used): ('			 + CONVERT ( VARCHAR, a.last_ideal_grant_kb	  )					+ '/' + CONVERT ( VARCHAR, a.last_grant_kb		 ) + '/' + CONVERT ( VARCHAR, a.last_used_grant_kb	) + ') '
	+	'DOP ' + CONVERT ( VARCHAR, a.last_dop )	 AS info
	FROM			sys.dm_exec_query_stats					a
		CROSS APPLY	sys.dm_exec_sql_text ( @sql_handle )	b
	WHERE sql_handle = @sql_handle
	ORDER BY a.statement_start_offset DESC
	;

	OPEN cur_erstel;

	FETCH NEXT FROM cur_erstel 
	INTO 
		@descr
	,	@anzahl
	,	@kontext
	;

	INSERT INTO dbo.tp_dim_protokoll	(  lauf, stamp            ,  nr,  typ,  kontext,  anzahl,  descr )
								VALUES	( @lauf, CURRENT_TIMESTAMP, @nr, @typ, @kontext, @anzahl, @descr );

	CLOSE cur_erstel;
	DEALLOCATE cur_erstel;
	END
ELSE -- Normale Protokollierung
	BEGIN
	INSERT INTO dbo.tp_dim_protokoll	(  lauf, stamp            ,  nr,  typ,  kontext,  anzahl,  descr )
								VALUES	( @lauf, CURRENT_TIMESTAMP, @nr, @typ, @kontext, @anzahl, @descr );
	END

-- Erhöhung von @nr (nur benutzt wenn @Iterator eingesetzt wird)
SET @nr = @nr + 1;

GO
-- =======================================
-- Protokoll Wrapper(Adapter) für up_log2
-- Später entfernen, wenn alles umgestellt
-- =======================================
IF OBJECT_ID ( 'dbo.up_log2', 'P' ) IS NOT NULL DROP PROCEDURE dbo.up_log2;
GO
CREATE PROCEDURE dbo.up_log2
	@lauf		VARCHAR (27)
,	@nr			SMALLINT		OUTPUT
,	@typ		CHAR    (1)
,	@kontext	VARCHAR (MAX)
,	@anzahl		BIGINT
,	@descr		VARCHAR (MAX)
WITH EXECUTE AS CALLER
AS

EXEC up_dim_protokoll	@lauf		= @lauf
					,	@nr			= @nr
					,	@typ		= @typ
					,	@kontext	= @kontext
					,	@anzahl		= @anzahl
					,	@descr		= @descr
;
GO
IF OBJECT_ID ( 'dbo.up_log2_InitCallStack', 'P' ) IS NOT NULL DROP PROCEDURE dbo.up_log2_InitCallStack;
GO
IF OBJECT_ID ( 'dbo.up_log2_PushCallStack', 'P' ) IS NOT NULL DROP PROCEDURE dbo.up_log2_PushCallStack;
GO
IF OBJECT_ID ( 'dbo.up_log2_PopCallStack' , 'P' ) IS NOT NULL DROP PROCEDURE dbo.up_log2_PopCallStack;
GO
IF OBJECT_ID ( 'dbo.up_log2_GetCallStack' , 'P' ) IS NOT NULL DROP PROCEDURE dbo.up_log2_GetCallStack;
GO
CREATE PROCEDURE dbo.up_log2_InitCallStack
AS
EXEC up_dim_protokoll_InitCallStack;
GO
CREATE PROCEDURE dbo.up_log2_PushCallStack ( @PROCID INTEGER )
AS
EXEC up_dim_protokoll_PushCallStack @PROCID;
GO
CREATE PROCEDURE dbo.up_log2_PopCallStack
AS
EXEC up_dim_protokoll_PopCallStack;
GO
CREATE PROCEDURE dbo.up_log2_GetCallStack ( @CallStack VARCHAR (MAX) OUTPUT )
AS
EXEC up_dim_protokoll_GetCallStack @CallStack OUTPUT;
GO
-- =======================================
-- =======================================

/* Zum Testen
DECLARE 
		@LAUF			VARCHAR (27)				-- Laufzeit für Protokollierung
,		@Iterator		SMALLINT					-- Zählvariabel für Protokollierungsnummer
,		@Version		VARCHAR (40)				-- Version für Protkollierung
,		@Anzahl			BIGINT						--
,		@LogText		VARCHAR	 (MAX)				-- Text für Protokollierung

SET @LAUF		= SYSDATETIME();
SET @Iterator	= 1
SET @Version	= 'TESTAUFRUF';
SET @Anzahl		= 0
SET @Logtext	= 'Aufruf Nr:' 

EXECUTE dbo.up_dim_protokoll @LAUF, @Iterator OUTPUT, 'M', @Version, @@ROWCOUNT, @LogText;
EXECUTE dbo.up_dim_protokoll @LAUF, @Iterator OUTPUT, 'M', @Version, @@ROWCOUNT, @LogText;
EXECUTE dbo.up_dim_protokoll @LAUF, @Iterator OUTPUT, 'M', @Version, @@ROWCOUNT, @LogText;
EXECUTE dbo.up_dim_protokoll @LAUF, @Iterator OUTPUT, 'M', @Version, @@ROWCOUNT, @LogText;
EXECUTE dbo.up_dim_protokoll @LAUF, @Iterator OUTPUT, 'M', @Version, @@ROWCOUNT, @LogText;
EXECUTE dbo.up_dim_protokoll @LAUF, @Iterator OUTPUT, 'M', @Version, @@ROWCOUNT, @LogText;
PRINT @Iterator

EXECUTE dbo.up_dim_protokoll @LAUF, @Iterator OUTPUT, 'E', @Version, @@ROWCOUNT, @LogText;
PRINT @Iterator

BEGIN TRY
SET @Iterator = 1 / 0;
END TRY
BEGIN CATCH
EXECUTE dbo.up_dim_protokoll @LAUF, 999, 'E', @Version, 0, '*** Catched : ';
END CATCH


BEGIN TRY
RAISERROR (15600,-1,-1, 'mysp_CreateCustomer');
END TRY
BEGIN CATCH
EXECUTE dbo.up_dim_protokoll @LAUF, 999, 'E', @Version, 0, '*** Catched : ';
END CATCH




SELECT *
FROM tp_dim_protokoll
WHERE lauf = @LAUF
ORDER BY stamp 
;

*/