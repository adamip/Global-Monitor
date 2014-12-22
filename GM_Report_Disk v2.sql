USE [ksubscribers]
GO
/****** Object:  StoredProcedure [dbo].[GM_Report_Disk]    Script Date: 03/14/2013 12:06:12 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* ***********************************************************************************************************************
	Procedure GM_Report_Disk		      																Adam Ip 2013-05-06

	Procedure GM_Report_Disk fetch data from [monitorCounterLogyyyymmdd] and inserting the data onto
		[GMPORTAL\SQLEXPRESS].[GMReports].[dbo].[Disk].
	Stored Procedure GM_Report_Disk takes no parameter
				
	For example, 
		EXEC GM_Report_Disk
		
	
*/

ALTER PROCEDURE [dbo].[GM_Report_Disk]
AS 

/* delete temporary tables, if previously exist */
BEGIN TRANSACTION SQL1;
IF OBJECT_ID('tempdb..#tmpDisk') IS NOT NULL
	DROP TABLE [#tmpDisk]; 
/* create temporary tables */
CREATE TABLE [#tmpDisk] ( 
   [RecID] NUMERIC(26,0) IDENTITY
 , [AgentGUID] BIGINT NOT NULL
 , [ResultGroup] INT
 , [Locked] INT
 , [DiskLabel] NVARCHAR( 100 ) NOT NULL 
 , [DriveName] NVARCHAR( 100 ) NOT NULL
 , [TotalSpaceGB] FLOAT(53)
 , [FreeSpaceGB] FLOAT(53)
 );
COMMIT TRANSACTION SQL1;

BEGIN TRANSACTION SQL2;
PRINT 'Creating temporary table #tmpDisk';
INSERT INTO #tmpDisk
	SELECT [AgentGuid]
	, [ResultGroup], [Locked]
	, LTRIM( RTRIM( [DriveLetter] )) AS [DiskLabel]
	, LTRIM( RTRIM( [VolumeName] )) AS DriveName
	, CONVERT( FLOAT, [totalMBytes] ) / 1024.0 AS [TotalSpaceGB]
	, CONVERT( FLOAT, [freeMBytes] ) / 1024.0 AS [FreeSpaceGB]
	FROM auditRsltDisks 
	WHERE  [totalMBytes] > 0.0 
		AND [TYPE] NOT LIKE '%CDROM%'
		AND volumeName NOT LIKE '%pagefile%' AND volumeName NOT LIKE '%page file%' AND volumeName NOT LIKE '%Swap%'
		ORDER BY [agentGuid];
COMMIT TRANSACTION SQL2;

/* delete temporary tables, if previously exist */
BEGIN TRANSACTION SQL3;
PRINT 'Creating temporary table #tmpDate';
IF OBJECT_ID('tempdb..#tmpDate') IS NOT NULL
	DROP TABLE [#tmpDate]; 
/* create temporary tables */
CREATE TABLE [#tmpDate] ( 
   [RecID] NUMERIC(26,0) IDENTITY
 , [AgentGUID] BIGINT NOT NULL
 , [ResultGroup] INT
 , [Locked] INT
 , [Stamp] DATETIME
);
COMMIT TRANSACTION SQL3;

BEGIN TRANSACTION SQL4;
WITH LatestDates AS (
	SELECT *, ROW_NUMBER() OVER (
		PARTITION BY AgentGUID ORDER BY [DATE] DESC ) AS [Rank] FROM auditRsltDate
	)
INSERT INTO [#tmpDate] SELECT [AgentGuid], [ResultGroup], [Locked], [Date] FROM LatestDates WHERE [Rank] = 1;	
COMMIT TRANSACTION SQL4;

DECLARE @curRecID BIGINT;
DECLARE @curAgentGUID Numeric( 26,0 );	
DECLARE @iResultGroup INT, @iLocked INT;
DECLARE @curDiskLabel NVARCHAR( 100 );
DECLARE @curDriveName NVARCHAR( 100 );
DECLARE @curTotalSpaceGB FLOAT( 53 );
DECLARE @curFreeSpaceGB FLOAT( 53 );
DECLARE @dLatestDate DATETIME;
DECLARE @iSkipped BIGINT, @iInserted BIGINT;

SET @iSkipped = 0;
SET @iInserted = 0;

/* T-SQL Merge command does not work on remote database server or View.  Hence we use Cursor here */ 	
IF CURSOR_STATUS('global','Cur') >= -1	/* remove Cursor if already exists */
	 DEALLOCATE Cur;
DECLARE Cur CURSOR FOR	/* SQL Cursor */
	SELECT RecID, AgentGUID, ResultGroup, Locked, DiskLabel, DriveName, TotalSpaceGB, FreeSpaceGB FROM [#tmpDisk] ORDER BY RecID;
OPEN Cur;
FETCH NEXT FROM Cur INTO @curRecID, @curAgentGUID, @iResultGroup, @iLocked
	, @curDiskLabel, @curDriveName, @curTotalSpaceGB, @curFreeSpaceGB;

PRINT 'Fetching record through temporary table #tmpDisk';	
WHILE @@FETCH_STATUS = 0
	BEGIN
	-- BEGIN DISTRIBUTED TRANSACTION INSERT1;	
	SET @dLatestDate = NULL;
	SELECT @dLatestDate = [Stamp] FROM [#tmpDate] 
		WHERE AgentGuid = @curAgentGUID AND ResultGroup = @iResultGroup AND Locked = @iLocked;
	IF @dLatestDate IS NULL 
		BEGIN
		SET @iSkipped = @iSkipped + 1;
		PRINT 'Skipping record # ' + LTRIM( CONVERT( NVARCHAR(20), @iSkipped )) + ',  AgentGuid = ' + CONVERT( NVARCHAR(20), @curAgentGUID ) + ', ResultGroup = ' + CONVERT( NVARCHAR(2), @iResultGroup ) + ', Locked = ' + CONVERT( NVARCHAR(2), @iLocked );
		END
	ELSE
		BEGIN
		SET @iInserted = @iInserted + 1;
		PRINT 'Inserting record # ' +  + LTRIM( CONVERT( NVARCHAR(20), @iInserted )) + ', AgentGuid = ' + CONVERT( NVARCHAR(20), @curAgentGUID ) + ', ResultGroup = ' + CONVERT( NVARCHAR(2), @iResultGroup ) + ', Locked = ' + CONVERT( NVARCHAR(2), @iLocked ) + ', Time Stamp = ' + CONVERT( NVARCHAR(30), @dLatestDate, 21 );
		/*INSERT INTO [GMPORTAL\SQLEXPRESS].[GMReports].[dbo].[Disk]( 
			[AgentGUID], YearNum, WeekNum, DiskLabel, DriveName, TotalSpaceGB, FreeSpaceGB, Stamp, RecCreatedOn ) 
			VALUES ( @curAgentGUID
				, DATEPART( YEAR, GETDATE()), DATEPART( WEEK, GETDATE())
				, @curDiskLabel, @curDriveName, @curTotalSpaceGB, @curFreeSpaceGB, @dLatestDate, GETDATE());*/
		END
	-- COMMIT TRANSACTION INSERT1;
	FETCH NEXT FROM Cur INTO @curRecID, @curAgentGUID, @iResultGroup, @iLocked
		, @curDiskLabel, @curDriveName, @curTotalSpaceGB, @curFreeSpaceGB;
	END
CLOSE Cur;
DEALLOCATE Cur;
DELETE FROM #tmpDisk;
DELETE FROM #tmpDate;

PRINT 'Number of records inserted = ' + CONVERT( NVARCHAR(10), @iInserted );
PRINT 'Number of records skipped  = ' + CONVERT( NVARCHAR(10), @iSkipped );

IF OBJECT_ID('tempdb..#tmpDisk') IS NOT NULL
	DROP TABLE [#tmpDisk]; 
IF OBJECT_ID('tempdb..#tmpDate') IS NOT NULL
	DROP TABLE [#tmpDate]; 
	
