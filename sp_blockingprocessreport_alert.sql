USE [master]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*********************************************************************************************
sp_blockedprocessreport v1.2 (2016-02-16)
(C) 2016, Danilo Dominici

Feedback: mailto:ddominici@gmail.com

License: 
[sp_blockedprocessreport_alert] is free to download and use for personal, educational, and internal 
corporate purposes, provided that this header is preserved. Redistribution or sale, in whole or in part, is prohibited without the author's express 
written consent.

Usage:
	EXEC [dbo].[sp_blockedprocessreport_alert]
		@send_notification = 0,
		@start_date        = ',
		@block_duration_ms = 10000,
		@mail_profile      = 'mydatabasemailprofile',
		@mail_recipients   = 'emailaddress@domain.com'
    
*********************************************************************************************/
ALTER PROC [dbo].[sp_blockedprocessreport]
(
    @send_notification  BIT = 0,
    @start_date         DATETIME = NULL,
    @block_duration_ms  INT = 10000,
    @mail_profile       qVARCHAR(128) = NULL,
    @mail_recipients    VARCHAR(1024) = NULL
)
AS
    SET NOCOUNT ON
    
    --
    -- ADJUST PARAMETERS
    --

    -- Start date default to 1 hour, back in time
    IF @start_date IS NULL SET @start_date = DATEADD(hour, -1, GETDATE())

    -- sets the alert threshold
    SELECT @block_duration_ms = CAST(value AS int) * 1000 
    FROM sys.configurations 
    WHERE name = 'blocked process threshold (s)'

    -- Find default profile
    SELECT @mail_profile = name
    FROM msdb.dbo.sysmail_principalprofile pp
    INNER JOIN msdb.dbo.sysmail_profile p ON pp.profile_id = p.profile_id
    WHERE pp.is_default = 1
    -- Default to the author :)
    IF @mail_recipients IS NULL SET @mail_recipients = 'ddominici@gmail.com'

    --
    -- Extract blocked process report data from extended events file
    --
    ;WITH cte1 AS
    (
		SELECT target_data = convert(XML, target_data)
		FROM sys.dm_xe_session_targets t
		JOIN sys.dm_xe_sessions s ON t.event_session_address = s.address
		WHERE t.target_name = 'event_file'
		AND s.name = 'BlockedProcessReport'
    )
    , 
    cte2 AS
    (
		SELECT [FileName] = FileEvent.FileTarget.value('@name', 'varchar(1000)')
		FROM cte1
		CROSS APPLY cte1.target_data.nodes('//EventFileTarget/File') FileEvent(FileTarget)
    ),
    cte3 AS
    (
		SELECT event_data = CONVERT(XML, t2.event_data)
		FROM cte2
		CROSS APPLY sys.fn_xe_file_target_read_file(cte2.[FileName], NULL, NULL, NULL) t2
		WHERE t2.object_name = 'blocked_process_report'
    )
    ,
    cte4 AS
    (
		SELECT xevents.event_data,
			DATEADD(mi, DATEDIFF(mi, GETUTCDATE(), CURRENT_TIMESTAMP), xevents.event_data.value('(event/@timestamp)[1]', 'datetime2')) AS event_time,
			xevents.event_data.query('(event[@name="blocked_process_report"]/data[@name="blocked_process"]/value/blocked-process-report)[1]') AS blocked_process_report,
			xevents.event_data.query('(event[@name="blocked_process_report"]/data[@name="blocked_process"]/value/blocked-process-report/blocked-process)[1]') AS blocked_process,
			xevents.event_data.query('(event[@name="blocked_process_report"]/data[@name="blocked_process"]/value/blocked-process-report/blocking-process)[1]') AS blocking_process
		FROM cte3
		CROSS APPLY (SELECT CAST(event_data AS XML) AS event_data) AS xevents   
		WHERE DATEADD(mi, DATEDIFF(mi, GETUTCDATE(), CURRENT_TIMESTAMP), xevents.event_data.value('(event/@timestamp)[1]', 'datetime2')) >= @start_date
    )
    ,
    LockInfo AS
    (
		SELECT  'Blocked Process' AS ReportType,
			cte4.event_time,
			cte4.event_data.value('(event[@name="blocked_process_report"]/data[@name="database_id"]/value)[1]', 'int') AS [database_id],
			cte4.event_data.value('(event[@name="blocked_process_report"]/data[@name="database_name"]/value)[1]', 'nvarchar(max)') AS [database name],
			cte4.event_data.value('(event[@name="blocked_process_report"]/data[@name="object_id"]/value)[1]', 'int') AS [object_id],
			cte4.event_data.value('(event[@name="blocked_process_report"]/data[@name="index_id"]/value)[1]', 'int') AS [index_id],
			cte4.event_data.value('(event[@name="blocked_process_report"]/data[@name="lock_mode"]/text)[1]', 'varchar') AS [lock_mode],
			cte4.event_data.value('(event[@name="blocked_process_report"]/data[@name="duration"]/value)[1]', 'bigint') / 1000 AS [duration (ms)],
			cte4.event_data.value('(event[@name="blocked_process_report"]/data[@name="login_sid"]/value)[1]', 'int') AS [login_sid],
 
			--blocked_process.value('(blocked-process/process/@waitresource)[1]', 'nvarchar(128)') AS blocked_process_waitresource,
			blocked_process.value('(blocked-process/process/@lastbatchstarted)[1]', 'datetime') AS blocked_process_lastbatchstarted,
			blocked_process.value('(blocked-process/process/@waittime)[1]', 'bigint') AS blocked_process_waittime,
			blocked_process.value('(blocked-process/process/@lockMode)[1]', 'nvarchar(128)') AS blocked_process_lockMode,
			blocked_process.value('(blocked-process/process/@status)[1]', 'nvarchar(128)') AS blocked_process_status,
			blocked_process.value('(blocked-process/process/@spid)[1]', 'int') AS blocked_process_spid,
			blocked_process.value('(blocked-process/process/@clientapp)[1]', 'nvarchar(128)') AS blocked_process_clientapp,
			blocked_process.value('(blocked-process/process/@hostname)[1]', 'nvarchar(128)') AS blocked_process_hostname,
			blocked_process.value('(blocked-process/process/@loginname)[1]', 'nvarchar(128)') AS blocked_process_loginname,
			blocked_process.value('(blocked-process/process/@isolationlevel)[1]', 'nvarchar(128)') AS blocked_process_isolationlevel,
			blocked_process.value('(blocked-process/process/@XDES)[1]', 'nvarchar(128)') AS blocked_process_xdes,
			blocked_process.value('(blocked-process/process/@xactid)[1]', 'INT') AS blocked_process_xactid,
			blocked_process.value('(blocked-process/process/inputbuf)[1]', 'nvarchar(4000)') AS blocked_process_inputbuf,
			blocked_process.query('(blocked-process/process/executionStack)[1]') AS blocked_process_executionstack,

			blocking_process.value('(blocking-process/process/@lastbatchstarted)[1]', 'datetime') AS blocking_process_lastbatchstarted,
			blocking_process.value('(blocking-process/process/@status)[1]', 'nvarchar(128)') AS blocking_process_status,
			blocking_process.value('(blocking-process/process/@spid)[1]', 'int') AS blocking_process_spid,
			blocking_process.value('(blocking-process/process/@clientapp)[1]', 'nvarchar(128)') AS blocking_process_clientapp,
			blocking_process.value('(blocking-process/process/@hostname)[1]', 'nvarchar(128)') AS blocking_process_hostname,
			blocking_process.value('(blocking-process/process/@loginname)[1]', 'nvarchar(128)') AS blocking_process_loginname,
			blocking_process.value('(blocking-process/process/@isolationlevel)[1]', 'nvarchar(128)') AS blocking_process_isolationlevel,
			blocking_process.value('(blocking-process/process/@XDES)[1]', 'nvarchar(128)') AS blocking_process_xdes,
			blocking_process.value('(blocking-process/process/@xactid)[1]', 'INT') AS blocking_process_xactid,
			blocking_process.value('(blocking-process/process/inputbuf)[1]', 'nvarchar(4000)') AS blocking_process_inputbuf
		FROM  cte4
    ),
    Selection AS
    (
	    SELECT  rn = ROW_NUMBER() OVER (PARTITION BY blocked_process_spid, blocked_process_xactid, blocked_process_lastbatchstarted, blocking_process_spid, blocking_process_xactid, blocking_process_lastbatchstarted ORDER BY [duration (ms)] DESC),
			ReportType,
			event_time,

			-- LOCK GENERAL INFO
			[database name],
			COALESCE(OBJECT_SCHEMA_NAME([object_id], [database_id]), ' -- N/A -- ') AS [schema],
			COALESCE(OBJECT_NAME([object_id], [database_id]), ' -- N/A -- ') AS [table],
			[index_id],
			[lock_mode],
			[duration (ms)],
			COALESCE(SUSER_NAME(login_sid), ' -- N/A -- ') AS username,
 
			-- BLOCKED PROCESS
			blocked_process_lastbatchstarted,
			blocked_process_waittime,
			blocked_process_lockMode,
			blocked_process_status,
			blocked_process_spid,
			blocked_process_clientapp,
			blocked_process_hostname,
			blocked_process_loginname,
			blocked_process_isolationlevel,
			blocked_process_xdes,
			blocked_process_xactid,
			blocked_process_inputbuf,
			blocked_process_executionstack,
 
			-- BLOCKING PROCESS
			blocking_process_lastbatchstarted,
			blocking_process_status,
			blocking_process_spid,
			blocking_process_clientapp,
			blocking_process_hostname,
			blocking_process_loginname,
			blocking_process_isolationlevel,
			blocking_process_xdes,
			blocking_process_xactid,
			blocking_process_inputbuf
		FROM  LockInfo
		WHERE [duration (ms)] >= @block_duration_ms
    )
    SELECT * 
    INTO #tmpLockInfo 
    FROM Selection 
    WHERE rn = 1

    IF @send_notification = 1 AND EXISTS(SELECT 1 FROM #tmpLockInfo)
    BEGIN
		DECLARE @body VARCHAR(MAX), 
			@xml VARCHAR(MAX),
			@mail_subject VARCHAR(128) = @@SERVERNAME + ' - Blocked Process Report';

		-- Prepare email body
		SET @xml = CAST(( 
			SELECT TOP 100 
				event_time AS 'td', '',
				--ReportType AS 'td', '',
				[database name] AS 'td', '',
				[schema] AS 'td', '',
				[table] AS 'td', '',
				[index_id] AS 'td', '',
				[lock_mode] AS 'td', '',
				[duration (ms)] AS 'td', '',
				--  username AS 'td', '',
				--blocked_process_waittime AS 'td', '',
				--blocked_process_lockMode AS 'td', '',
				--blocked_process_status AS 'td', '',
				blocked_process_spid AS 'td', '',
				blocked_process_lockMode AS 'td', '',
				blocked_process_clientapp AS 'td', '',
				blocked_process_hostname AS 'td', '',
				COALESCE(blocked_process_loginname, ' --N/A --') AS 'td', '',
				blocked_process_isolationlevel AS 'td', '',
				blocked_process_lastbatchstarted AS 'td', '',
				blocked_process_inputbuf AS 'td', '',
				--blocked_process_executionstack AS 'td', '',
				--blocking_process_status AS 'td', '',
				blocking_process_spid AS 'td', '',
				blocking_process_clientapp AS 'td', '',
				blocking_process_hostname AS 'td', '',
				COALESCE(blocking_process_loginname, ' --N/A --') AS 'td', '',
				blocking_process_isolationlevel AS 'td', '',
				blocking_process_lastbatchstarted AS 'td', '',
				blocking_process_inputbuf AS 'td'
			FROM #tmpLockInfo 
			--WHERE rn = 1
			FOR XML PATH('tr'), ELEMENTS ) AS NVARCHAR(MAX))

		SET @body ='<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" 
 "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"> 
 <html> 
 <head> 
 <style type="text/css"> 
body {
   font-family: "Trebuchet MS", Arial, Helvetica, sans-serif;
   font-size: small;
}

table, th, td {
border: 1px solid black;
border-collapse: collapse;
}

th, td {
padding: 5px;
}

table#t01 tr:nth-child(even) {
background-color: #f2f2f2;
}

