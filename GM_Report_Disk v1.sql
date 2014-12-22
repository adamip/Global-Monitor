USE [ksubscribers]
GO
/****** Object:  StoredProcedure [dbo].[GM_Report_Disk]    Script Date: 03/14/2013 12:06:12 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* ***********************************************************************************************************************
	Procedure GM_Report_Disk		      																Adam Ip 2013-03-08

	Procedure GM_Report_Disk fetch data from [monitorCounterLogyyyymmdd] and inserting the data onto
		[GMPORTAL\SQLEXPRESS].[GMReports].[dbo].[Disk].
	Stored Procedure GM_Report_Disk takes two parameters, case-insensitive
		1. Number of weeks backward, or a Start Date, and 
		2. End Date
		
	Parameter #1, i.e. Day or a Date.  If not provided, then the default value is 1, which implies last week's data. 
	    If a day in numeric form is provided, and not in a calendar date format, then the second parameter will be ignored.
		If an invalid date or invalid date format is provided, then the stored procedure will ignore this parameter and 
		proceed last week's data, i.e. default back to 1 	
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
		EXEC GM_Report_Disk;	--executes snapshot data with a last week's date stamp 
		EXEC GM_Report_Disk 0;	--executes snapshot data with a this week's date stamp 
		EXEC GM_Report_Disk 1;	--executes snapshot data with a last week's date stamp  
		EXEC GM_Report_Disk 2;	--executes snapshot data with a date stamp of 2 weeks ago 
		EXEC GM_Report_Disk 7;	--executes snapshot data with a date stamp of 7 weeks ago 
		EXEC GM_Report_Disk '2013-01-05';	--executes snapshot data with a date stamp of the week of January 5th 2013 
		EXEC GM_Report_Disk '2013-01-05' '2013-01-07';	
			--executes snaphost data with a date stamp of the week of January 5th 2013 to the week of January 7th 2013; data in week interval			
	
	The stored procedure calls two custom SQL functions, i.e. fn_Start_of_Week and fn_End_of_Week 
*/

ALTER PROCEDURE [dbo].[GM_Report_Disk]
	@Parm_FromDate NVARCHAR(20) = NULL,
	@Parm_ToDate NVARCHAR(20) = NULL	
AS 

DECLARE @sFromDate VARCHAR(20);
DECLARE @iDateSlot INT;
DECLARE @tDateSlot DATETIME;
DECLARE @tWeekSlotBegin DATETIME;
DECLARE @tWeekSlotEnd DATETIME;
DECLARE @iToDate INT;
DECLARE @iTEMP INT;
DECLARE @iYear INT;
DECLARE @iWeek INT;

DECLARE @SqlInsert VARCHAR(30);
DECLARE @SqlSelect1 VARCHAR(150), @SqlSelect2 VARCHAR(150), @SqlSelect3 VARCHAR(50);
DECLARE @SqlFrom1 VARCHAR(10);
DECLARE @SqlFrom21 VARCHAR(150), @SqlFrom22 VARCHAR(60), @SqlFrom23 VARCHAR(100), @SqlFrom24 VARCHAR(150), @SqlFrom25 VARCHAR(150), @SqlFrom26 VARCHAR(70);
DECLARE @SqlFrom3 VARCHAR(70);
DECLARE @SqlWhere1 VARCHAR(100), @SqlWhere2 VARCHAR(70), @SqlWhere3 VARCHAR(100);
DECLARE @SqlOrder VARCHAR(35);
DECLARE @SqlCommand VARCHAR(2000);

