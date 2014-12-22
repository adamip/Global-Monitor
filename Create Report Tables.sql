USE [GMReports];

DROP TABLE [dbo].[Servers];
CREATE TABLE [dbo].[Servers] (
 [RecID] BIGINT IDENTITY
 , [AgentGUID] Numeric(26,0) NOT NULL
 , [Server] Varchar(50) NOT NULL
 , Company Varchar(50) NOT NULL
 , TheDate Datetime NOT NULL
 , MachineType Varchar(50) 
 , IPAddress Varchar(50) NOT NULL
 , LastReboot Datetime
 , MemoryInstalledMB BIGINT
 , Processor Varchar(100) NOT NULL
 , Cores INT
 , WindowsVersion Varchar(100) NOT NULL
 , RecCreatedOn Datetime NOT NULL
 );

ALTER TABLE  [GMReports].[dbo].[Servers]
ADD CONSTRAINT PK_Servers
PRIMARY KEY( [RecID] ); 

/* - - - - - - - - - - - - - - - - - - */
DROP TABLE [GMReports].[dbo].[CPU];
CREATE TABLE [GMReports].[dbo].[CPU] (
 [RecID] BIGINT IDENTITY
 , [AgentGUID] Numeric(26,0) NOT NULL
 , [TheDate] Datetime NOT NULL
 , [Hour] INT NOT NULL
 , [Sum] FLOAT(53) NOT NULL
 , [DataPoints] INT NOT NULL
 , [RecCreatedOn] Datetime NOT NULL
 );

ALTER TABLE  [GMReports].[dbo].[CPU]
ADD CONSTRAINT PK_CPU
PRIMARY KEY( [RecID] ); 

/* - - - - - - - - - - - - - - - - - - */
DROP TABLE [GMReports].[dbo].[Memory];
CREATE TABLE [GMReports].[dbo].[Memory] (
 [RecID] BIGINT IDENTITY
 , [AgentGUID] Numeric(26,0) NOT NULL
 , [TheDate] Datetime NOT NULL
 , [Hour] INT NOT NULL
 , [Sum] FLOAT(53) NOT NULL
 , [DataPoints] INT NOT NULL
 , [RecCreatedOn] Datetime NOT NULL
 );

ALTER TABLE  [GMReports].[dbo].[Memory]
ADD CONSTRAINT PK_Memory
PRIMARY KEY( [RecID] ); 

/* - - - - - - - - - - - - - - - - - - */
DROP TABLE [GMReports].[dbo].[NTEvent];
CREATE TABLE [GMReports].[dbo].[NTEvent] (
 [RecID] BIGINT IDENTITY
 , [AgentGUID] Numeric(26,0) NOT NULL
 , [EventTime] Datetime NOT NULL
 , [Message] NVARCHAR(2000) NOT NULL
 , [RecCreatedOn] Datetime NOT NULL
 );

ALTER TABLE  [GMReports].[dbo].[NTEvent]
ADD CONSTRAINT PK_NTEvent
PRIMARY KEY( [RecID] ); 

/* - - - - - - - - - - - - - - - - - - */
CREATE TABLE [GMReports].[dbo].[Disk] ( 
   [RecID] NUMERIC(26,0) IDENTITY
 , [AgentGUID] BIGINT NOT NULL
 , [YearNum] INT NOT NULL
 , [WeekNum] INT NOT NULL
 , [DiskLabel] NVARCHAR( 100 ) NOT NULL 
 , [DriveName] NVARCHAR( 100 ) NOT NULL 
 , [TotalSpaceGB] FLOAT(53)
 , [FreeSpaceGB] FLOAT(53)
 , [Stamp] Datetime NOT NULL
 , [RecCreatedOn] Datetime NOT NULL
	);
 ALTER TABLE [GMReports].[dbo].[Disk]
	ADD CONSTRAINT PK_Disk
	PRIMARY KEY( [RecID] ); 









