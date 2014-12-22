USE [ksubscribers];
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO
/*************************************************************************************************************************
	Procedure GM_Report_Servers_Snapshot																Adam Ip 2013-03-06

	Procedure GM_Report_Servers_Snapshot takes a snapshot based on [MachNameTab], while collecting server information from
		various Tables.
	Enhancement: 
		1. Measurement unit of memory installed on server is MB.  In case that such description contains
			TB, GB, KB, or contains no unit description at all, the calculation would take care of these different 
			situation.
		2. If the fetched data is NULL, a proper conversion is performed before INSERTing to report.
		3. INSERTing avoids duplication of records.
		4. Records in report contains a record ID, RecID, as primary key
		5. Records in report contains a timestamp field, i.e. RecCreatedOn.  For instance, in case the server changes 
			its configuration in the middle of a month, two snapshots in that month will generate a total of two records 
			on this server, with diffenent configuration description and different timestamps.
		6. Stored Procedure returns number of records been INSERTed.
*/
ALTER PROCEDURE [dbo].[GM_Report_Servers_Snapshot]
AS

DECLARE @id NUMERIC(26);
DECLARE @Mach_Name VARCHAR(100);
DECLARE @Group_Name VARCHAR(100);
DECLARE @Date_Stamp DATETIME;
DECLARE @Machine_Type VARCHAR(100);
DECLARE @IP_Address VARCHAR(20);
DECLARE @Last_Reboot DATETIME;
DECLARE @Memory_Installed_MB BIGINT;
DECLARE @Mem_Size VARCHAR(100);	
DECLARE @Processors Varchar(100);
DECLARE @Core INT;
DECLARE @Windows_Version Varchar(100);
DECLARE @Reporting_Enabled Varchar(100);
DECLARE @Ret INT;

IF CURSOR_STATUS('global','Cur') >= -1	/* remove Cursor if already exists */
	 DEALLOCATE Cur;
DECLARE Cur CURSOR FOR	/* First SQL Cursor */
	SELECT DISTINCT AGENTGUID FROM [MachNameTab] ORDER BY AGENTGUID;
