#----------------------------------------------------------------
# Application: SQL Performance Monitor
# Propose: Inform about SQL Request, status and time_wait
#----------------------------------------------------------------
      
#-------------------------------------------------------------------------------
# Show the number of requests and wait stats 
#-------------------------------------------------------------------------------

function CheckStatusPerRequestAdHoc($connection)
{
 try
 {
   $StringColumns=""
   $RecordsAnalyzed=0
   $RecordsRules=0
   $ColumnExport = [System.Collections.ArrayList]::new() 
   $Tmp = [ColumnsToExport]::new()
   $MaxLenStatement = $(ReadConfigFile("MaxLenStatement"))
   if(TestEmpty($MaxLenStatement))
   {
    $MaxLenStatement=250
   }

   $command = New-Object -TypeName System.Data.SqlClient.SqlCommand
   $command.CommandTimeout = $(ReadConfigFile("CommandTimeout"))
   $command.Connection=$connection
   $command.CommandText = "SELECT
                             substring(REPLACE(REPLACE(SUBSTRING(ST.text, (req.statement_start_offset/2) + 1, (
                            (CASE statement_end_offset WHEN -1 THEN DATALENGTH(ST.text) ELSE req.statement_end_offset END
                            - req.statement_start_offset)/2) + 1) , CHAR(10), ' '), CHAR(13), ' '), 1, " + $MaxLenStatement + ") AS statement_text
                            ,req.database_id as database_id
                            ,program_name as program_name
                            ,req.session_id as session_id
                            , req.cpu_time as cpu_time_ms
                            , req.status as status
                            , wait_time as wait_time
                            , wait_resource as wait_resource 
                            , wait_type as wait_type 
                            , last_wait_type as last_wait_type
                            , req.total_elapsed_time as total_elapsed_time
                            , total_scheduled_time as total_scheduled_time
                            , req.row_count as [Row Count]
                            , command as command
                            , scheduler_id as scheduler_id
                            , memory_usage as memory_usage
                            , req.writes as writes
                            , req.reads as reads 
                            , req.logical_reads as logical_reads
                            , blocking_session_id as blocking_session_id
                            , CASE blocking_session_id WHEN 0 THEN 'Noblocking' ELSE ( select t.text as BlockerQuery FROM sys.dm_exec_connections as connblocker cross apply sys.dm_exec_sql_text(connblocker.most_recent_sql_handle) AS T where blocking_session_id=connblocker.session_id ) end AS BlockerQuery
                            , host_name as host_name
                            , host_process_id as host_process_id
                            , login_time as login_time
                            , client_net_address as client_net_adress
                            , TextPlan.query_plan as QueryPlan
                            FROM sys.dm_exec_requests AS req
                            INNER JOIN sys.dm_exec_connections as Conn on req.session_id=Conn.session_id
                            inner join sys.dm_exec_sessions as sess on sess.session_id = req.session_id
                            CROSS APPLY sys.dm_exec_sql_text(req.sql_handle) as ST
                            CROSS APPLY sys.dm_exec_text_query_plan(req.plan_handle,0,-1) as TextPlan
                            where req.session_id <> @@SPID"

  $orderBy = ReadConfigFile("orderby")
  if(TestEmpty($orderBy))
  {
   $orderBy=" order by req.database_id"
  }
  $command.CommandText = $command.CommandText + " " + $orderBy
  
  $Reader = $command.ExecuteReader(); 
  
  If($Reader.HasRows)
  {
    $ViewType = ReadConfigFile("ViewType")
    if(TestEmpty($ViewType))
    {
      $ViewType="ALL"
    }

     If($ViewType -eq "ALL")
     {
      for ($iColumn=0; $iColumn -lt $Reader.FieldCount; $iColumn++) 
      {
        $Tmp = [ColumnsToExport]::new()
        $Tmp.FieldName = $Reader.GetName($iColumn)
        $Tmp.Ordinal = $iColumn
        $Null = $ColumnExport.Add($Tmp)
      }
     }
     else
     {
      for ($iColumn=0; $iColumn -lt $Reader.FieldCount; $iColumn++) 
      {
       If($ViewType -like ("*#" + $Reader.GetName($iColumn).ToString().Trim() + "#*"))
       {
        $Tmp = [ColumnsToExport]::new()
        $Tmp.FieldName = $Reader.GetName($iColumn).ToString().Trim()
        $Tmp.Ordinal = $iColumn
        $Null = $ColumnExport.Add($Tmp)
       }
      }       
     }
  }
                    
  while($Reader.Read())
   {
    $RecordsAnalyzed=$RecordsAnalyzed+1
    Foreach($Tmp in $ReadDataLines)
    {
     if( Invoke-Expression $Tmp.Expression)
     {
      $RecordsRules=$RecordsRules+1
      $StringColumns="--> Rule " + $Tmp.RuleName
      logMsg($StringColumns) -ShowDate $false -Color 4 -NewLine $false -SaveFile $false

      
      for ($iColumn=0; $iColumn -lt $ColumnExport.Count; $iColumn++) 
      {
       logMsg($ColumnExport[$iColumn].FieldName + ":" ) -Color 3 -ShowDate $false -NewLine $false -SaveFile $false
       $StringColumns=$StringColumns+$ColumnExport[$iColumn].FieldName + ":"
       $Temporal = $Reader.GetValue($ColumnExport[$iColumn].Ordinal).ToString()
       If(TestEmpty($Temporal)) {$Temporal = ""}
       $Temporal = $Temporal.Replace("\t"," ").Replace("\n"," ").Replace("\r"," ").Replace("\r\n","").Trim() + " || "
       logMsg($Temporal) -ShowDate $false -NewLine $false -SaveFile $false
       $StringColumns=$StringColumns+$Temporal
      }

      logMsg($StringColumns) -Show $false -ShowDate $false
      logMsg("-->") -ShowDate $false -Color 4 -SaveFile $false
     }
    }
   }
   $Reader.Close();
   logMsg("(Records Analyzed " + $RecordsAnalyzed.ToString() + " With Rules: " + $RecordsRules.ToString() + ") - Number of Rules:" + $ReadDataLines.Count.ToString() ) -Color 5 -SaveFile $false
  }
  catch
   {
    logMsg( "Not able to run Checking Status per Requests..." + $Error[0].Exception) (2)
   } 
}

