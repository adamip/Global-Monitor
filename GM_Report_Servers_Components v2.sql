USE [ksubscribers];
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO
/*
CREATE PROCEDURE [dbo].[GM_Report_Servers_Components]
	@Parm_Components NVARCHAR(20) = NULL,
	@Parm_On_Day NVARCHAR(20) = NULL
AS */

/* Debugging use	 */
DECLARE @Parm_Components NVARCHAR(20);
DECLARE @Parm_On_Day NVARCHAR(20);  
SET @Parm_Components = ' ';
SET @Parm_On_Day = '2013-02-17';  

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
/*
CREATE TABLE tmpCPU /* DECLARE @tmpCPU TABLE */ ( [AgentGUID] Numeric(26,0) NOT NULL
 , [TheDate] Datetime NOT NULL
 , [Hour] INT NOT NULL
 , [Sum] FLOAT(53) NOT NULL
 , [DataPoints] INT NOT NULL
 , [RecCreatedOn] Datetime NOT NULL );
CREATE TABLE tmpMem /* DECLARE @tmpMem TABLE */ ( [AgentGUID] Numeric(26,0) NOT NULL
 , [TheDate] Datetime NOT NULL
 , [Hour] INT NOT NULL
 , [Sum] FLOAT(53) NOT NULL
 , [DataPoints] INT NOT NULL
 , [RecCreatedOn] Datetime NOT NULL );		*/
 
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

SET @ONDATE = 0;
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
		IF @Parm_On_Day > 10000
			BEGIN
			SET @Parm_On_Day = 1;
			END
		SET @ONDATE = CONVERT( VARCHAR, DATEADD( DAY, -1 * @Parm_On_Day, GETDATE()), 112 ); 
		END
	END			
SET @TableName = 'monitorCounterLog' + @ONDATE;

SET @Ret = 0;
SET @dDATE = CONVERT( DATETIME, @ONDATE );
SET @ONDATE = CONVERT( VARCHAR, @dDATE );
SET @SqlFrom = 'FROM  [monitorCounter] AS C, [' + @TableName  + '] AS L ';
SET @SqlGroup = 'GROUP BY L.agentGuid ';
SET @SqlOrder = 'ORDER BY L.agentGuid;';

SET @i = 0;
WHILE @i < 24
	BEGIN
	SET @SqlSelect = 'SELECT L.[agentGuid], ''' + CONVERT( VARCHAR, DATEADD( HOUR, @i, @dDATE )) + ''' AS [TheDate], ' + CONVERT( VARCHAR, @i) + ' AS [Hour], SUM(L.counterValue) AS [Sum], COUNT( * ) AS [DataPoints], GetDate() AS [RecCreatedOn] ';
	IF @CPU = 1
		BEGIN
		SET @SqlInsert1 = 'INSERT INTO tmpCPU ';
		SET @SqlWhere1 = 'WHERE L.monitorCounterId = C.monitorCounterId AND L.counterValue >= 0 AND ( C.[NAME] LIKE ''%[%]%Process%'' OR C.[NAME] LIKE ''%Process%[%]%Time'' ) ';
		SET @SqlWhere1 = @SqlWhere1 + 'AND L.eventDateTime BETWEEN ''' + CONVERT( VARCHAR, DATEADD( HOUR, @i, @dDATE )) + ''' ';
		SET @SqlWhere1 = @SqlWhere1 + 'AND ''' + CONVERT( VARCHAR, DATEADD( HOUR, @i + 1, @dDATE )) + ''' ';
		SET @SqlCommand1 = @SqlInsert1 + @SqlSelect + @SqlFrom + @SqlWhere1 + @SqlGroup + @SqlOrder;
		EXEC( @SqlCommand1 );
		/* deubgging */ --SELECT @i AS [I], @CPU AS [CPU], @MEM AS [MEM], @ONDATE AS [DATE], @dDate, @TableName AS TableName, @SqlCommand1 AS SQL1;
		END
	IF @MEM = 1
		BEGIN
		SET @SqlInsert2 = 'INSERT INTO tmpMem ';
		SET @SqlWhere2 = 'WHERE L.monitorCounterId = C.monitorCounterId AND L.counterValue > 0 AND C.[NAME] LIKE ''% bytes in use%'' ';
		SET @SqlWhere2 = @SqlWhere2 + 'AND L.eventDateTime BETWEEN ''' + CONVERT( VARCHAR, DATEADD( HOUR, @i, @dDATE )) + ''' ';
		SET @SqlWhere2 = @SqlWhere2 + 'AND ''' + CONVERT( VARCHAR, DATEADD( HOUR, @i + 1, @dDATE )) + ''' ';
		SET @SqlCommand2 = @SqlInsert2 + @SqlSelect + @SqlFrom + @SqlWhere2 + @SqlGroup + @SqlOrder;
		EXEC( @SqlCommand2 ); 
		/* deubgging */ --SELECT @i AS [I], @CPU AS [CPU], @MEM AS [MEM], @ONDATE AS [DATE], @dDate, @TableName AS TableName, @SqlCommand2 AS SQL2;
		END	
	SET @i = @i + 1;
	END

IF @CPU = 1
	BEGIN
	INSERT INTO [GMPORTAL\SQLEXPRESS].[GMReports].[dbo].[CPU] 
		SELECT [source].[AgentGUID]
		 , [source].[TheDate]
		 , [source].[Hour]
		 , [source].[Sum] 
		 , [source].[DataPoints] 
		 , [source].[RecCreatedOn]  
	FROM tmpCPU AS [source], [GMPORTAL\SQLEXPRESS].[GMReports].[dbo].[CPU] AS [target]
		WHERE [source].[AgentGUID] <> [target].[AgentGUID]
			AND [source].[TheDate] <> [target].[TheDate]
			AND [source].[Hour] <> [target].[Hour]
			AND [source].[Sum] <> [target].[Sum]
			AND [source].[DataPoints] <> [target].[DataPoints]
			AND [source].[RecCreatedOn] <> [target].[RecCreatedOn];
	END
IF @Mem = 1
	BEGIN
	INSERT INTO [GMPORTAL\SQLEXPRESS].[GMReports].[dbo].[Memory] 
		SELECT [source].[AgentGUID]
		 , [source].[TheDate]
		 , [source].[Hour]
		 , [source].[Sum] 
		 , [source].[DataPoints] 
		 , [source].[RecCreatedOn]  
	FROM tmpMem AS [source], [GMPORTAL\SQLEXPRESS].[GMReports].[dbo].[Memory] AS [target]
		WHERE [source].[AgentGUID] <> [target].[AgentGUID]
			AND [source].[TheDate] <> [target].[TheDate]
			AND [source].[Hour] <> [target].[Hour]
			AND [source].[Sum] <> [target].[Sum]
			AND [source].[DataPoints] <> [target].[DataPoints]
			AND [source].[RecCreatedOn] <> [target].[RecCreatedOn];
	END	