USE [ksubscribers];
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO
/*************************************************************************************************************************
	Procedure GM_Report_Servers_Components																Adam Ip 2013-03-07

	Procedure GM_Report_Servers_Components fetch data from [monitorCounterLogyyyymmdd] and inserting the data onto
		either [GMPORTAL\SQLEXPRESS].[GMReports].[dbo].[CPU] or [GMPORTAL\SQLEXPRESS].[GMReports].[dbo].[MEM], or both.
	Stored Procedure GM_Report_Servers_Components takes two parameters, case-insensitive
		1. Day, and 
		2. which components
		As of this moment, only two components are handled by this stored procedure, i.e. CPU, and Memory.
		
	Parameter #1, i.e. Day.  If not provided, then the default value is 1, which implies yesterday's data.
		Precaution: While specify a calendar date on Parameter 1 please make sure that it is 10 characters long, i.e. in format 
		of yyyy/mm/dd or yyyy-mm-dd.  A calendar date must be embedded in a pair of single quote brackets.  If an invalid date 
		or invalid date format is provided, then the stored procedure will ignore the error and proceed yesterday's data, 
		i.e. default back to 1 	
	Parameter #2, i.e. Components.  If not provided, then the default action is processing all components, i.e. CPU and Memory.
		The second parameter can be with or withotu a pair of single quote brackets around it.	

	Precaution: There is a comma between parameters while providing more than one parameters
				
	For examples, 
		EXEC GM_Report_Servers_Components;			--executes yesterday's data on all componets
		EXEC GM_Report_Servers_Components 0;		--executes today's data on all componets
		EXEC GM_Report_Servers_Components 0 MEM;	--executes today's data on Memory componet
		EXEC GM_Report_Servers_Components 1, MEM;	--executes yesterday's data on Memory componet	
		EXEC GM_Report_Servers_Components 1, 'MEM';	--executes yesterday's data on Memory componet	
		EXEC GM_Report_Servers_Components 2, CPU;	--executes data of 2 days ago on CPU componet	
		EXEC GM_Report_Servers_Components 7, CPU;	--executes data of a week ago on CPU componet	
		EXEC GM_Report_Servers_Components 0 ALL;	--executes today's data on all componets	
		EXEC GM_Report_Servers_Components '2013-01-05', 'CPU';	--executes January 5th 2013 data on CPU componet
		EXEC GM_Report_Servers_Components '2013-01-05', MEM;	--executes January 5th 2013 data on Memory componet	
		EXEC GM_Report_Servers_Components '2013-01-05';			--executes January 5th 2013 data on all componets	
		EXEC GM_Report_Servers_Components 1;		--executes yesterday's data on all componets
		EXEC GM_Report_Servers_Components 2;		--executes data of 2 days ago on all componets
		
	
*/
ALTER PROCEDURE [dbo].[GM_Report_Servers_Components]
	@Parm_On_Day NVARCHAR(20) = NULL,
	@Parm_Components NVARCHAR(20) = NULL
AS 

/* Debugging use	
DECLARE @Parm_Components NVARCHAR(20);
DECLARE @Parm_On_Day NVARCHAR(20);  
SET @Parm_Components = ' ';
SET @Parm_On_Day = '2013-02-16';   */

DECLARE @i INT;
DECLARE @ONDATE VARCHAR(20);
DECLARE @dDATE DATETIME;
DECLARE @Ret INT;
DECLARE @CPU INT;
DECLARE @MEM INT;
DECLARE @TableName VARCHAR(100);
DECLARE @SqlInsert1 VARCHAR(100);
DECLARE @SqlInsert2 VARCHAR(100);
DECLARE @SqlSelect VARCHAR(200);
DECLARE @SqlFrom VARCHAR(100);
DECLARE @SqlWhere1 VARCHAR(300);
DECLARE @SqlWhere2 VARCHAR(300);
DECLARE @SqlGroup VARCHAR(100);
DECLARE @SqlOrder VARCHAR(100);
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

