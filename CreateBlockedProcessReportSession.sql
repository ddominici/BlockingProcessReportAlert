CREATE EVENT SESSION [BlockedProcessReport] ON SERVER 
ADD EVENT sqlserver.blocked_process_report (
    ACTION(
		 sqlserver.client_pid
		,sqlserver.database_name
		,sqlserver.plan_handle,sqlserver.query_plan_hash)
)
ADD TARGET package0.event_file(SET filename=N'BlockedProcessReport',max_file_size=(5))
WITH (
	 MAX_MEMORY=4096 KB
	,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS
	,MAX_DISPATCH_LATENCY=30 SECONDS
	,MAX_EVENT_SIZE=0 KB
	,MEMORY_PARTITION_MODE=NONE
	,TRACK_CAUSALITY=OFF
	,STARTUP_STATE=ON
)
GO
