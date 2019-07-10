# BlockingProcessReportAlert
The core of this project is the stored procedure usp_BlockedProcessAlert, that extract all the information from the XML blocked process report.

# Prerequisites

You must have set up the Database Mail feature so that your SQL Server is able to send email messages to anyone.

# Setup

1) Change the ##Blocked Process Threshold## from the SQL Server instance options in SQL Server Management Studio. This option means that after the number of seconds you specified, SQL Server generates an XML that contains the required information to troubleshoot the blocking issue, reporting who is blocking and who is blocked by the first process. The default for this option is zero, which means that no blocked process report is generated at all. 

2) Install the stored procedure (by default in master database, but you can choose another database of your choice).

3) Create the job and the schedule for it by running the second script.

That's all! 

By default, if you changed the blocked process threshold, let's say, to 15 seconds, you start to receive an HTML email with the blocking and the blocked processes occurred during the last hour. 
