USE [ksubscribers];
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO
/* ***********************************************************************************************************************
	Procedure GM_Report_Servers_Components																Adam Ip 2013-03-07

	Procedure GM_Report_Servers_Components fetch data from [monitorCounterLogyyyymmdd] and inserting the data onto
		either [GMPORTAL\SQLEXPRESS].[GMReports].[dbo].[CPU] or [GMPORTAL\SQLEXPRESS].[GMReports].[dbo].[MEM], or both.
	Stored Procedure GM_Report_Servers_Components takes three parameters, case-insensitive
		1. which components,
			As of this moment, only two components are handled by this stored procedure, i.e. CPU, and Memory.
		2. Day or a Date, and 
		3. End Date
		
	Parameter #1, i.e. Components.  If not provided, then the default action is processing all components, i.e. CPU and Memory.
		This parameter must have a pair of single quote brackets around it.	
	Parameter #2, i.e. Day or a Date.  If not provided, then the default value is 1, which implies yesterday's data. 
	    If a day in numeric form is provided, and not in a calendar date format, then the third parameter will be ignored.
		If an invalid date or invalid date format is provided, then the stored procedure will ignore this parameter and 
		proceed yesterday's data, i.e. default back to 1 	
	Parameter #3, End Date
	    If the second parameter is provided as a day in numeric format, then this parameter will be ignored.
		If the second parameter is provided as a calendar date but this third parameter is not provided, then proceed only the 
		    date on the second parameter.
		If the second parameter and third parameter are provided as calendar date, then Start Date and nd Date are hence defined. 
		If an invalid date or invalid date format is provided, then the stored procedure will ignore the this parameter and 
			proceed forward.

	Caution: There is a comma between parameters while providing more than one parameters.
	Caution: While specify a calendar date, please make sure that it is 12 characters long, i.e. in the format pattern of 
		'yyyy/mm/dd' or 'yyyy-mm-dd'.  A calendar date must be embedded in a pair of single quote brackets.  Calendar dates which  
		are not 12 characters long will be ignored.
				
	For examples, 
		EXEC GM_Report_Servers_Components;			--executes yesterday's data on all components
		EXEC GM_Report_Servers_Components 'ALL', 0;	--executes today's data on all components
		EXEC GM_Report_Servers_Components 'MEM', 0;	--executes today's data on Memory component
		EXEC GM_Report_Servers_Components 'MEM', 1;	--executes yesterday's data on Memory component	
		EXEC GM_Report_Servers_Components 'MEM', 1;	--executes yesterday's data on Memory component	
		EXEC GM_Report_Servers_Components 'CPU', 2;	--executes data of 2 days ago on CPU component	
		EXEC GM_Report_Servers_Components 'CPU', 7;	--executes data of a week ago on CPU component	
		EXEC GM_Report_Servers_Components 'ALL';    --executes yesterday's data on all components	
		EXEC GM_Report_Servers_Components 'ALL' 1;	--executes yesterday's data on all components
		EXEC GM_Report_Servers_Components 'ALL' 2;	--executes data of 2 days ago on all components
		EXEC GM_Report_Servers_Components 'CPU', '2013-01-05';		--executes January 5th 2013 data on CPU component
		EXEC GM_Report_Servers_Components 'MEM', '2013-01-05';		--executes January 5th 2013 data on Memory component	
		EXEC GM_Report_Servers_Components 'CPUMEM', '2013-01-05';	--executes January 5th 2013 data on CPU & Memory components	
		EXEC GM_Report_Servers_Components 'ALL', '2013-01-05' '2013-01-07';
			--executes data on all components from January 5th 2013	to January 7th 2013			
	
*/

ALTER PROCEDURE [dbo].[GM_Report_Servers_Components]
	@Parm_Components NVARCHAR(20) = NULL, 
	@Parm_FromDate NVARCHAR(20) = NULL,
	@Parm_ToDate NVARCHAR(20) = NULL	
AS 

/* Debugging use	
DECLARE @Parm_Components NVARCHAR(20);
DECLARE @Parm_FromDate NVARCHAR(20);  
DECLARE @Parm_ToDate NVARCHAR(20);  
SET @Parm_Components = ' ';
SET @Parm_FromDate = '2013-02-01';   
SET @Parm_ToDate = '';   */

