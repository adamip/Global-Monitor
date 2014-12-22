USE [ksubscribers];
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO
/* ***********************************************************************************************************************
	Procedure GM_Report_NTEvent		      																Adam Ip 2013-03-08

	Procedure GM_Report_NTEvent fetch data from [monitorCounterLogyyyymmdd] and inserting the data onto
		[GMPORTAL\SQLEXPRESS].[GMReports].[dbo].[NTEvent].
	Stored Procedure GM_Report_NTEvent takes two parameters, case-insensitive
		1. Day or a Date, and 
		2. End Date
		
	Parameter #1, i.e. Day or a Date.  If not provided, then the default value is 1, which implies yesterday's data. 
	    If a day in numeric form is provided, and not in a calendar date format, then the second parameter will be ignored.
		If an invalid date or invalid date format is provided, then the stored procedure will ignore this parameter and 
		proceed yesterday's data, i.e. default back to 1 	
	Parameter #2, End Date
	    If the first parameter is provided as a day in numeric format, then this parameter will be ignored.
		If the first parameter is provided as a calendar date but this second parameter is not provided, then proceed only the 
		    date on the first parameter.
		If the first parameter and second parameter are provided as calendar date, then Start Date and nd Date are hence defined. 
		If an invalid date or invalid date format is provided, then the stored procedure will ignore the this parameter and 
			proceed forward.

	Caution: There is a comma between parameters while providing more than one parameters.
	Caution: While specify a calendar date, please make sure that it is 12 characters long, i.e. in the format pattern of 
		'yyyy/mm/dd' or 'yyyy-mm-dd'.  A calendar date must be embedded in a pair of single quote brackets.  Calendar dates which  
		are not 12 characters long will be ignored.
				
	For examples, 
		EXEC GM_Report_NTEvent;		--executes yesterday's data 
		EXEC GM_Report_NTEvent 0;	--executes today's data 
		EXEC GM_Report_NTEvent 1;	--executes yesterday's data 
		EXEC GM_Report_NTEvent 2;	--executes data of 2 days ago 
		EXEC GM_Report_NTEvent 7;	--executes data of a week ago 	
		EXEC GM_Report_NTEvent '2013-01-05';		--executes January 5th 2013 data 
		EXEC GM_Report_NTEvent '2013-01-05' '2013-01-07';	--executes data from January 5th 2013	to January 7th 2013			
	
*/

ALTER PROCEDURE [dbo].[GM_Report_NTEvent]
	@Parm_FromDate NVARCHAR(20) = NULL,
	@Parm_ToDate NVARCHAR(20) = NULL	
AS 

DECLARE @sFromDate VARCHAR(20);
DECLARE @iDateSlot INT;
DECLARE @iToDate INT;
DECLARE @iTEMP INT;
DECLARE @TableName VARCHAR(50);

DECLARE @SqlInsert VARCHAR(30);
DECLARE @SqlSelect VARCHAR(80);
DECLARE @SqlFrom VARCHAR(50);
DECLARE @SqlWhere1 VARCHAR(300), @SqlWhere2 VARCHAR(300);
DECLARE @SqlGroup VARCHAR(10);
DECLARE @SqlOrder VARCHAR(30);
DECLARE @SqlCommand1 VARCHAR(1000), @SqlCommand2 VARCHAR(1000);;