OPEN Cur;	
FETCH NEXT FROM Cur INTO @id;
SET @Ret = 0;
WHILE @@FETCH_STATUS = 0
	BEGIN

	/* Fetching data */	
	SELECT @Reporting_Enabled = fieldValue FROM auditRsltManualFieldValues AS V, auditRsltManualFields AS F
		WHERE V.agentGuid = @id AND V.fieldNameFK = F.id AND F.fieldName LIKE 'ReportingEnabled';
		
	IF @Reporting_Enabled LIKE 'YES'
		BEGIN	
		PRINT 'Fetching record on AgentGUID = ' + CONVERT( VARCHAR(26), @id );
		SELECT TOP 1 @Mach_Name = LTrim(RTrim(machName)), @Group_Name = LTrim(RTrim(groupName)) 
			FROM machNameTab WHERE agentGuid = @id;
		SET @Date_Stamp = Dateadd(month, Datediff(month, 0, Getdate()), 0);

		SELECT @Machine_Type = LTrim(RTrim(fieldValue)) FROM auditRsltManualFieldValues AS V, auditRsltManualFields AS F
			WHERE V.agentGuid = @id AND V.fieldNameFK = F.id AND F.fieldName LIKE 'Server Type';
			
		SELECT TOP 1 @IP_Address = LTrim(RTrim(ipAddress)), @Windows_Version = LTrim(RTrim(osInfo)) 
			FROM userIpInfo WHERE agentGuid = @id;
		SELECT TOP 1 @Last_Reboot = rebootTime FROM lastReboot WHERE agentGuid = @id;
		
		DECLARE MEM CURSOR FOR	/* Second SQL Cursor */
			SELECT memSize FROM auditRsltSimm WHERE agentGuid = @id;
		SET @Memory_Installed_MB = 0;
		OPEN MEM;
		FETCH NEXT FROM MEM INTO @Mem_Size;
		WHILE @@FETCH_STATUS = 0
			BEGIN
			IF @Mem_Size IS NOT NULL
				BEGIN
				SET @Mem_Size = LTrim(RTrim( @Mem_Size ));
				IF CHARINDEX( 'MB', @Mem_Size ) > 0
					BEGIN
					SET @Mem_Size = REPLACE( @Mem_Size, 'MB', '' );
					SET @Memory_Installed_MB = @Memory_Installed_MB + CAST( @Mem_Size AS BIGINT );			
					END
				ELSE IF CHARINDEX( 'GB', @Mem_Size ) > 0
					BEGIN
					SET @Mem_Size = REPLACE( @Mem_Size, 'GB', '' );
					SET @Memory_Installed_MB = @Memory_Installed_MB + CAST( @Mem_Size AS BIGINT ) * 1024;			
					END
				ELSE IF CHARINDEX( 'TB', @Mem_Size ) > 0
					BEGIN
					SET @Mem_Size = REPLACE( @Mem_Size, 'TB', '' );
					SET @Memory_Installed_MB = @Memory_Installed_MB + CAST( @Mem_Size AS BIGINT ) * 1024 * 1024;			
					END	
				ELSE IF CHARINDEX( 'KB', @Mem_Size ) > 0
					BEGIN
					SET @Mem_Size = REPLACE( @Mem_Size, 'KB', '' );
					SET @Memory_Installed_MB = @Memory_Installed_MB + CAST( @Mem_Size AS BIGINT ) / 1024;			
					END
				ELSE -- does not carry any unit description, i.e. KB MB GB TB.  Assume to be MB
					BEGIN
					SET @Memory_Installed_MB = @Memory_Installed_MB + CAST( @Mem_Size AS BIGINT );			
					END				
				END
			FETCH NEXT FROM MEM INTO @Mem_Size;
			END
		CLOSE MEM;
		DEALLOCATE MEM; 	
		
		SELECT TOP 1 @Processors = cpuDesc, @Core = cpuCount FROM auditRsltCpu WHERE agentGuid = @id;	
		
		/* Saving data to report */	
		SET @Group_Name = ISNULL( @Group_Name, '' );	
		SET @Machine_Type = ISNULL( @Machine_Type, '' ); 
		SET @Processors = ISNULL( @Processors, '' ); 
		SET @Core = ISNULL( @Core, 0 ); 
		SET @Windows_Version = ISNULL( @Windows_Version, '' ); 

		IF NOT EXISTS ( SELECT * FROM [GMPORTAL\SQLEXPRESS].[GMReports].[dbo].[Servers] 
			WHERE [AgentGUID] = @id
				AND [Server] = @Mach_Name
				AND Company = @Group_Name
				AND TheDate = @Date_Stamp
				AND MachineType = @Machine_Type 
				AND IPAddress = @IP_Address
				AND ( LastReboot IS NULL OR LastReboot = @Last_Reboot )
				AND MemoryInstalledMB = @Memory_Installed_MB
				AND Processor = @Processors
				AND Cores = @Core
				AND WindowsVersion = @Windows_Version )
			BEGIN
			PRINT 'Inserting record on AgentGUID = ' + CONVERT( VARCHAR(26), @id );		
			INSERT INTO [GMPORTAL\SQLEXPRESS].[GMReports].[dbo].[Servers]
				( [AgentGUID], [Server], Company, TheDate, MachineType,IPAddress, LastReboot, 
					MemoryInstalledMB, Processor, Cores, WindowsVersion, [RecCreatedOn] ) 
				VALUES
				( @id, @Mach_Name, @Group_Name, @Date_Stamp, @Machine_Type, @IP_Address, @Last_Reboot, 
					@Memory_Installed_MB, @Processors, @Core, @Windows_Version, GETDATE());
			SET @Ret = @Ret + 1;
			END
		END	-- if enable reporting			
	FETCH NEXT FROM Cur INTO @id;
	END
CLOSE Cur;
DEALLOCATE Cur; 

/* Total number of records inserted */	
RETURN @Ret;	
	