/* create a temporary table */
IF OBJECT_ID('tempdb..#tmpDisk') IS NOT NULL
	DROP TABLE [#tmpDisk]; 

CREATE TABLE [#tmpDisk] ( 
   [RecID] NUMERIC(26,0) IDENTITY
 , [AgentGUID] BIGINT NOT NULL
 , [DiskLabel] NVARCHAR( 100 ) NOT NULL 
 , [DriveName] NVARCHAR( 100 ) NOT NULL
 , [TotalSpaceGB] FLOAT(53)
 , [FreeSpaceGB] FLOAT(53)
 , [Stamp] Datetime NOT NULL
	);
 ALTER TABLE [#tmpDisk]
	ADD CONSTRAINT PK_Disk
	PRIMARY KEY( [RecID] ); 
	
SET @sFromDate = '';
SET @iToDate = 0;
IF @Parm_FromDate IS NULL
	BEGIN	/* default to be last week */
	SET @sFromDate = CONVERT( VARCHAR, DATEADD( DAY, -8, GETDATE()), 112 ); 
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
			SET @sFromDate = CONVERT( VARCHAR, DATEADD( WEEK, -1 * @Parm_FromDate, GETDATE()), 112 ); 
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

SET @SqlInsert = 'INSERT INTO #tmpDisk ';
SET @SqlSelect1 = 'SELECT [Disk].[agentGuid], LTRIM( RTRIM( [source].[DiskLabel] )) AS [DiskLabel], LTRIM( RTRIM( [source].[DriveName] )) AS DriveName, ';
SET @SqlSelect2 = ' CONVERT( FLOAT, [Disk].[totalMBytes] ) / 1024.0 AS [TotalSpaceGB], CONVERT( FLOAT, [Disk].[freeMBytes] ) / 1024.0 AS [FreeSpaceGB], ';
SET @SqlSelect3 = '[source].[LatestStamp] AS [Stamp] ';
SET @SqlFrom1 =  'FROM ( ';
SET @SqlFrom21 = 'SELECT [D].[agentGuid], D.[volumeName] AS [DiskLabel], D.[driveLetter] AS [DriveName], MAX( T.[DATE] ) AS [LatestStamp] ';
SET @SqlFrom22 = 'FROM auditRsltDisks AS [D], auditRsltDate AS [T] ';
SET @SqlFrom23 = 'WHERE D.[AGENTguid] = T.[AGENTguid] AND D.[resultGroup] = 1 AND T.[resultGroup] = 1 ';
SET @SqlFrom24 = 'AND ( D.[TYPE] = ''Fixed'' OR ( D.[TYPE] = ''Removable'' AND D.totalMBytes > 0 )) AND D.volumeName NOT LIKE ''%page file%'' '; 
SET @SqlFrom26 = 'GROUP BY [D].[agentGuid], D.[volumeName], D.[driveLetter] ';
SET @SqlFrom3 =  ') AS [source], auditRsltDisks AS [Disk], auditRsltDate AS RD ';
SET @SqlWhere1 = 'WHERE [source].agentGuid = [RD].agentGuid AND [source].agentGuid = [Disk].agentGuid ';
SET @SqlWhere2 = 'AND [Disk].locked = 1 AND [source].[LatestStamp] = [RD].[date] ';
SET @SqlWhere3 = 'AND [source].DiskLabel = [Disk].volumeName AND [source].DriveName = [Disk].driveLetter ';
SET @SqlOrder =  'ORDER BY [Stamp], [DriveName];';
	
WHILE @iDateSlot <= @iToDate
	BEGIN
	BEGIN TRANSACTION SQL1
	SET @tDateSlot = CONVERT( DATETIME, CONVERT( VARCHAR(50), @iDateSlot));
	SET @tWeekSlotBegin = [dbo].fn_Start_of_Week( @tDateSlot, 1 );
	SET @tWeekSlotEnd = [dbo].fn_End_of_Week( @tDateSlot, 1 );
	/* year number calculation and date number calculation are based on the 7th day in the week slot */
	SET @iYear = DATEPART( YEAR, @tWeekSlotEnd ); 
	SET @iWeek = DATEPART( WEEK, @tWeekSlotEnd ); 
	/* add 1 day to @tWeekSlotEnd to establish the upper bound of the week slot */
	SET @tWeekSlotEnd = DATEADD( DAY, 1, @tWeekSlotEnd );
	
	SET @SqlFrom25 = 'AND T.[date] >= ''' + CONVERT( VARCHAR(50), @tWeekSlotBegin ) + ''' AND T.[date] < ''' + CONVERT( VARCHAR(50), @tWeekSlotEnd ) + ''' '; 
	SET @SqlCommand = @SqlInsert + @SqlSelect1 + @SqlSelect2 + @SqlSelect3 + @SqlFrom1 + @SqlFrom21 + @SqlFrom22 + @SqlFrom23 + @SqlFrom24 + @SqlFrom25 + @SqlFrom26 + @SqlFrom3 + @SqlWhere1 + @SqlWhere2 + @SqlWhere3 + @SqlOrder;
	
	/* debug */ --SELECT @iToDate AS [@iToDate], @iDateSlot AS [@iDateSlot], @tWeekSlotBegin AS [@tWeekSlotBegin], @tWeekSlotEnd AS [@tWeekSlotEnd], @iYear AS [@iYear], @iWeek AS [@iWeek], @SqlCommand AS [@SqlCommand];
	PRINT 'Fetching record: ' + @SqlCommand ;
	EXEC( @SqlCommand );
	COMMIT TRANSACTION SQL1;
	DECLARE @curRecID BIGINT;
	DECLARE @curAgentGUID Numeric( 26,0 );	
	DECLARE @curDiskLabel NVARCHAR( 100 );
	DECLARE @curDriveName NVARCHAR( 100 );
	DECLARE @curTotalSpaceGB FLOAT( 53 );
	DECLARE @curFreeSpaceGB FLOAT( 53 );
	DECLARE @curStamp Datetime;

	/* T-SQL Merge command does not work on remote database server or View.  Hence we use Cursor here */ 	
	IF CURSOR_STATUS('global','Cur') >= -1	/* remove Cursor if already exists */
		 DEALLOCATE Cur;
	DECLARE Cur CURSOR FOR	/* SQL Cursor */
		SELECT RecID FROM [#tmpDisk] ORDER BY RecID;
	OPEN Cur;
	FETCH NEXT FROM Cur INTO @curRecID;
	
	
	WHILE @@FETCH_STATUS = 0
		BEGIN
		-- BEGIN DISTRIBUTED TRANSACTION INSERT1;
		SELECT @curAgentGUID = AgentGUID, @curDiskLabel = DiskLabel, @curDriveName = DriveName, @curTotalSpaceGB = TotalSpaceGB, @curFreeSpaceGB = FreeSpaceGB, @curStamp = Stamp
			FROM [#tmpDisk] 
			WHERE @curRecID = RecID; 
		/* Insertion.  Avoid record duplication */	
		IF NOT EXISTS ( SELECT * FROM [GMPORTAL\SQLEXPRESS].[GMReports].[dbo].[Disk]
			WHERE [agentGuid] = @curAgentGUID AND [YearNum] = @iYear AND [WeekNum] = @iWeek AND [DriveName] = @curDriveName AND [DiskLabel] = @curDiskLabel )
			BEGIN
			PRINT 'Inserting record: Agent GUID = ' + CONVERT( NVARCHAR(50), @curAgentGUID ) + ', Disk Label = ' + @curDiskLabel + ', Drive Letter = ' + @curDriveName + ', Total Space = ' + CONVERT( VARCHAR(10), @curTotalSpaceGB ) + 'GB, Free Space' + CONVERT( VARCHAR(10), @curFreeSpaceGB ) + 'GB, Time stamp = ' + CONVERT( VARCHAR(20), @curStamp ); 	 
			INSERT INTO [GMPORTAL\SQLEXPRESS].[GMReports].[dbo].[Disk]( 
				[AgentGUID], YearNum, WeekNum, DiskLabel, DriveName, TotalSpaceGB, FreeSpaceGB, Stamp, RecCreatedOn ) 
				VALUES ( @curAgentGUID, @iYear, @iWeek, @curDiskLabel, @curDriveName, @curTotalSpaceGB, @curFreeSpaceGB, @curStamp, GETDATE());
			END
		
		-- COMMIT TRANSACTION INSERT1;
		FETCH NEXT FROM Cur INTO @curRecID;
		END
	CLOSE Cur;
	DEALLOCATE Cur;
	DELETE FROM #tmpDisk;
		
	/*  Fetch a date = @iDateSlot plus 7 days 
	    CONVERT STYLE = 112 means yyyymmdd */
	SET @iDateSlot = CONVERT( INT, CONVERT( VARCHAR(30), DATEADD( WEEK, 1, CONVERT( DATETIME, CONVERT( VARCHAR(20), @iDateSlot ))), 112 ));
	END
		
IF OBJECT_ID('tempdb..#tmpDisk') IS NOT NULL
	DROP TABLE [#tmpDisk]; 
