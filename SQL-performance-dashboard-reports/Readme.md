
The following blog post provides more details and background on this solution. I highly recommend you first read the blog post before you consider deploying this solution to your environment.

https://blogs.msdn.microsoft.com/sql_server_team/sql-server-performance-dashboard-reports-unleashed-for-enterprise-monitoring/

Setting Up and Configuring SQL Server Dashboard Reports for Monitoring

The following are steps for setting up and configuring SQL Server Dashboard Reports for monitoring. 

1.	Install and configure SQL Server Reporting service (any version greater than SQL Server 2012 with latest SP and CU) on a server identified as a Central Monitoring Server. The central monitoring server should be part of the same domain and network as the target SQL Server instance.
2.	Download SQL Performance Dashboard Reporting Solution from Tiger toobox github repository.
3.	Download SSDT-BI for Visual Studio 2012 or Download SSDT-BI for Visual Studio 2013 and install BI designer on workstation where github solution is downloaded or copied.
4.	Open PerfDashboard solution using Visual Studio 2012 or 2013 on the workstation and deploy it against the SQL Server Reporting service instance by providing the TargetServerUrl as shown below
5.	Make sure report deployment is successful and browse the report manager url to see the reports deployed under SQL Server Performance Dashboard folder.
6.	Run setup.sql script from Tiger toobox github repository against all the target SQL Server instances which creates a schema MS_PerfDashboard in msdb database. All the relevant objects required for SQL performance dashboard reports are contained in MS_PerfDashboard schema.
7.	You should always start with performance_dashboard_main report as a landing page and navigate to other reports from the performance dashboard report. If you have deployed the reports against SQL Server 2016 Reporting services instance, you can set performance_dashboard_main report as favorite for easier navigation as shown below.
8.	When you browse performance_dashboard_main report, it will ask you the target SQL Server instance which you wish to see the report against as shown below. If setup.sql is ran against the target SQL Server instance, you will see the data populated against the report.
9.	You can further click on the hyperlinks to navigate to that report for further drill through as shown below

All the reports use Windows authentication to connect to the target SQL Server instance so if browsing user is part of a different domain or do not have login or VIEW SERVER STATE permissions, the reports will generate an error. Further, this solution relies on Kerberos authentication as it involves double hop (client -> SSRS server -> target SQL instance), so it is important that target SQL Server instances have SPNs registered. The alternative to Kerberos authentication is to use stored credentials in the report which helps bypass double hop but is considered less secure.
If you have also deployed the SQL Performance Baselining solution and System Health Session Reports from Tiger toobox github repository, you can use the same central SSRS server for hosting all the reports as shown below and running it against target SQL Server instances as shown below. The SQL Performance Baselining solution can be useful to identify the historical resource consumption, usage and capacity planning while SQL performance dashboard reports and System health session reports can be used for monitoring and point in time troubleshooting.

DISCLAIMER: ?? 2017 Microsoft Corporation. All rights reserved. Sample scripts in this guide are not supported under any Microsoft standard support program or service. The sample scripts are provided AS IS without warranty of any kind. Microsoft disclaims all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a particular purpose. The entire risk arising out of the use or performance of the sample scripts and documentation remains with you. In no event shall Microsoft, its authors, or anyone else involved in the creation, production, or delivery of the scripts be liable for any damages whatsoever (including, without limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary loss) arising out of the use of or inability to use the sample scripts or documentation, even if Microsoft has been advised of the possibility of such damages.
