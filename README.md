# SQLPerformanceMonitor

One of the main questions that we have in a live performance troubleshooting scenario is to answer the question what is Azure SQL Database or Managed Instance working on?. [In this video]([https://techcommunity.microsoft.com/t5/azure-database-support-blog/lesson-learned-224-hands-on-labs-checking-the-performance-with/ba-p/3574602](https://techcommunity.microsoft.com/t5/azure-database-support-blog/lesson-learned-231-hands-on-labs-what-is-azure-sql-working-on/ba-p/3581046)) I'm going to share some insights how to find the information. 

In critical service requests when our customers need an immediately response and resolution for their performance issue, we often run queries like you have below (besides other ones) to know the process that are currently running. In order to have a easy way to capture this information I developed this Powershell script that you could find here, running it you could have this information and save it to a file.

Please, when you copy this PowerShell Script in your local environment copy also Config.Txt and Rules.Txt. These files are neccesary at the moment of the execution. If these don't exist will be created with default values.

## Main Goal of this PowerShell script.
 
- **Collect live data during a process execution every 5 seconds.**
- **Obtain details about query text, wait time, execution plan, program name and other details.**
- **Additionally, you could configure a filter to obtain only the queries that you have some specific interest, for example, high cpu, elapsed time or wait type.**
- **This PowerShell script will continuously running until you press CTRL-C and it could be run in unattended mode.**

## Configuration file
- **server**=servername.database.windows.net 
- **user**=username
- **password**=Password
- **Db**=DatabaseName
- **ApplicationName**=SQL Performance Monitoring
- **RetryLogicNumberAttempts**=10 #Number of attempts to connect to the database
- **RetryLogicNumberAttemptsBetweenAttemps**=5 #Number of seconds in every connection retry
- **ConnectionTimeout**=60
- **CommandTimeout**=3600
- **SecondsToWait**=5 #Number of seconds to wait for every cycle.
- **orderby**=order by req.database_id #Order By of the output of the queries
- **ViewType**=ALL #Name of columns to export
- **MaxLenStatement**=4000  #Maximum caracter long.

## Configuration file:
- **Default content:** ALL;ALL;ALL;"All Queries"
- **Additional rules:**
   + cpu_time_ms;-gt;100;"High CPU"
   + last_wait_type;-eq;"PAGELATCH_EX";"High PageLatchEX"
 
## Example of data gathered:
 
- **Rule NameofRule**
- **statement_text:** SELECT TOP 600000 * INTO #t FROM dbo.Example1 
- **database_id:** 7 
- **program_name:** Testing by JMJD - SQL (HighTempDB) 
- **session_id:** 67
- **cpu_time_ms:** 271 
- **status:** suspended 
- **wait_resource:** 2:1:107 
- **last_wait_type:** PAGELATCH_EX 
- **blocking_session_id:** 77
- **BlockerQuery:** SELECT TOP 600000 * INTO #t FROM dbo.Example1; DROP TABLE #t; ||
 
## Outcome

In the database created we are gone 
- **PerfSqlMonitoring.Log** = Contains all queries executed or filtered.

Enjoy!