#--------------------------------------
#Read the configuration file
#--------------------------------------
Function ReadConfigFile
{ 
    Param
    (
         [Parameter(Mandatory=$false, Position=0)]
         [string] $Param
    )
  try
   {

    $return = ""

    If(TestEmpty($Param))
    {
     return $return
    }

    $stream_reader = New-Object System.IO.StreamReader($FileConfig)
    while (($current_line =$stream_reader.ReadLine()) -ne $null) ##Read the file
    {
     If(-not (TestEmpty($current_line)))
     {
      $Text = GiveMeSeparator $current_line "="
      if($Text.Text -eq $Param )
      {
       $return = $Text.Remaining;
       break;
      }
     }
    }
    $stream_reader.Close()
    return $return
   }
 catch
 {
   logMsg("Error Reading the fules files..." + $Error[0].Exception) (2) 
   return ""
 }
}


#----------------------------------------------------------------
#Function to connect to the database using a retry-logic
#----------------------------------------------------------------

Function GiveMeConnectionSource()
{ 
  $NumberAttempts= ReadConfigFile("RetryLogicNumberAttempts")
  for ($i=1; $i -lt [int]$NumberAttempts; $i++)
  {
   try
    {
      logMsg( "Connecting to the database..." + $Db + ". Attempt #" + $i + " of " + $NumberAttempts) (1) -SaveFile $false
      $SQLConnection = New-Object System.Data.SqlClient.SqlConnection 
      $SQLConnection.ConnectionString = "Server="+$(ReadConfigFile("server"))
      $SQLConnection.ConnectionString = $SQLConnection.ConnectionString + ";Database="+$(ReadConfigFile("Db"))
      $SQLConnection.ConnectionString = $SQLConnection.ConnectionString + ";User ID="+ $(ReadConfigFile("user"))
      $SQLConnection.ConnectionString = $SQLConnection.ConnectionString + ";Password="+$(ReadConfigFile("password"))
      $SQLConnection.ConnectionString = $SQLConnection.ConnectionString + ";Connection Timeout="+$(ReadConfigFile("ConnectionTimeout"))
      $SQLConnection.ConnectionString = $SQLConnection.ConnectionString + ";Application Name="+$(ReadConfigFile("ApplicationName"))
      $SQLConnection.ConnectionString = $SQLConnection.ConnectionString + ";ConnectRetryCount=3"
      $SQLConnection.ConnectionString = $SQLConnection.ConnectionString + ";ConnectRetryInterval=10"
      $SQLConnection.ConnectionString = $SQLConnection.ConnectionString + ";Max Pool Size=5"
      $SQLConnection.ConnectionString = $SQLConnection.ConnectionString + ";Min Pool Size=1"
      $SQLConnection.ConnectionString = $SQLConnection.ConnectionString + ";MultipleActiveResultSets=false"
      $SQLConnection.Open()
      logMsg("Connected to the database.." + $Db) (1) -SaveFile $false
      return $SQLConnection
      break;
    }
  catch
   {
    logMsg("Not able to connect - Retrying the connection..." + $Error[0].Exception) (2) -SaveFile $false
    Start-Sleep -s $(ReadConfigFile("RetryLogicNumberAttemptsBetweenAttemps"))
   }
  }
}

