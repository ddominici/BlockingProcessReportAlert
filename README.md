# BlockingProcessReportAlert

Blocked process threshold uses the deadlock monitor background thread to walk through the list of tasks waiting for a time greater than or multiples of the configured threshold. The event is generated once per reporting interval for each of the blocked tasks.
The blocked process report is done on a best effort basis. There is no guarantee of any real-time or even close to real-time reporting.
This project reads the blocked process report, on selected interval basis, and sends a HTML email to the DBA.

# Prerequisites

You must have set up the Database Mail feature so that your SQL Server is able to send email messages to anyone.

# Setup

1) Change the blocked process threshold option to specify the threshold, in seconds, at which blocked process reports are generated. The threshold can be set from 0 to 86,400. By default, no blocked process reports are produced. This event is not generated for system tasks or for tasks that are waiting on resources that do not generate detectable deadlocks.

2) Install the stored procedure by running the script sp_blockingprocessreport_alert.sql.

3) Create the job and the schedule for it by running the script.

That's all! 

By default, if you changed the blocked process threshold, let's say, to 15 seconds, you start to receive an HTML email with the blocking and the blocked processes occurred during the last hour. 
