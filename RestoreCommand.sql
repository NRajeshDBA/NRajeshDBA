/*
Script for creating automated restore scripts based on Ola Hallengren's Maintenance Solution.   
Source: https://ola.hallengren.com  
  
Create RestoreCommand s proc in location of Maintenance Solution procedures   
and CommandLog table along with creating job steps.  
  
At least one full backup for all databases should be logged to CommandLog table (i.e., executed through Maintenance Solution  
created FULL backup job) for generated restore scripts to be valid.   
Restore scripts are generated based on CommandLog table, not msdb backup history.  
  
Restore script is created using ouput file. Each backup job creates a date / time stamped restore script file in separate step.  
Add a job to manage file retention if desired (I use a modified version of Ola's Output File Cleanup job).  
If possible, perform a tail log backup and add to end of restore script   
in order to avoid data loss (also remove any replace options for full backups).  
  
Make sure sql agent has read / write to the directory that you want the restore script created.  
  
Script will read backup file location from @Directory value used in respective DatabaseBackup job (NULL is supported).   
Set @LogToTable = 'Y' for all backup jobs! (This is the defaut).    
  
Created by Jared Zagelbaum, 4/13/2015, https://jaredzagelbaum.wordpress.com/  
For intro / tutorial see: https://jaredzagelbaum.wordpress.com/2015/04/16/automated-restore-script-output-for-ola-hallengrens-maintenance-solution/  


This script is modified version of the one available at https://jaredzagelbaum.wordpress.com/2015/04/16/automated-restore-script-output-for-ola-hallengrens-maintenance-solution/
Thanks to JARED ZAGELBAUM
This script will give a TSQL Restore commands as output based on data in CommandLog Table of olahallengren script :  https://github.com/olahallengren/sql-server-maintenance-solution
Date: <16-0-2023>
SP is modified by Rajesh Nalubolu in include restoration info from URL with CREDENTIAL and Split file

*/
CREATE PROCEDURE [dbo].[RestoreCommand] AS      
SET NOCOUNT ON  

Declare @DatabaseName sysname
Declare @DatabaseNamePartition sysname = 'N/A'
Declare @Command nvarchar(max)
Declare @IncludeCopyOnly nvarchar(max) = 'Y'
-- include copy only backups in restore script? Added for AlwaysOn support    
Declare @message nvarchar(max)
Declare @credential nvarchar (50)

SELECT top 1
    @credential= 'CREDENTIAL ='''  
