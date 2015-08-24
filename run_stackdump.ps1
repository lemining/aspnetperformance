param(
    $AppPoolName = "AppPoolName" ,
    $SleepSeconds = 10,
    $Repeats = 10,
    $Reason = "No reason",
    $CPUThreshold = 0 #Kick off right away
)

Import-Module WebAdministration

$Path = split-path -parent $MyInvocation.MyCommand.Definition
$nameOfTool = "Stackdump.exe"

$PathsToTool = @(Get-ChildItem -Recurse -Filter $nameOfTool (Join-Path $Path "Tools")) | Where-Object { -not $_.FullName.Contains("Net2") }

if($PathsToTool.Count -eq 0){
    Write-Output "Unable to find Stackdump.exe. Download from http://stackdump.codeplex.com/ and put in Tools folder."
    exit 1
}

# Test if 64bit system
# Found on https://social.technet.microsoft.com/Forums/windowsserver/en-US/5dfeb3ab-6265-40cd-a4ac-05428b9db5c3/determine-32-or-64bit-os
if ([System.IntPtr]::Size -eq 4) { 
    $tool = $PathsToTool | Where-Object { $_.FullName.Contains("x86") }
} else { 
    $tool = $PathsToTool | Where-Object { $_.FullName.Contains("x64") }
}

if($CPUThreshold -gt 0){
    while(($cpu = Get-WmiObject win32_processor | Measure-Object -property LoadPercentage -Average | Select Average).Average -lt $CPUThreshold){
        Write-Output "Waiting 5 seconds for CPU to raise above $CPUThreshold"
        Start-Sleep -Seconds 5
    }
}else{
    Write-Output "No CPU threshold specified. Collecting stack dumps now"
}

$ProcessPid = dir IIS:\AppPools\$AppPoolName\WorkerProcesses | %{ $_.processId }

if($ProcessPid -eq 0 -or $ProcessPid -eq $null){
    Write-Output "Unable to find $AppPoolName pool in IIS. Please pass in or set as default"
    exit 
}

$d = Get-Date -Format "yyMMdd_hhmmss"
mkdir $d

# A very basic way of recording our current settings
"Reason: " + $Reason > (join-path $d "settings.txt")
"Repeats: " + $Repeats >> (join-path $d "settings.txt")
"SleepSeconds: " + $SleepSeconds >> (join-path $d "settings.txt")
"AppPool: " + $AppPoolName >> (join-path $d "settings.txt")

for($i=1; $i -le $Repeats; $i++){
    $cpu = Get-WmiObject win32_processor | Measure-Object -property LoadPercentage -Average | Select Average
    $filename = ("$AppPoolName" + "_" + $i + "_cpu" + ($cpu.Average) +".txt")
    
    & $tool.FullName $ProcessPid > (join-path $d $filename)
    Start-Sleep -Seconds $SleepSeconds
}