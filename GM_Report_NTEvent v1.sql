USE Productions_MSCRM;
/*
CREATE PROCEDURE dbo.proc_ActivityContact_run_1
AS 
BEGIN */

DECLARE @sCatalog VARCHAR(20), @sSchema VARCHAR(10), @sTable VARCHAR(50), @sFullNameTable VARCHAR(80)
DECLARE @sSQL VARCHAR(8000)
DECLARE @iMaxNumAct INT, @i INT
SET @i = 1
SET @sCatalog = 'Productions_MSCRM'
SET @sSchema = 'dbo'
SET @sTable = 'tblActivityContact'
SET @sFullNameTable = @sCatalog + '.' + @sSchema + '.' + @sTable
PRINT @sFullNameTable 

IF( EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES   
    WHERE TABLE_CATALOG = @sCatalog
      AND TABLE_SCHEMA = @sSchema 
      AND TABLE_NAME = @sTable ))
	BEGIN
		SET @sSQL = 'DROP TABLE ' + @sFullNameTable
		PRINT @sSQL;
		EXEC( @sSQL );
	END
	
SET @sSQL = 'CREATE TABLE ' + @sFullNameTable
SET @sSQL = @sSQL +	'( [Owner] nVARCHAR(160)'
SET @sSQL = @sSQL +	', [Contact] nVARCHAR(300)'
SET @sSQL = @sSQL +	', [Account] nVARCHAR(160)'
SET @sSQL = @sSQL +	', [Lead Source] nVARCHAR(128)'
SET @sSQL = @sSQL +	');'
PRINT @sSQL;
EXEC( @sSQL );

SET @sSQL = 'CREATE INDEX Contact_idx ON ' + @sFullNameTable + '( Contact );';
PRINT @sSQL;
EXEC( @sSQL );

SELECT @iMaxNumAct = MAX( T.CT ) 
	FROM 
	( SELECT COUNT(*) AS CT
		FROM vw_ActivityContact_run_1
		GROUP BY Contact
	) AS T;
PRINT @iMaxNumAct

IF @iMaxNumAct > 0
	BEGIN
	SET @sSQL = 'ALTER TABLE ' + @sFullNameTable + ' ADD'
	WHILE @i <= @iMaxNumAct
		BEGIN
		SET @sSQL = @sSQL +	' [' + CONVERT( VARCHAR(100), @i ) + ' Subject] nVARCHAR(200)'  
		SET @sSQL = @sSQL +	', [' + CONVERT( VARCHAR(100), @i ) + ' Type] nVARCHAR(21)'  
		SET @sSQL = @sSQL +	', [' + CONVERT( VARCHAR(100), @i ) + ' Created On] Datetime' 
		SET @sSQL = @sSQL +	', [' + CONVERT( VARCHAR(100), @i ) + ' Created By] nVARCHAR(160)'
		SET @sSQL = @sSQL +	', [' + CONVERT( VARCHAR(100), @i ) + ' Description] nVARCHAR(max)'
		IF @i < @iMaxNumAct BEGIN SET @sSQL = @sSQL + ',' END		
		SET @i = @i + 1
		END
	END	
PRINT @sSQL	
EXEC( @sSQL )	
	
/* 
END */
