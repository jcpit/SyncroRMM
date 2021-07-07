#Your task name for the Task Scheduler
$TaskName="CustomTaskName"

#Specifies how long the Task Scheduler will attempt to restart the task. The format for this string is PDTHMS (for example, "PT5M" is 5 minutes, "PT1H" is 1 hour, and "PT20M" is 20 minutes
$ScriptInterval="PT1M"

# To run the script as user or system
$ScriptContext="System" #Run as system
#$ScriptContext="User" #Run as user32

function RunMyCode()
{
    Import-Module $env:SyncroModule -WarningAction SilentlyContinue
    
    #PUT YOUR CODE HERE
    Log-Activity -Message "Persistent script Triggered" -EventName "Test Event"
}

##############################################################################
#
#
# You should not need to modify below this line.
#
#
##############################################################################


function InstallScript()
{
    write-host "Installing Script..."
    if (!(test-path -path $PersistentScriptPath)) {new-item -path $PersistentScriptPath -itemtype directory}

    Copy-Item $CurrentScript $SourcePath -Force
    #If the script was updated, run it with orginal parameters
    $Trigger= New-ScheduledTaskTrigger -At 1:00am –Daily # Specify the trigger settings
    #$User= "NT AUTHORITY\SYSTEM" # Specify the account to run the script   
    
    if ($ScriptContext="User") {
		# Run as Current User      
        #$jobOption = New-ScheduledJobOption -MultipleInstancePolicy IgnoreNew

        #$jobTrigger = New-JobTrigger -AtLogon
        $jobTrigger = New-JobTrigger -AtStartup
        #$jobTrigger | Set-JobTrigger -RepetitionInterval (New-TimeSpan -Minutes 1) -RepetitionDuration (New-TimeSpan -Minutes 5)

        $newJob = Register-ScheduledJob -Name $TaskName -Trigger $jobTrigger -ScheduledJobOption $jobOption -FilePath $SourcePath

        $taskPrincipal = New-ScheduledTaskPrincipal -LogonType Interactive -UserId $env:USERNAME        
        Set-ScheduledTask -TaskPath '\Microsoft\Windows\PowerShell\ScheduledJobs\' -TaskName $($newJob.Name) -Principal $taskPrincipal

	} else {
		# Run as SYSTEM     
		$principal = New-ScheduledTaskPrincipal -LogonType ServiceAccount -UserID "NT AUTHORITY\SYSTEM" -RunLevel Highest 
	}       

    $Action= New-ScheduledTaskAction -Execute "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument "-ExecutionPolicy Bypass -file ""$SourcePath""" # Specify what program to run and with its parameters
    $Task = Register-ScheduledTask -TaskName $TaskName -Trigger $Trigger -Principal $principal -Action $Action  –Force # Specify the name of the task

    $Task.Triggers.Repetition.Duration = "P1D"
    $Task.Triggers.Repetition.Interval = $ScriptInterval

    $Task | Set-ScheduledTask
    write-host "Done."
}

$PersistentScriptPath="$Env:Programfiles\RepairTech\Syncro\PersistentScripts"
$SourcePath="$PersistentScriptPath\$TaskName.ps1"
$CurrentScript = $($MyInvocation.MyCommand.Source)
$ErrorLog="$PersistentScriptPath\Error.log"

$env:RepairTechApiBaseURL = "syncromsp.com"
$env:RepairTechApiSubDomain = (Get-ItemProperty "HKLM:SOFTWARE\WOW6432Node\RepairTech\Syncro").shop_subdomain
$env:RepairTechFilePusherPath = "C:\ProgramData\Syncro\bin\FilePusher.exe"
$env:RepairTechUUID = (Get-ItemProperty "HKLM:SOFTWARE\WOW6432Node\RepairTech\Syncro").uuid
$env:SyncroModule = "C:\ProgramData\Syncro\bin\module.psm1"


try {
    #check that the destination file exists
    if (!(Test-Path -path $SourcePath)) {

        #If the script is not running from the Persistent Scripts path then Install script.
        if (!($SourcePath -eq $CurrentScript ))
        {
            InstallScript
            Exit
        }

    } else {
        #If the script already exists but isn't running from the Persistent Scripts path then Update the script
        if (!($SourcePath -eq $CurrentScript ))
        {
            Write-host "Script Already Exists!"
            Write-host "Unregistering Task..."
 
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

            InstallScript
            Exit
        } else {

            #If the script is being run from the Persistent Scripts path then run our code.
            RunMyCode
            Exit
        }
    }
}
Catch
{
    $ErrorInfo = $_ | Out-String 
    "ERROR [$TaskName] $ErrorInfo" | Add-Content $ErrorLog
}