#--------------------------------------------------------------
#Create a folder 
#--------------------------------------------------------------
Function CreateFolder
{ 
  Param( [Parameter(Mandatory)]$Folder ) 
  try
   {
    $FileExists = Test-Path $Folder
    if($FileExists -eq $False)
    {
     $result = New-Item $Folder -type directory 
     if($result -eq $null)
     {
      logMsg("Imposible to create the folder " + $Folder) (2)
      return $false
     }
    }
    return $true
   }
  catch
  {
   return $false
  }
 }

#--------------------------------------
#Read the rules configuration file
#--------------------------------------
Function ReadRulesFile
{ 
 try
 {
  $stream_reader = New-Object System.IO.StreamReader($FileRules)

  while (($current_line =$stream_reader.ReadLine()) -ne $null) ##Read the file
  {
   If(-not (TestEmpty($current_line)))
   {
    $Tmp = [ReadDataLine]::new()
    $Tmp.ReadLine =  $current_line
    
    $Text = GiveMeSeparator $current_line ";"

    $Tmp.Field =  $Text.Text
    $Text = GiveMeSeparator $Text.Remaining ";"

    $Tmp.Operator =  $Text.Text
    $Text = GiveMeSeparator $Text.Remaining ";"

    $Tmp.Value =  $Text.Text
    $Text = GiveMeSeparator $Text.Remaining ";"

    $Tmp.RuleName =  $Text.Text

    if($Tmp.Field -ne "ALL")
    {
      $Tmp.Expression = "`$" + "Reader.GetValue(`$" + "Reader.GetOrdinal(" + [char]34 + $Tmp.Field + [char]34 + ")) " + $Tmp.Operator + " " + $Tmp.Value
    }
    else
    {
      $Tmp.Expression = "1 -eq 1"
    }
    $ReadDataLines.Add($Tmp) | Out-Null
   }
  }
  $stream_reader.Close()
 }
 catch
 {
   logMsg("Error Reading the fules files..." + $Error[0].Exception) (2) 
 }
}
#-------------------------------
#Create a folder 
#-------------------------------
Function DeleteFile{ 
  Param( [Parameter(Mandatory)]$FileName ) 
  try
   {
    $FileExists = Test-Path $FileNAme
    if($FileExists -eq $True)
    {
     Remove-Item -Path $FileName -Force 
    }
    return $true 
   }
  catch
  {
   return $false
  }
 }

#-------------------------------
#Create the rule file with the default rule
#-------------------------------

Function CreateRuleFile{ 
  Param( [Parameter(Mandatory)]$FileName ) 
  try
   {
    If(TestEmpty($FileName)) 
     { 
       return $false
     }
    If(FileExist($FileName)) 
     { 
       return $true 
     }

    $stream_write = New-Object System.IO.StreamWriter($FileName,$false, [Text.Encoding]::UTF8)
    $stream_write.WriteLine( 'ALL;ALL;ALL;"All Queries"')
    $stream_write.Close()
    return $true
   }
  catch
  {
   return $false
  }
}