+    CASE  
        WHEN CHARINDEX('CREDENTIAL = N''', Command) > 0  
        THEN SUBSTRING(Command, CHARINDEX('CREDENTIAL = N''', Command) + LEN('CREDENTIAL = N'''), CHARINDEX('''', Command, CHARINDEX('CREDENTIAL = N''', Command) + LEN('CREDENTIAL = N''')) - CHARINDEX('CREDENTIAL = N''', Command) - LEN('CREDENTIAL = N''')
)  
        ELSE NULL  
    END   
 +''''
FROM CommandLog
WHERE Command LIKE '%CREDENTIAL = N%'
Order by ID desc
--select @credential  

Declare restorecursor CURSOR FAST_FORWARD FOR    
  
with
    completed_ola_backups
    as
    (
        SELECT [ID]  
, [DatabaseName]  
, [SchemaName]  
, [ObjectName]  
, [ObjectType]  
, [IndexName]  
, [IndexType]  
, [StatisticsName]  
, [PartitionNumber]  
, [ExtendedInfo]  
, [Command]  
, [CommandType]  
, [StartTime]  
, [EndTime]  
, [ErrorNumber]  
, [ErrorMessage]  
, CASE WHEN [Command] LIKE '%_LOG%' THEN 'Log'  
WHEN @IncludeCopyOnly = 'Y' AND [Command] LIKE '%LOG_COPY_ONLY%' THEN 'Log'  
WHEN [Command] LIKE '%_DIFF%' THEN 'Diff'  
WHEN [Command] LIKE '%_FULL%' THEN 'Full'  
WHEN @IncludeCopyOnly = 'Y' AND [Command] LIKE '%FULL_COPY_ONLY%' THEN 'Full'  
End BackupType  
, CASE WHEN [Command] LIKE '%_LOG%' THEN 3  
WHEN @IncludeCopyOnly = 'Y' AND [Command] LIKE '%LOG_COPY_ONLY%' THEN 3  
WHEN [Command] LIKE '%_DIFF%' THEN 2  
WHEN [Command] LIKE '%_FULL%' THEN 1  
WHEN @IncludeCopyOnly = 'Y' AND [Command] LIKE '%FULL_COPY_ONLY%' THEN 1  
End BackupTypeOrder  
, CASE CommandType
WHEN 'BACKUP_LOG' THEN
    CASE
        WHEN CHARINDEX('with', Command) > 0 THEN CHARINDEX('with', Command)
        WHEN CHARINDEX('.trn', Command) > 0 THEN CHARINDEX('.trn', Command)
        ELSE 0
    END
WHEN 'BACKUP_DATABASE' THEN
    CHARINDEX('WITH', Command) -- have WITH COMPRESSION
END filechar

        FROM [dbo].[CommandLog]
        WHERE CommandType IN ('BACKUP_LOG', 'BACKUP_DATABASE')
            AND EndTime IS NOT NULL -- Completed Backups Only  
            AND ErrorNumber = 0

    )  
,
    lastfull
    as
    (
        SELECT MAX( [id]) FullId  
, DatabaseName
        FROM completed_ola_backups
        WHERE BackupType = 'Full'
        GROUP BY DatabaseName
    )  
,
    lastdiff
    as
    (
        SELECT MAX( [id]) DiffId  
, cob.DatabaseName
        FROM completed_ola_backups cob
            INNER JOIN lastfull lf
            ON cob.DatabaseName = lf.DatabaseName
                AND cob.[ID] > lf.FullId
        WHERE BackupType = 'Diff'
        GROUP BY cob.DatabaseName
    )  
,
    lastnonlog
    as
    (
        SELECT Max([Id]) LogIdBoundary  
, DatabaseName
        FROM
            (  
                                                SELECT Fullid Id, DatabaseName
                FROM lastfull
            UNION ALL
                SELECT DiffId Id, ld.DatabaseName
                FROM lastdiff ld  
) Nonlog
        GROUP BY DatabaseName
    )  
,
    lastlogs
    as
    (
        SELECT cob.[Id] logid
        FROM completed_ola_backups cob
            INNER JOIN lastnonlog lnl
            ON cob.DatabaseName = lnl.DatabaseName
                AND cob.[ID] > lnl.LogIdBoundary
    )  
,
    validbackups
    as
    (
                            SELECT FullId backupid
            FROM lastfull
        UNION
            SELECT DiffId backupid
            FROM lastdiff
        UNION
            SELECT logid backupid
            FROM lastlogs
    )

SELECT cob.DatabaseName,
    Replace(Replace( Replace( Replace(LEFT(Command, filechar + 3) , 'BACKUP LOG', 'RESTORE LOG'), 'BACKUP DATABASE', 'RESTORE DATABASE'), 'TO DISK', 'FROM DISK'),'TO URL','FROM URL')   
       + CASE WHEN @credential IS NULL THEN '' ELSE ' ' + @credential + ',' END + ' NORECOVERY'

+  
CASE BackupType  
WHEN 'Full'  
THEN ', REPLACE, Stats= 1;'  
ELSE ''  
+', Stats= 1;'

END RestoreCommand

FROM completed_ola_backups cob
WHERE EXISTS  
(SELECT *
FROM validbackups vb
WHERE cob.[ID] = vb.backupid  
)
ORDER BY cob.DatabaseName, Id, BackupTypeOrder
;



RAISERROR( '/*****************************************************************', 10, 1) WITH NOWAIT
set @message = 'Emergency Script Restore for ' + @@Servername +  CASE @@Servicename WHEN 'MSSQLSERVER' THEN '' ELSE '\' + @@Servicename END
RAISERROR(@message,10,1) WITH NOWAIT
set @message = 'Generated ' + convert(nvarchar, getdate(), 9)
RAISERROR(@message,10,1) WITH NOWAIT
set @message = 'Script does not perform a tail log backup. Dataloss may occur, use only for emergency DR.'
RAISERROR(@message,10,1) WITH NOWAIT
RAISERROR( '******************************************************************/', 10, 1) WITH NOWAIT


OPEN RestoreCursor

FETCH NEXT FROM restorecursor    
 INTO @databasename, @command


WHILE @@FETCH_STATUS = 0    
 BEGIN


    IF @DatabaseName <> @DatabaseNamePartition AND @DatabaseNamePartition <> 'N/A'    
 BEGIN
        set @message = 'RESTORE DATABASE ' + '[' + @DatabaseNamePartition + ']' + ' WITH RECOVERY;'
        RAISERROR(@message,10,1) WITH NOWAIT
    END

    IF @DatabaseName <> @DatabaseNamePartition    
  BEGIN
        set @message = char(13) + char(10) + char(13) + char(10) + '--------' + @DatabaseName + '-------------'
        RAISERROR(@message,10,1) WITH NOWAIT
    END

    RAISERROR( @Command,10,1) WITH NOWAIT



    SET @DatabaseNamePartition = @DatabaseName
    FETCH NEXT FROM restorecursor    
INTO @databasename, @command

END


set @message =  'RESTORE DATABASE ' + '[' +  @DatabaseNamePartition + ']' +  ' WITH RECOVERY;'
RAISERROR(@message,10,1) WITH NOWAIT    
;

CLOSE restorecursor;
DEALLOCATE restorecursor;   
