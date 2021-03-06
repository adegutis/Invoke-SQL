﻿Function Invoke-SQL {

    <#
    .Synopsis

     Executes SQL command using the SQLPS module if it is installed, otherwise it falls back to using native SMO commands

    .Description

     Executes SQL command using the SQLPS module if it is installed, otherwise it falls back to using native SMO commands. Requires that SQL SMO is installed on the server running the function.
 
    .Parameter SQLInstance

     The SQL instance name to be used
     
    .Parameter DatabaseName

     The database to execute the SQL commands against  

    .Parameter SQLQuery

     The SQL command(s) to execute

    .Parameter 

    .Example

    $SQLQuery = 'SELECT * FROM servers'
    $Results = Invoke-SQL -SQLInstance 'Server\Instance' -Database 'SaaSops' -SQLQuery $SQLQuery
    
    .Example

    Invoke-SQL -SQLInstance 'Server\Instance' -Database 'SaaSops' -SQLQuery $SQLQuery

    .Example

    $SQLQuery = 'SELECT * FROM servers'
    $SQLInstance = 'Server\Instance'
    $Database = 'SaaSops'
    $User = 'User1'
    $Password = 'Password'
    $Results = Invoke-SQL -SQLInstance $SQLInstance -Database $Database -SQLQuery $SQLQuery -SQLStatementTimeout 60 -SQLUser $user -SQLPassword $Password

    .Notes

    #>


    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$SQLInstance,
        [Parameter(Mandatory = $true)][string]$DatabaseName,
        [Parameter(Mandatory = $true)][string]$SQLQuery, 
        [Parameter(Mandatory = $false)]$SQLStatementTimeout = 600, # 10 minute default
        [Parameter(Mandatory = $false)][string]$SQLUser,
        [Parameter(Mandatory = $false)][string]$SQLPassword
    )
    # try using .NET Class for the SQL Connection
    $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
    if ($SqlConnection) {
        if ($SQLUser -and $SQLPassword) {
            $SqlConnection.ConnectionString = "Server=$SQLInstance;Database=$DatabaseName;Integrated Security=False;User ID='$SQLUser';Password='$SQLPassword';"
        } else {
            $SqlConnection.ConnectionString = "Server=$SQLInstance;Database=$DatabaseName;Integrated Security=True;"
        }

        try {
            $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
            $SqlCmd.CommandTimeout = $SQLStatementTimeout
            $SqlCmd.CommandText = $SQLQuery 
            $SqlCmd.Connection = $SqlConnection
            $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
            $SqlAdapter.SelectCommand = $SqlCmd
            $DataSet = New-Object System.Data.DataSet
            $SqlAdapter.Fill($DataSet) | Out-Null
            $SqlConnection.Close()
            $Results = $DataSet.Tables[0]
        } Catch {
            $Error[0] | Format-List -force
        }
    } elseif (Get-Module -ListAvailable -Name SQLPS) {
        if (!Get-Module -Name SQLPS ) {
            Import-Module SQLPS
        }
        if ($SQLUser -and $SQLPassword) {
            Invoke-Sqlcmd -ServerInstance $SQLInstance -Database $DatabaseName -Query $SQLQuery -QueryTimeout $SQLStatementTimeout -Username $SQLUser -Password $SQLPassword
        } else {
            Invoke-Sqlcmd -ServerInstance $SQLInstance -Database $DatabaseName -Query $SQLQuery -QueryTimeout $SQLStatementTimeout
        }
    } else {
        # SQLPS Module does not exist. Using SMO intead

        $SMO = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') 
        Add-Type -Path $SMO.Location
        $SMOExtended = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMOExtended')  
        Add-Type -Path $SMOExtended.Location

        $ConnectionSettings = New-Object Microsoft.SqlServer.Management.Common.ServerConnection
        $ConnectionSettings.ServerInstance = $SQLInstance 
        if ($SQLUser -and $SQLPassword) {
            $ConnectionSettings.LoginSecure = $false
            $ConnectionSettings.Login = $SQLUser
            $ConnectionSettings.Password = $SQLPassword
        } else {
            $ConnectionSettings.LoginSecure = $true
        }
        $Instance = New-Object Microsoft.SqlServer.Management.Smo.Server($ConnectionSettings)
        $instance.ConnectionContext.StatementTimeout = $SQLStatementTimeout
        $Database = $Instance.Databases.Item($DatabaseName);  
        try {
            $SQLResult = $Database.ExecuteWithResults($SQLQuery);
            $Results = $SQLResult.Tables[0];
        } catch {
            $Error[0] | Format-List -force
        }
    }
    Write-Output $Results

} # End Function Invoke-SQL