#-------------------------------
#Create the config file with the default values
#-------------------------------

Function CreateConfigFile{ 
  Param( [Parameter(Mandatory)]$FileName ) 
  try
   {
    If(TestEmpty($FileName)) 
     { 
       return $false
     }
    If(FileExist($FileName)) 
     { 
       return $true 
     }

    $stream_write = New-Object System.IO.StreamWriter($FileName,$false, [Text.Encoding]::UTF8)
    $stream_write.WriteLine("server=servername.database.windows.net")
    $stream_write.WriteLine("user=username")
    $stream_write.WriteLine("password=password")
    $stream_write.WriteLine("Db=databasename")
    $stream_write.WriteLine("ApplicationName=Application SQL Monitoring")
    $stream_write.WriteLine("RetryLogicNumberAttempts=10")
    $stream_write.WriteLine("RetryLogicNumberAttemptsBetweenAttemps=5")
    $stream_write.WriteLine("ConnectionTimeout=60")
    $stream_write.WriteLine("CommandTimeout=3600")
    $stream_write.WriteLine("SecondsToWait= 5")
    $stream_write.WriteLine("orderby=order by req.database_id")
    $stream_write.WriteLine("ViewType=ALL")
    $stream_write.WriteLine("MaxLenStatement=4000")


    $stream_write.Close()
    return $true
   }
  catch
  {
   return $false
  }
}


#-------------------------------
#File Exists
#-------------------------------
Function FileExist{ 
  Param( [Parameter(Mandatory)]$FileName ) 
  try
   {
    $return=$false
    $FileExists = Test-Path $FileName
    if($FileExists -eq $True)
    {
     $return=$true
    }
    return $return
   }
  catch
  {
   return $false
  }
 }

#--------------------------------
#Log the operations
#--------------------------------
function logMsg
{
    Param
    (
         [Parameter(Mandatory=$false, Position=0)]
         [string] $msg,
         [Parameter(Mandatory=$false, Position=1)]
         [int] $Color,
         [Parameter(Mandatory=$false, Position=2)]
         [boolean] $Show=$true,
         [Parameter(Mandatory=$false, Position=3)]
         [boolean] $ShowDate=$true,
         [Parameter(Mandatory=$false, Position=4)]
         [boolean] $SaveFile=$true,
         [Parameter(Mandatory=$false, Position=5)]
         [boolean] $NewLine=$true 
 
    )
  try
   {
    If(TestEmpty($msg))
    {
     $msg = " "
    }


    if($ShowDate -eq $true)
    {
      $Fecha = Get-Date -format "yyyy-MM-dd HH:mm:ss"
    }
    $msg = $Fecha + " " + $msg
    If($SaveFile -eq $true)
    {
      Write-Output $msg | Out-File -FilePath $LogFile -Append
    }
    $Colores="White"
    $BackGround = 
    If($Color -eq 1 )
     {
      $Colores ="Cyan"
     }
    If($Color -eq 3 )
     {
      $Colores ="Yellow"
     }
    If($Color -eq 4 )
     {
      $Colores ="Green"
     }
    If($Color -eq 5 )
     {
      $Colores ="Magenta"
     }

     if($Color -eq 2 -And $Show -eq $true)
      {
         if($NewLine)
         {
           Write-Host -ForegroundColor White -BackgroundColor Red $msg 
         }
         else
         {
          Write-Host -ForegroundColor White -BackgroundColor Red $msg -NoNewline
         }
      } 
     else 
      {
       if($Show -eq $true)
       {
        if($NewLine)
         {
           Write-Host -ForegroundColor $Colores $msg 
         }
        else
         {
           Write-Host -ForegroundColor $Colores $msg -NoNewline
         }  
       }
      } 


   }
  catch
  {
    Write-Host $msg 
  }
}

#--------------------------------
#The Folder Include "\" or not???
#--------------------------------