table#t01 tr:nth-child(odd) {
background-color: #fff;
}

table#t01 th {
color: white;
background-color: #4CAF50;
}
 </style> 
 </head> 
 <html><body><H3>Blocked Process Report</H3>
 <div style="overflow-x:auto;">
 <table id="t01" widrth="100%"> 
 <tr>
<th>Event Time</th>
<th>Database Name</th>
<th>Schema</th>
<th>Table</th>
<th>Index Id</th>
<th>Lock Mode</th>
<th>Duration (ms)</th>
<th>SPID (blocked)</th>
<th>Lock Mode (blocked)</th>
<th>Client App (blocked)</th>
<th>Hostname (blocked)</th>
<th>Username (blocked)</th>
<th>Isolation Level (blocked)</th>
<th>Last batch started (blocked)</th>
<th>Query (blocked)</th>
<th>SPID (blocking)</th>
<th>Client App (blocking)</th>
<th>Hostname (blocking)</th>
<th>Username (blocking)</th>
<th>Isolation Level (blocking)</th>
<th>Last batch started (blocking)</th>
<th>Query (blocking)</th>
 </tr>'    
 
		SET @body = @body + @xml +'</table></div></body></html>'
    
		EXEC msdb.dbo.sp_send_dbmail
			@profile_name = @mail_profile,
			@body         = @body,
			@body_format  ='HTML',
			@recipients   = @mail_recipients,
			@subject      = @mail_subject;

    END

    IF @send_notification = 0
    BEGIN
		SELECT * FROM #tmpLockInfo;
    END
GO