/* create a temporary table */
IF OBJECT_ID('tempdb..#tmp') IS NOT NULL
	DROP TABLE [#tmp]; 

CREATE TABLE [#tmp] ( 
   [RecID] NUMERIC(26,0) IDENTITY
 , [AgentGUID] BIGINT NOT NULL
 , [EventTime] Datetime NOT NULL
 , [Message] NVARCHAR( 2000 ) NOT NULL );
ALTER TABLE [#tmp]
	ADD CONSTRAINT PK_Event
	PRIMARY KEY( [RecID] ); 
	
SET @sFromDate = '';
SET @iToDate = 0;
IF @Parm_FromDate IS NULL
	BEGIN
	SET @sFromDate = CONVERT( VARCHAR, DATEADD( DAY, -1, GETDATE()), 112 ); 
	END	
ELSE 
	BEGIN
	SET @Parm_FromDate = REPLACE( @Parm_FromDate, CHAR(92), CHAR(47));	/* SET @Parm_FromDate = REPLACE( @Parm_FromDate, '\', '/' ); */
	SET @Parm_FromDate = REPLACE( @Parm_FromDate, CHAR(47), CHAR(45) );	/* SET @Parm_FromDate = REPLACE( @Parm_FromDate, '/', '-' ); */
	SET @Parm_FromDate = REPLACE( @Parm_FromDate, CHAR(45), '' );			/* SET @Parm_FromDate = REPLACE( @Parm_FromDate, '-', '' );  */
	IF ISDATE( @Parm_FromDate ) = 1
		BEGIN
		SET @sFromDate = CONVERT( VARCHAR, @Parm_FromDate, 112 );
		IF ISDATE( @Parm_ToDate ) = 1
			BEGIN
			SET @Parm_ToDate = REPLACE( @Parm_ToDate, CHAR(92), CHAR(47));	/* SET @Parm_ToDate = REPLACE( @Parm_ToDate, '\', '/' ); */
			SET @Parm_ToDate = REPLACE( @Parm_ToDate, CHAR(47), CHAR(45) );	/* SET @Parm_ToDate = REPLACE( @Parm_ToDate, '/', '-' ); */
			SET @Parm_ToDate = REPLACE( @Parm_ToDate, CHAR(45), '' );			/* SET @Parm_ToDate = REPLACE( @Parm_ToDate, '-', '' );  */
			SET @iToDate = CONVERT( INT, CONVERT( VARCHAR, @Parm_ToDate, 112 ));	/* initialize End Date in numeric form */
			END
		END
	ELSE 
		BEGIN
		IF ISNUMERIC( @Parm_FromDate ) = 1
			BEGIN
			IF @Parm_FromDate > 10000	/* avoid large numeric input -- invalid number */
				SET @Parm_FromDate = 1;
			SET @sFromDate = CONVERT( VARCHAR, DATEADD( DAY, -1 * @Parm_FromDate, GETDATE()), 112 ); 
			END
		END			
	END
	
SET @iDateSlot = CONVERT( INT, @sFromDate );	/* initialize Start Date in numeric form */

IF ISDATE( @Parm_ToDate ) = 1
	BEGIN
	IF @iDateSlot > @iToDate AND @iToDate > 0
		BEGIN
		SET @iTEMP = @iDateSlot;
		SET @iDateSlot = @iToDate;
		SET @iToDate = @iTEMP;		
		END
	END
IF @iToDate = 0
	SET @iToDate = @iDateSlot;	

SET @SqlSelect = 'SELECT [agentGuid], [eventTime], LTrim( RTrim( [message] )) AS [message] ';
SET @SqlGroup = '';
SET @SqlOrder = 'ORDER BY [eventTime];';
	
WHILE @iDateSlot <= @iToDate
	BEGIN
	SET @TableName = 'ntEventLog' + CONVERT( VARCHAR, @iDateSlot );
	SET @SqlFrom = 'FROM [' + @TableName  + '] ';

	IF EXISTS( SELECT * FROM sys.objects WHERE object_id = OBJECT_ID( @TableName ) AND TYPE in ( N'U' ))	/* if source table does not exist, then skip */
		BEGIN
		BEGIN TRANSACTION SQL1
		SET @SqlInsert = 'INSERT INTO #tmp ';
		/* CONVERT Style 102 means dd-mm-yyyy */
		SET @SqlWhere1 = 'WHERE [eventTime] >= ''' + CONVERT( VARCHAR(50), CONVERT( DATETIME, CONVERT( VARCHAR(50), @iDateSlot ))) + ''' AND ';
		SET @SqlWhere2 = '[eventTime] < ''' + CONVERT( VARCHAR(50), DATEADD( DAY, 1, CONVERT( DATETIME, CONVERT( VARCHAR(50), @iDateSlot )))) + ''' ';
		SET @SqlCommand1 = @SqlInsert + @SqlSelect + @SqlFrom + @SqlWhere1 + @SqlWhere2 + @SqlGroup + @SqlOrder;
		/* T-SQL does not allow table name as a variable or parameter, therefore must implement in EXEC( sql_string ) */
		PRINT 'Fetching record: ' + @SqlCommand1;	
		EXEC( @SqlCommand1 ); 
		/* deubgging */ --SELECT @iDateSlot AS [DateSlot], @iToDate AS [ToDate], @TableName AS TableName, @SqlCommand AS SQL; 
		COMMIT TRANSACTION SQL1;

		DECLARE @curRecID BIGINT;	
		DECLARE @curAgentGUID Numeric( 26,0 );
		DECLARE @curEventTime Datetime;
		DECLARE @curMessage NVARCHAR( 2000 );

		/* T-SQL Merge command does not work on remote database server or View.  Hence we use Cursor here */ 	
		IF CURSOR_STATUS('global','Cur') >= -1	/* remove Cursor if already exists */
			 DEALLOCATE Cur;
		DECLARE Cur CURSOR FOR	/* SQL Cursor */
			SELECT RecID FROM [#tmp] ORDER BY RecID;
		OPEN Cur;
		FETCH NEXT FROM Cur INTO @curRecID;
		WHILE @@FETCH_STATUS = 0
			BEGIN
			-- BEGIN DISTRIBUTED TRANSACTION INSERT1;
			SELECT @curAgentGUID = [AgentGUID], @curEventTime = [EventTime], @curMessage = [Message]
				FROM [#tmp] 
				WHERE @curRecID = RecID; 
			/* Insertion.  Avoid record duplication */		
			IF NOT EXISTS ( SELECT * FROM [GMPORTAL\SQLEXPRESS].[GMReports].[dbo].[NTEvent]
				WHERE [agentGuid] = @curAgentGUID AND [EventTime] = @curEventTime AND [Message] = @curMessage )
				BEGIN
				SET @SqlCommand2 = 'INSERT INTO [GMPORTAL\SQLEXPRESS].[GMReports].[dbo].[NTEvent]( [AgentGUID], [EventTime], [Message], [RecCreatedOn] ) VALUES ( ' + CONVERT( NVARCHAR(26), @curAgentGUID ) + ', ''' + CONVERT( VARCHAR(50), @curEventTime ) + ''', ''' + @curMessage + ''', GETDATE());';
				PRINT 'Inserting record = ' + @SqlCommand2;
				EXEC( @SqlCommand2 );
				END
			-- COMMIT TRANSACTION INSERT1;		
			FETCH NEXT FROM Cur INTO @curRecID;
			END
		CLOSE Cur;
		DEALLOCATE Cur; 
		DELETE FROM #tmp;
		END 
	/* CONVERT STYLE = 112 means yyyymmdd */
	SET @iDateSlot = CONVERT( INT, CONVERT( VARCHAR(30), DATEADD( DAY, 1, CONVERT( DATETIME, CONVERT( VARCHAR(20), @iDateSlot ))), 112 ));
	END
		
IF OBJECT_ID('tempdb..#tmp') IS NOT NULL
	DROP TABLE [#tmp]; 