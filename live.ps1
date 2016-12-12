#Requires -RunAsAdministrator



# Written by Stian Petersen
# Version 1.0, 09/12-2016
# The purpose of this script is to capture volatile data from a live system. It is designed to be fully automatic 
# without any userinteraction or knowledge by the user other than starting the script
# Limits: The script has to be run as administrator. The script does NOT check if the media it is copying to is large enough for the files it tried to copy.
# Script is tested on powershell 5.0 on windows 10 Pro            





# Licence:
# This script can be used under the terms of GNU GENERAL PUBLIC LICENSE.
# The script makes use of dd for windows and winpmem 1.6.2 which are licenced under GNU GENERAL PUBLIC LICENSE.

 


# Function to copy mounted volumes with robocopy
function imageMountedVolume{
    Write-Host "`nSearching for possible encrypted mounted volumes"
    $hasCreatedHeader = $False
    $destinationFolder = "$caseFolder\PossibleEncyptedVolumes"
    New-Item $destinationFolder -type directory -force | Out-Null # Make directory to copy to

    $allVolumes = Get-WmiObject Win32_logicaldisk | Select-Object -ExpandProperty deviceID
    $nonVHDvolumes = get-volume | select-object -ExpandProperty  DriveLetter

    

    foreach ($volume in $allVolumes){
        $volume = $volume  -replace '[:]'
        if ($nonVHDvolumes -notcontains $volume){
            Write-Host "`nFound mounted virtual hard drive $volume`:"
            Write-Host "Creating image of drive $volume`:  Please wait..."
            $executeStart = Get-Date -Format "yyyy-MM-dd HH.mm.ss"
            $ddPath = "$scriptPath\bin\dd.exe" 
            $ddPath = $ddPath -replace ":\\", ":\"
            # Execute dd.exe to copy the volume
            &"$ddPath" "if=\\.\$volume`:" "of=$caseFolder\PossibleEncyptedVolumes\Volume_$volume.raw"  | Out-Null
            $executeEnd = Get-Date -Format "yyyy-MM-dd HH.mm.ss"
            Write-Host "Done"

            # Write header to report front page
            if (!$hasCreatedHeader){
               "<br><br><H3>Possible Encypted Mounted Volumes`:</H3>" | Out-File -append $Report
               $hasCreatedHeader = $True
            }

            # Add volume info to array for logging
            $cmd="$ddPath if=\\.\$volume`: of=$caseFolder\PossibleEncyptedVolumes\Volume_$volume.raw"
            $script:volumesArray += ,("$cmd", "$executeStart", "$executeEnd")

            "<b>Volume $volume</b><br>" | Out-File -append $Report
            "Image Start time: $executeStart<br>" | Out-File -append $Report
            "Image finished time: $executeEnd<br><br>" | Out-File -append $Report
        }
    }
}

# Function capturing Run with winpmem
function captureRam{
    Write-Host "`nCaputring RAM. Please wait..." 
    $destinationFolder = "$caseFolder\RAM"
    New-Item $destinationFolder -type directory -force | Out-Null # Create directory to copy to
    $script:ramExecuteStart = Get-Date -Format "yyyy-MM-dd HH.mm.ss"
    & "$scriptPath\bin\winpmem_1.6.2.exe" "$destinationFolder\ramCapture.raw" "-p"  | Out-Null
    $script:ramExecuteEnd = Get-Date -Format "yyyy-MM-dd HH.mm.ss"
    Write-Host "RAM capture complete`n" 
    "<br><br><H3>Memory`:</H3>" | Out-File -append $Report
    "RAM capture Start time: $ramExecuteStart<br>" | Out-File -append $Report
    "RAM capture finished time: $ramExecuteEnd<br><br>" | Out-File -append $Report
}

# Function creating html header for the reports
function createHtmlHeader($title, $executeStart){
$header = "
<header> 
    <style>
        TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}
        TH{border-width: 1px;padding: 0px;border-style: solid;border-color: black; background-color: #6495ED;}
        TD{border-width: 1px;padding: 0px;border-style: solid;border-color: black;}
        tr:nth-child(even) {
            background-color: #dddddd;
        }d; }
    </style>
    <Title>$title</Title>
    <br><br>
    <H2>$title</H2>"
    if($executeStart){
        "<h4>Start time: $executeStart</h4>"
    }
"</Header>"
return $header
}

