/* This script is modified version of the one available at https://jaredzagelbaum.wordpress.com/2015/04/16/automated-restore-script-output-for-ola-hallengrens-maintenance-solution/comment-page-1/?unapproved=448&moderation-hash=cec0588c2318a1a796618cfe741ce978#comment-448
Thanks to JARED ZAGELBAUM
This script will give a TSQL Restore commands as output based on data in CommandLog Table of olahallengren script :  https://github.com/olahallengren/sql-server-maintenance-solution

*/


Create PROCEDURE [dbo].[RestoreCommand] AS    
SET NOCOUNT ON    
Declare @DatabaseName sysname    
Declare @DatabaseNamePartition sysname = 'N/A'    
Declare @Command nvarchar(max)    
Declare @IncludeCopyOnly nvarchar(max) = 'Y'   -- include copy only backups in restore script? Added for AlwaysOn support    
Declare @message nvarchar(max)    
Declare @credential nvarchar (50)  
  
SELECT top 1 @credential= 'CREDENTIAL ='''  
+    CASE  
        WHEN CHARINDEX('CREDENTIAL = N''', Command) > 0  
        THEN SUBSTRING(Command, CHARINDEX('CREDENTIAL = N''', Command) + LEN('CREDENTIAL = N'''), CHARINDEX('''', Command, CHARINDEX('CREDENTIAL = N''', Command) + LEN('CREDENTIAL = N''')) - CHARINDEX('CREDENTIAL = N''', Command) - LEN('CREDENTIAL = N''')
)  
        ELSE NULL  
    END   
 +''''  
FROM CommandLog WHERE Command LIKE '%CREDENTIAL = N%'  Order by ID desc
--select @credential  
  
Declare restorecursor CURSOR FAST_FORWARD FOR    
  
with completed_ola_backups as  
(  
SELECT [ID]  
,[DatabaseName]  
,[SchemaName]  
,[ObjectName]  
,[ObjectType]  
,[IndexName]  
,[IndexType]  
,[StatisticsName]  
,[PartitionNumber]  
,[ExtendedInfo]  
,[Command]  
,[CommandType]  
,[StartTime]  
,[EndTime]  
,[ErrorNumber]  
,[ErrorMessage]  
,CASE WHEN [Command] LIKE '%_LOG%' THEN 'Log'  
WHEN @IncludeCopyOnly = 'Y' AND [Command] LIKE '%LOG_COPY_ONLY%' THEN 'Log'  
WHEN [Command] LIKE '%_DIFF%' THEN 'Diff'  
WHEN [Command] LIKE '%_FULL%' THEN 'Full'  
WHEN @IncludeCopyOnly = 'Y' AND [Command] LIKE '%FULL_COPY_ONLY%' THEN 'Full'  
End BackupType  
,CASE WHEN [Command] LIKE '%_LOG%' THEN 3  
WHEN @IncludeCopyOnly = 'Y' AND [Command] LIKE '%LOG_COPY_ONLY%' THEN 3  
WHEN [Command] LIKE '%_DIFF%' THEN 2  
WHEN [Command] LIKE '%_FULL%' THEN 1  
WHEN @IncludeCopyOnly = 'Y' AND [Command] LIKE '%FULL_COPY_ONLY%' THEN 1  
End BackupTypeOrder  
,CASE CommandType
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
,lastfull as  
(  
SELECT MAX( [id]) FullId  
,DatabaseName  
FROM completed_ola_backups  
WHERE BackupType = 'Full'  
GROUP BY DatabaseName  
)  
,lastdiff as  
(  
SELECT MAX( [id]) DiffId  
,cob.DatabaseName  
FROM completed_ola_backups cob  
INNER JOIN lastfull lf  
ON cob.DatabaseName = lf.DatabaseName  
AND cob.[ID] > lf.FullId  
WHERE BackupType = 'Diff'  
GROUP BY cob.DatabaseName  
)  
,lastnonlog as  
(  
SELECT Max([Id]) LogIdBoundary  
,DatabaseName  
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
,lastlogs as  
(  
SELECT cob.[Id] logid  
FROM completed_ola_backups cob  
INNER JOIN lastnonlog lnl  
ON cob.DatabaseName = lnl.DatabaseName  
AND cob.[ID] > lnl.LogIdBoundary  
)  
,validbackups as  
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
       + CASE WHEN @credential IS NULL THEN '' ELSE ' ' + @credential + ',' END + ' NORECOVERY, Stats=1'  

+  
CASE BackupType  
WHEN 'Full'  
THEN ', REPLACE;'  
ELSE ';'  
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