SET @ONDATE = '';
SET @Parm_On_Day = REPLACE( @Parm_On_Day, CHAR(92), CHAR(47));	/* SET @Parm_On_Day = REPLACE( @Parm_On_Day, '\', '/' ); */
SET @Parm_On_Day = REPLACE( @Parm_On_Day, CHAR(47), CHAR(45) );	/* SET @Parm_On_Day = REPLACE( @Parm_On_Day, '/', '-' ); */
SET @Parm_On_Day = REPLACE( @Parm_On_Day, CHAR(45), '' );			/* SET @Parm_On_Day = REPLACE( @Parm_On_Day, '-', '' );  */
IF @Parm_On_Day IS NULL
	BEGIN
	SET @ONDATE = CONVERT( VARCHAR, DATEADD( DAY, -1, GETDATE()), 112 ); 
	END	
ELSE IF ISDATE( @Parm_On_Day ) = 1
	BEGIN
	SET @ONDATE = CONVERT( VARCHAR, @Parm_On_Day, 112 );
	END
ELSE 
	BEGIN
	IF ISNUMERIC( @Parm_On_Day ) = 1
		BEGIN
		IF @Parm_On_Day > 10000	/* avoid large numeric input -- invalid number */
			SET @Parm_On_Day = 1;
		SET @ONDATE = CONVERT( VARCHAR, DATEADD( DAY, -1 * @Parm_On_Day, GETDATE()), 112 ); 
		END
	END			
	
SET @TableName = 'monitorCounterLog' + @ONDATE;

SET @dDATE = CONVERT( DATETIME, @ONDATE );
SET @ONDATE = CONVERT( VARCHAR, @dDATE );
SET @SqlFrom = 'FROM  [monitorCounter] AS C, [' + @TableName  + '] AS L ';
SET @SqlGroup = 'GROUP BY L.agentGuid ';
SET @SqlOrder = 'ORDER BY L.agentGuid;';