function GiveMeFolderName([Parameter(Mandatory)]$FolderSalida)
{
  try
   {
    $Pos = $FolderSalida.Substring($FolderSalida.Length-1,1)
    If( $Pos -ne "\" )
     {return $FolderSalida + "\"}
    else
     {return $FolderSalida}
   }
  catch
  {
    return $FolderSalida
  }
}

#--------------------------------
#Validate Param
#--------------------------------
function TestEmpty($s)
{
if ([string]::IsNullOrWhitespace($s))
  {
    return $true;
  }
else
  {
    return $false;
  }
}

#--------------------------------
#Separator
#--------------------------------

function GiveMeSeparator
{
Param([Parameter(Mandatory=$true)]
      [System.String]$Text,
      [Parameter(Mandatory=$true)]
      [System.String]$Separator)
  try
   {
    [hashtable]$return=@{}
    $Pos = $Text.IndexOf($Separator)
    $return.Text= $Text.substring(0, $Pos) 
    $return.Remaining = $Text.substring( $Pos+1 ) 
    return $Return
   }
  catch
  {
    $return.Text= $Text
    $return.Remaining = ""
    return $Return
  }
}

Function Remove-InvalidFileNameChars {

param([Parameter(Mandatory=$true,
    Position=0,
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
    [String]$Name
)

return [RegEx]::Replace($Name, "[{0}]" -f ([RegEx]::Escape([String][System.IO.Path]::GetInvalidFileNameChars())), '')}


#--------------------------------
#Run the process
#--------------------------------

try
{
Clear

Class ReadDataLine
{
    [string]$ReadLine = ""
    [string]$Field = ""
    [string]$Operator = ""
    [string]$Value = ""
    [string]$Expression = ""
    [string]$RuleName = ""
}

Class ColumnsToExport
{
    [int]$Ordinal = 0
    [string]$FieldName = ""
}

$invocation = (Get-Variable MyInvocation).Value
$Folder = Split-Path $invocation.MyCommand.Path
$sFolderV = GiveMeFolderName($Folder) #Creating a correct folder adding at the end \.
$LogFile = $sFolderV + "PerfSqlMonitoring.Log"                  #Logging the operations.
$FileRules = $sFolderV + "Rules.Txt"
$FileConfig = $sFolderV + "Config.Txt"

logMsg("Deleting Logs") (1) -SaveFile $false
   $result = DeleteFile($LogFile)         #Delete Log file

logMsg("Creating the rules if needed") (1) -SaveFile $false
   $result = CreateRuleFile($FileRules)   #Creating the log file

logMsg("Creating the config file if needed") (1) -SaveFile $false
   $result = CreateConfigFile($FileConfig)   #Creating the log file


   
   $ReadDataLines = [System.Collections.ArrayList]::new() 
  
    while(1 -eq 1)
    { 
     clear
     logMsg -msg "Running the SQL Performance Live Monitor..." -Color 5
     ReadRulesFile
     $SQLConnectionSource = GiveMeConnectionSource #Connecting to the database.
     if($SQLConnectionSource -eq $null)
     { 
         logMsg("SQL Performance Monitor - is not possible to connect to the database " + $Db ) (2)
         exit;
     }
      CheckStatusPerRequestAdHoc $SQLConnectionSource 
     $SQLConnectionSource.Close() 
     logMsg("Closed the connection from the database..") (1) -SaveFile $false
     [int]$SecondsToWait =  ReadConfigFile("SecondsToWait")
     logMsg("Waiting " + $SecondsToWait.ToString() + " seconds for next cycle") -Color 1 -ShowDate $false -SaveFile $false -NewLine $false
     For([int]$i=1;$i -le $SecondsToWait;$i=$i+1)
      {
        logMsg(".") -Color 1 -ShowDate $false -SaveFile $false -NewLine $false
        $Null = Start-Sleep -Seconds 1 ##| Out-Null
      }
        $ReadDataLines.Clear()
    }   

}
catch
  {
    logMsg("SQL Performance Monitor Script was executed incorrectly ..: " + $Error[0].Exception) (2)
  }
finally
{
   logMsg("SQL Performance Monitor Script finished - Check the previous status line to know if it was success or not") (1)
} 
