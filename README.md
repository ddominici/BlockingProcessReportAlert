# BlockingProcessReportAlert
The core of this project is the stored procedure usp_BlockedProcessAlert, that extract all the information from the XML blocked process report.

# Setup

1) Change the ###Blocked Process Threshold### from the SQL Server instance options in SQL Server Management Studio. This option means that after the number of seconds you specified, SQL Server generates an XML that contains the required information to troubleshoot the blocking issue, reporting who is blocking and who is blocked by the first process. The default for this option is zero, which means that no blocked process report is generated at all. 
