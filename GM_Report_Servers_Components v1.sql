USE [ksubscribers];
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO
/*
CREATE PROCEDURE [dbo].[GM_Report_Servers_Components]
	@Components NVARCHAR(20) = NULL,
	@On_Day NVARCHAR(20) = NULL
AS */

DECLARE @Components NVARCHAR(20);
DECLARE @On_Day NVARCHAR(20);
SET @Components = ' ';
SET @On_Day = '2013-02-17';


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
DECLARE @SqlCommand1 VARCHAR(1000);
DECLARE @SqlCommand2 VARCHAR(1000);
/*
CREATE TABLE tmpCPU /* DECLARE @tmpCPU TABLE */ ( [AgentGUID] Numeric(26,0) NOT NULL
 , [TheDate] Datetime NOT NULL
 , [Hour] INT NOT NULL
 , [Sum] INT NOT NULL
 , [DataPoints] INT NOT NULL
 , [RecCreatedOn] Datetime NOT NULL );
CREATE TABLE tmpMem /* DECLARE @tmpMem TABLE */ ( [AgentGUID] Numeric(26,0) NOT NULL
 , [TheDate] Datetime NOT NULL
 , [Hour] INT NOT NULL
 , [Sum] INT NOT NULL
 , [DataPoints] INT NOT NULL
 , [RecCreatedOn] Datetime NOT NULL );*/
 
SET @CPU = 0;
SET @MEM = 0;
IF @Components LIKE '%ALL%'
	BEGIN
	SET @CPU = 1;
	SET @MEM = 1;
	END
IF @Components LIKE '%CPU%'
	BEGIN
	SET @CPU = 1;	
	END
IF @Components LIKE '%MEM%'
	BEGIN
	SET @MEM = 1;
	END
IF @CPU = 0 AND @MEM = 0	
	BEGIN
	SET @CPU = 1;
	SET @MEM = 1;
	END	

SET @ONDATE = 0;
SET @On_Day = REPLACE( @On_Day, '\', '/' );
SET @On_Day = REPLACE( @On_Day, '/', '-' );
SET @On_Day = REPLACE( @On_Day, '-', '' );	
IF @On_Day IS NULL
	BEGIN
	SET @ONDATE = CONVERT( VARCHAR, DATEADD( DAY, -1, GETDATE()), 112 ); 
	END	
ELSE IF ISDATE( @On_day ) = 1
	BEGIN
	SET @ONDATE = CONVERT( VARCHAR, @On_day, 112 );
	END
ELSE 
	BEGIN
	IF ISNUMERIC( @On_day ) = 1
		BEGIN
		IF @On_day > 10000
			BEGIN
			SET @On_day = 1;
			END
		SET @ONDATE = CONVERT( VARCHAR, DATEADD( DAY, -1 * @On_day, GETDATE()), 112 ); 
		END
	END			
SET @TableName = 'monitorCounterLog' + @ONDATE;

SET @Ret = 0;
SET @dDATE = CONVERT( DATETIME, @ONDATE );
SET @ONDATE = CONVERT( VARCHAR, @dDATE );
SET @SqlInsert1 = 'INSERT INTO tmpCPU ';
SET @SqlInsert2 = 'INSERT INTO tmpMem ';
SET @SqlSelect = 'SELECT L.[agentGuid], ''' + @ONDATE + ''', 1, SUM(L.counterValue) AS [Sum], COUNT( * ) AS [DataPoints], GetDate() AS [RecCreatedOn] ';
SET @SqlFrom = 'FROM ' + @TableName  + ' AS L, [monitorCounter] AS C ';
SET @SqlWhere1 = 'WHERE L.monitorCounterId = C.monitorCounterId AND L.counterValue >= 0 AND ( C.[NAME] LIKE ''%[%]%Process%'' OR C.[NAME] LIKE ''%Process%[%]%Time'' ) ';
SET @SqlWhere2 = 'WHERE L.monitorCounterId = C.monitorCounterId AND L.counterValue > 0 AND ( C.[NAME] LIKE ''% bytes in use%'' ) ';
SET @SqlGroup = 'GROUP BY L.agentGuid ORDER BY L.agentGuid;';
SET @SqlCommand1 = @SqlInsert1 + @SqlSelect + @SqlFrom + @SqlWhere1 + @SqlGroup;
SET @SqlCommand2 = @SqlInsert2 + @SqlSelect + @SqlFrom + @SqlWhere2 + @SqlGroup;

SELECT @CPU AS [CPU], @MEM AS [MEM], @ONDATE AS [DATE], @dDate, @TableName AS TableName, @SqlCommand1, @SqlCommand2;
EXEC( @SqlCommand1 );











	