SET @i = 0;
WHILE @i < 24
	BEGIN
	SET @SqlSelect = 'SELECT L.[agentGuid], ''' + CONVERT( VARCHAR, DATEADD( HOUR, @i, @dDATE )) + ''' AS [TheDate], ' + CONVERT( VARCHAR, @i) + ' AS [Hour], SUM(L.counterValue) AS [Sum], COUNT( * ) AS [DataPoints]';
	IF @CPU = 1
		BEGIN
		SET @SqlInsert1 = 'INSERT INTO #tmpCPU ';
		SET @SqlWhere1 = 'WHERE L.monitorCounterId = C.monitorCounterId AND L.counterValue >= 0 AND ( C.[NAME] LIKE ''%[%]%Process%'' OR C.[NAME] LIKE ''%Process%[%]%Time'' ) ';
		SET @SqlWhere1 = @SqlWhere1 + 'AND L.eventDateTime BETWEEN ''' + CONVERT( VARCHAR, DATEADD( HOUR, @i, @dDATE )) + ''' ';
		SET @SqlWhere1 = @SqlWhere1 + 'AND ''' + CONVERT( VARCHAR, DATEADD( HOUR, @i + 1, @dDATE )) + ''' ';
		SET @SqlCommand1 = @SqlInsert1 + @SqlSelect + @SqlFrom + @SqlWhere1 + @SqlGroup + @SqlOrder;
		EXEC( @SqlCommand1 );
		/* deubgging */ --SELECT @i AS [I], @CPU AS [CPU], @MEM AS [MEM], @ONDATE AS [DATE], @dDate, @TableName AS TableName, @SqlCommand1 AS SQL1;
		END
	IF @MEM = 1
		BEGIN
		SET @SqlInsert2 = 'INSERT INTO #tmpMem ';
		SET @SqlWhere2 = 'WHERE L.monitorCounterId = C.monitorCounterId AND L.counterValue > 0 AND C.[NAME] LIKE ''% bytes in use%'' ';
		SET @SqlWhere2 = @SqlWhere2 + 'AND L.eventDateTime BETWEEN ''' + CONVERT( VARCHAR, DATEADD( HOUR, @i, @dDATE )) + ''' ';
		SET @SqlWhere2 = @SqlWhere2 + 'AND ''' + CONVERT( VARCHAR, DATEADD( HOUR, @i + 1, @dDATE )) + ''' ';
		SET @SqlCommand2 = @SqlInsert2 + @SqlSelect + @SqlFrom + @SqlWhere2 + @SqlGroup + @SqlOrder;
		EXEC( @SqlCommand2 ); 
		/* deubgging */ --SELECT @i AS [I], @CPU AS [CPU], @MEM AS [MEM], @ONDATE AS [DATE], @dDate, @TableName AS TableName, @SqlCommand2 AS SQL2;
		END	
	SET @i = @i + 1;
	END

DECLARE @curRecID BIGINT;	
DECLARE @curAgentGUID Numeric(26,0);
DECLARE @curTheDate Datetime;
DECLARE @curHour INT;
DECLARE @curSum FLOAT(53);
DECLARE @curDataPoints INT;
DECLARE @curRecCreatedOn Datetime;
SET @FloatPrecision = 0.000001;
SET @Ret = 0;

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
		SELECT @curAgentGUID = [AgentGUID], @curTheDate = [TheDate], @curHour = [Hour], @curSum = [Sum], @curDataPoints = [DataPoints]    
			FROM [#tmpCPU] 
			WHERE @curRecID = RecID; 
		/* Insertion.  Avoid record duplication */		
		IF NOT EXISTS ( SELECT * FROM [GMPORTAL\SQLEXPRESS].[GMReports].[dbo].[CPU]
			WHERE [agentGuid] = @curAgentGUID AND [TheDate] = @curTheDate AND [Hour] = @curHour 
				AND ABS( [Sum] - @curSum ) < @FloatPrecision AND [DataPoints] = @curDataPoints )
			BEGIN
			INSERT INTO [GMPORTAL\SQLEXPRESS].[GMReports].[dbo].[CPU]( [AgentGUID], [TheDate], [Hour], [Sum], [DataPoints], [RecCreatedOn] ) 
				VALUES ( @curAgentGUID, @curTheDate, @curHour, @curSum, @curDataPoints, GETDATE()); 
			SET @Ret = @Ret + 1;
			END
		FETCH NEXT FROM CurCPU INTO @curRecID;
		END
	CLOSE CurCPU;
	DEALLOCATE CurCPU;
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
		SELECT @curAgentGUID = [AgentGUID], @curTheDate = [TheDate], @curHour = [Hour], @curSum = [Sum], @curDataPoints = [DataPoints]    
			FROM [#tmpMEM] 
			WHERE @curRecID = RecID; 
		/* Insertion.  Avoid record duplication */	
		IF NOT EXISTS ( SELECT * FROM [GMPORTAL\SQLEXPRESS].[GMReports].[dbo].[Memory]
			WHERE [agentGuid] = @curAgentGUID AND [TheDate] = @curTheDate AND [Hour] = @curHour 
				AND ABS([Sum] - @curSum) < @FloatPrecision AND [DataPoints] = @curDataPoints )
			BEGIN
			INSERT INTO [GMPORTAL\SQLEXPRESS].[GMReports].[dbo].[Memory]( [AgentGUID], [TheDate], [Hour], [Sum], [DataPoints], [RecCreatedOn] ) 
				VALUES ( @curAgentGUID, @curTheDate, @curHour, @curSum, @curDataPoints, GETDATE()); 
			SET @Ret = @Ret + 1;
			END
		FETCH NEXT FROM CurMEM INTO @curRecID;
		END
	CLOSE CurMEM;
	DEALLOCATE CurMEM;
	END		

IF OBJECT_ID('tempdb..#tmpCPU') IS NOT NULL
	DROP TABLE [#tmpCPU]; 
IF OBJECT_ID('tempdb..#tmpMem') IS NOT NULL
	DROP TABLE [#tmpMem];	

/* Total number of records inserted */	
RETURN @Ret;	