DECLARE @HourSlot INT;
DECLARE @sFromDate VARCHAR(20);
DECLARE @iDateSlot INT;
DECLARE @iToDate INT;
DECLARE @iTEMP INT;
DECLARE @dDATE DATETIME;
DECLARE @CPU INT;
DECLARE @MEM INT;
DECLARE @sBuffer VARCHAR(1000);
DECLARE @TableName VARCHAR(50);
DECLARE @SqlInsert1 VARCHAR(30), @SqlInsert2 VARCHAR(30);
DECLARE @SqlSelect VARCHAR(250);
DECLARE @SqlFrom VARCHAR(100);
DECLARE @SqlWhere1 VARCHAR(400), @SqlWhere2 VARCHAR(400);
DECLARE @SqlGroup VARCHAR(30);
DECLARE @SqlOrder VARCHAR(30);
DECLARE @SqlCommand1 VARCHAR(1000);
DECLARE @SqlCommand2 VARCHAR(1000);
DECLARE @FloatPrecision FLOAT(53);

/* create a temporary table */
IF OBJECT_ID('tempdb..#tmpCPU') IS NOT NULL
	DROP TABLE [#tmpCPU]; 

CREATE TABLE [#tmpCPU] ( 
	[RecID] BIGINT IDENTITY
 , [AgentGUID] Numeric(26,0) NOT NULL
 , [TheDate] Datetime NOT NULL
 , [Hour] INT NOT NULL
 , [Sum] FLOAT(53) NOT NULL
 , [DataPoints] INT NOT NULL );
ALTER TABLE [#tmpCPU]
	ADD CONSTRAINT PK_CPU
	PRIMARY KEY( [RecID] ); 
	
/* create a temporary table */
IF OBJECT_ID('tempdb..#tmpMem') IS NOT NULL
	DROP TABLE [#tmpMem]; 

CREATE TABLE [#tmpMem] ( 
   [RecID] BIGINT IDENTITY
 , [AgentGUID] Numeric(26,0) NOT NULL
 , [TheDate] Datetime NOT NULL
 , [Hour] INT NOT NULL
 , [Sum] FLOAT(53) NOT NULL
 , [DataPoints] INT NOT NULL ); 
ALTER TABLE [#tmpMem]
	ADD CONSTRAINT PK_MEM
	PRIMARY KEY( [RecID] ); 		
	
/* Flags */
SET @CPU = 0;
SET @MEM = 0;
IF @Parm_Components LIKE '%ALL%'
	BEGIN
	SET @CPU = 1;
	SET @MEM = 1;
	END
IF @Parm_Components LIKE '%CPU%'
	SET @CPU = 1;	
IF @Parm_Components LIKE '%MEM%'
	SET @MEM = 1;
IF @CPU = 0 AND @MEM = 0	
	BEGIN
	SET @CPU = 1;
	SET @MEM = 1;
	END	

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
	SET @iToDate = @iDateSlot	

SET @SqlInsert1 = 'INSERT INTO #tmpCPU ';
SET @SqlInsert2 = 'INSERT INTO #tmpMem ';
SET @SqlGroup = 'GROUP BY L.agentGuid ';
SET @SqlOrder = 'ORDER BY L.agentGuid;';
	
WHILE @iDateSlot <= @iToDate
	BEGIN
	SET @TableName = 'monitorCounterLog' + CONVERT( VARCHAR, @iDateSlot );
	SET @SqlFrom = 'FROM [monitorCounter] AS C, [' + @TableName  + '] AS L ';

	IF EXISTS( SELECT * FROM sys.objects WHERE object_id = OBJECT_ID( @TableName ) AND TYPE in ( N'U' ))	/* if source table does not exist, then skip */
		BEGIN
		SET @dDATE = CONVERT( DATETIME, CONVERT( VARCHAR, @iDateSlot ));
		SET @HourSlot = 0;
		WHILE @HourSlot < 24
			BEGIN
			SET @SqlSelect = 'SELECT L.[agentGuid], ''' + CONVERT( VARCHAR, DATEADD( HOUR, @HourSlot, @dDATE )) + ''' AS [TheDate], ' + 
				CONVERT( VARCHAR, @HourSlot) + ' AS [Hour], SUM(L.counterValue) AS [Sum], COUNT( * ) AS [DataPoints] ';
			IF @CPU = 1
				BEGIN
				BEGIN TRANSACTION SQL1
				SET @SqlWhere1 = 'WHERE L.monitorCounterId = C.monitorCounterId AND L.counterValue >= 0 AND ( C.[NAME] LIKE ''%[%]%Process%'' OR C.[NAME] LIKE ''%Process%[%]%Time'' ) ';
				SET @SqlWhere1 = @SqlWhere1 + 'AND L.eventDateTime BETWEEN ''' + CONVERT( VARCHAR, DATEADD( HOUR, @HourSlot, @dDATE )) + ''' ';
				SET @SqlWhere1 = @SqlWhere1 + 'AND ''' + CONVERT( VARCHAR, DATEADD( HOUR, @HourSlot + 1, @dDATE )) + ''' ';
				SET @SqlCommand1 = @SqlInsert1 + @SqlSelect + @SqlFrom + @SqlWhere1 + @SqlGroup + @SqlOrder;
				PRINT 'Fetching record: ' + @SqlCommand1;	
				/* T-SQL does not allow table name as a variable or parameter, therefore must implement in EXEC( sql_string ) */
				EXEC( @SqlCommand1 );
				/* deubgging */ /* SELECT @HourSlot AS [Hour slot], @CPU AS [CPU], @MEM AS [MEM], @iDateSlot AS [DateSlot], 
					@iToDate AS [ToDate], @dDate AS [dDate], @TableName AS TableName, @SqlCommand1 AS SQL1; */
				COMMIT TRANSACTION SQL1	
				END
			IF @MEM = 1
				BEGIN
				BEGIN TRANSACTION SQL2
				SET @SqlWhere2 = 'WHERE L.monitorCounterId = C.monitorCounterId AND L.counterValue > 0 AND C.[NAME] LIKE ''% bytes in use%'' ';
				SET @SqlWhere2 = @SqlWhere2 + 'AND L.eventDateTime BETWEEN ''' + CONVERT( VARCHAR, DATEADD( HOUR, @HourSlot, @dDATE )) + ''' ';
				SET @SqlWhere2 = @SqlWhere2 + 'AND ''' + CONVERT( VARCHAR, DATEADD( HOUR, @HourSlot + 1, @dDATE )) + ''' ';
				SET @SqlCommand2 = @SqlInsert2 + @SqlSelect + @SqlFrom + @SqlWhere2 + @SqlGroup + @SqlOrder;
				PRINT 'Fetching record: ' + @SqlCommand2;	
				/* T-SQL does not allow table name as a variable or parameter, therefore must implement in EXEC( sql_string ) */
				EXEC( @SqlCommand2 ); 
				/* deubgging */  /* SELECT @HourSlot AS [Hour slot], @CPU AS [CPU], @MEM AS [MEM], @iDateSlot AS [DateSlot], 
					@iToDate AS [ToDate], @dDate AS [dDate], @TableName AS TableName, @SqlCommand2 AS SQL2; */
				COMMIT TRANSACTION SQL2
				END	
			SET @HourSlot = @HourSlot + 1;
			END

			DECLARE @curRecID BIGINT;	
			DECLARE @curAgentGUID Numeric(26,0);
			DECLARE @curTheDate Datetime;
			DECLARE @curHour INT;
			DECLARE @curSum FLOAT(53);
			DECLARE @curDataPoints INT;
			DECLARE @curRecCreatedOn Datetime;
			SET @FloatPrecision = 0.000001;

			/* T-SQL Merge command does not work on remote database server or View.  Hence we use Cursor here */ 	
			IF @CPU = 1
				BEGIN
				IF CURSOR_STATUS('global','CurCPU') >= -1	/* remove Cursor if already exists */
					 DEALLOCATE CurCPU;
				DECLARE CurCPU CURSOR FOR	/* SQL Cursor */
					SELECT RecID FROM [#tmpCPU] ORDER BY RecID;
				OPEN CurCPU;
				FETCH NEXT FROM CurCPU INTO @curRecID;
				WHILE @@FETCH_STATUS = 0
					BEGIN
					-- BEGIN DISTRIBUTED TRANSACTION INSERT1;
					SELECT @curAgentGUID = [AgentGUID], @curTheDate = [TheDate], @curHour = [Hour], @curSum = [Sum], @curDataPoints = [DataPoints]    
						FROM [#tmpCPU] 
						WHERE @curRecID = RecID; 
					/* Insertion.  Avoid record duplication */		
					IF NOT EXISTS ( SELECT * FROM [GMPORTAL\SQLEXPRESS].[GMReports].[dbo].[CPU]
						WHERE [agentGuid] = @curAgentGUID AND [TheDate] = @curTheDate AND [Hour] = @curHour 
							AND ABS( [Sum] - @curSum ) < @FloatPrecision AND [DataPoints] = @curDataPoints )
						BEGIN
						PRINT 'CPU: Inserting record [Date] ' + CONVERT( VARCHAR, @curTheDate ) + ', [Hour] ' + CONVERT( VARCHAR, @curHour ) + '[AgentGUID] ' + CONVERT( VARCHAR, @curAgentGUID );	
						INSERT INTO [GMPORTAL\SQLEXPRESS].[GMReports].[dbo].[CPU]( [AgentGUID], [TheDate], [Hour], [Sum], [DataPoints], [RecCreatedOn] ) 
							VALUES ( @curAgentGUID, @curTheDate, @curHour, @curSum, @curDataPoints, GETDATE()); 
						END	
					-- COMMIT TRANSACTION INSERT1;		
					FETCH NEXT FROM CurCPU INTO @curRecID;
					END
				CLOSE CurCPU;
				DEALLOCATE CurCPU;
				DELETE FROM #tmpCPU;
				END	
				
			IF @MEM = 1
				BEGIN
				IF CURSOR_STATUS('global','CurMEM') >= -1	/* remove Cursor if already exists */
					DEALLOCATE CurMEM;
				DECLARE CurMEM CURSOR FOR	/* SQL Cursor */
					SELECT RecID FROM [#tmpMEM] ORDER BY RecID;
				OPEN CurMEM;
				FETCH NEXT FROM CurMEM INTO @curRecID;
				WHILE @@FETCH_STATUS = 0
					BEGIN
					-- BEGIN DISTRIBUTED TRANSACTION INSERT2;
					SELECT @curAgentGUID = [AgentGUID], @curTheDate = [TheDate], @curHour = [Hour], @curSum = [Sum], @curDataPoints = [DataPoints]    
						FROM [#tmpMEM] 
						WHERE @curRecID = RecID; 
					/* Insertion.  Avoid record duplication */	
					IF NOT EXISTS ( SELECT * FROM [GMPORTAL\SQLEXPRESS].[GMReports].[dbo].[Memory]
						WHERE [agentGuid] = @curAgentGUID AND [TheDate] = @curTheDate AND [Hour] = @curHour 
							AND ABS([Sum] - @curSum) < @FloatPrecision AND [DataPoints] = @curDataPoints )
						BEGIN
						PRINT 'MEM: Inserting record [Date] ' + CONVERT( VARCHAR, @curTheDate ) + ', [Hour] ' + CONVERT( VARCHAR, @curHour ) + '[AgentGUID] ' + CONVERT( VARCHAR, @curAgentGUID );	
						INSERT INTO [GMPORTAL\SQLEXPRESS].[GMReports].[dbo].[Memory]( [AgentGUID], [TheDate], [Hour], [Sum], [DataPoints], [RecCreatedOn] ) 
							VALUES ( @curAgentGUID, @curTheDate, @curHour, @curSum, @curDataPoints, GETDATE()); 
						END	
					-- COMMIT TRANSACTION INSERT2;
					FETCH NEXT FROM CurMEM INTO @curRecID;
					END
				CLOSE CurMEM;
				DEALLOCATE CurMEM;
				DELETE FROM #tmpMEM;
				END 
		END	
	/* CONVERT STYLE = 112 means yyyymmdd */
	SET @iDateSlot = CONVERT( INT, CONVERT( VARCHAR(30), DATEADD( DAY, 1, CONVERT( DATETIME, CONVERT( VARCHAR(20), @iDateSlot ))), 112 ));
	END
		
IF OBJECT_ID('tempdb..#tmpCPU') IS NOT NULL
	DROP TABLE [#tmpCPU]; 
IF OBJECT_ID('tempdb..#tmpMem') IS NOT NULL
	DROP TABLE [#tmpMem];	
