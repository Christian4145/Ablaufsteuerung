------------------
--Anfang zwingenden Anfangsblock
SET	NOCOUNT	ON
;

SET	TRANSACtION	ISOLATION LEVEL READ UNCOMMITTED
;

DECLARE	
		@kontext	VARCHAR (MAX)		-- Angabe in welchem Skript der Fehler aufgetreten ist
,		@anzahl		BIGINT				-- Anzahl Datensätze
,		@sql_handle VARBINARY(64)
;

SET	@kontext	=	'Beispielprodukt Beispiel SQL-Skript Nr. 1'
;
SET	@sql_handle	=	(SELECT sql_handle FROM sys.dm_exec_requests WHERE session_id = @@SPID )
;

BEGIN	TRY

EXEC	dbo.up_dim_protokoll	@nr=			1, 
								@kontext=		@kontext, 
								@descr=			'*** Start'
;

EXEC	dbo.up_dim_protokoll	@nr=			2, 
								@typ=			'S', 
								@kontext=		@kontext, 
								@sql_handle=	@sql_handle
;
--Ende zwingenden Anfangsblock
------------------

--raiserror ('Hello', 10, 1)
;

select top 100 * from sys.messages
;

SET	@anzahl	=	ROWCOUNT_BIG();
EXEC	dbo.up_dim_protokoll	@nr=			3, 
								@kontext=		@kontext, 
								@anzahl=		@anzahl, 
								@descr=			'SQL Nr. 1 (messages)'
;

--------------
--Anfang zwingender Endeblock

EXEC	dbo.up_dim_protokoll	@nr=			4, 
								@typ=			'P', 
								@kontext=		@kontext, 
								@sql_handle=	@sql_handle
;

EXEC	dbo.up_dim_protokoll	@nr=			5, 
								@kontext=		@kontext, 
								@descr=			'*** Ende'
;

END	TRY

BEGIN CATCH
EXEC up_dim_protokoll	@nr			= 99
					,	@typ		= 'E'
					,	@kontext	= @kontext
					,	@descr		= '*** Catched : '
;

THROW 50000 , 'Abbruch durch CATCH', 13
END CATCH

--------------
--Ende zwingender Endeblock