# Function gathering volatile data
function gatherVolatileSystemInformation{
    Write-Host "`nGathering volatile system information"    

    # Create folder for system reports
    $destinationFolder = "$caseFolder\SystemInformation"
    New-Item $destinationFolder -type directory -force | Out-Null # Make directory to store html files with SystemInformation
    "<h3>Volatile system information:</h3>"| Out-File -append $Report


    # Netstat    
    $script:netstatExecuteStart = Get-Date -Format "yyyy-MM-dd HH.mm.ss"
    $netstat = Netstat -ano | ConvertFrom-String -PropertyNames " ", "Proto", "Local Address", "Foreign Address", "State", "PID" | select-object "Proto", "Local Address", "Foreign Address", "State", "PID" | select -skip 2
    $script:netstatExecuteend = Get-Date -Format "yyyy-MM-dd HH.mm.ss"
    $NetstatHeader = createHtmlHeader("Netstat", "$netstatExecuteStart")
    $netstat | ConvertTo-html -head $NetstatHeader | Add-Content -Path "$destinationFolder\Netstat.html", "$destinationFolder\combined.html"
    "<a href='SystemInformation\netstat.html'>Netstat</a><br>" | Out-File -append $Report

    # Arp table
    $script:arpExecuteStart = Get-Date -Format "yyyy-MM-dd HH.mm.ss"
    $arp = arp -a |  ConvertFrom-String  -PropertyNames "Interface", "Internet Address", "Physical Address","Type"  |select-object "Interface", "Internet Address", "Physical Address","Type" 
    $script:arpExecuteEnd = Get-Date -Format "yyyy-MM-dd HH.mm.ss"
    $arpHeader = createHtmlHeader("Arp Table", $arpExecuteStart)
    $arp | ConvertTo-html -head $arpHeader | Add-Content -Path "$destinationFolder\ArpTable.html", "$destinationFolder\combined.html"
    "<a href='SystemInformation\ArpTable.html'>Arp Table</a><br>" | Out-File -append $Report

    # List processes
    $script:procExecuteStart = Get-Date -Format "yyyy-MM-dd HH.mm.ss"
    $runningProcesses = Get-Process | Select-Object StartTime, Handle, Name, CPU, Id, SI, Path
    $script:procExecuteEnd = Get-Date -Format "yyyy-MM-dd HH.mm.ss"
    $processHeader = createHtmlHeader("Running Processes", $procExecuteStart)
    $runningProcesses | ConvertTo-html -head $processHeader  |  Add-Content -Path "$destinationFolder\RunningProcesses.html", "$destinationFolder\combined.html"
    "<a href='SystemInformation\RunningProcesses.html'>Running Processes</a><br>" | Out-File -append $Report

    # Combined report
    "<a href='SystemInformation\combined.html'>Combined Report For Printing</a><br>" | Out-File -append $Report

    Write-Host "Done"
}

# Write log of the commands executed
function writeLog($title, $executeStart){
    "<br><h3>Command Log:</h3>"| Out-File -append $Report
    "<table>
    <colgroup><col/><col/><col/></colgroup>
    <tr><th>Command</th><th>Execute Start</th><th>Execute End</th></tr>
    <tr><td>Netstat -ano </td><td> $netstatExecuteStart </td><td> $netstatExecuteEnd </td></tr>
    <tr><td>arp -a</td><td> $arpExecuteStart </td><td> $arpExecuteEnd </td></tr>
    <tr><td>Get-Process | Select-Object StartTime, Handle, Name, CPU, Id, SI, Path</td><td> $procExecuteStart </td><td> $procExecuteEnd </td></tr>" | Out-File -append $Report
    # Loop through copied volumes
    foreach ($volumeX in $volumesArray){
        $cmd,$start,$end = $volumeX
        "<tr><td>$cmd</td><td> $start </td><td> $end </td></tr>" | Out-File -append $Report
    }
    "<tr><td>$scriptPath`bin\winpmem_1.6.2.exe $caseFolder\RAM\ramCapture.raw -p</td><td> $ramExecuteStart </td><td> $ramExecuteEnd </td></tr>" | Out-File -append $Report
    "</table>" | Out-File -append $Report
}


#Get script folder
$scriptPath = Split-Path -parent $PSCommandPath

#Run script in order from most volatile to least volatile
$scriptExecuteStart = Get-Date -Format "yyyy-MM-dd HH.mm.ss"
$script:caseFolder = "$scriptPath\$scriptExecuteStart"
Write-Host "casefolder: $caseFolder"
New-Item "$caseFolder" -type directory -force | Out-Null #Create case folder
$Report = "$caseFolder\Report.html" 
New-Item "$Report" -type file -force | Out-Null #Create Report file
Write-Host "`nScript started $scriptExecuteStart"

$reportHeader = createHtmlHeader("Report $scriptExecuteStart")
$reportHeader | Out-File -append $Report

# Execute functions:
gatherVolatileSystemInformation
imageMountedVolume
captureRam
writeLog

$scriptExecuteEnd = Get-Date -Format "yyyy-MM-dd HH.mm.ss"
Write-Host "Script complete $scriptExecuteEnd`n"






