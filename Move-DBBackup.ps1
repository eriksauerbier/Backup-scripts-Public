# Backup-Skript f�r Datenbank-Backups
# Stannek GmbH - v.1.0 - 25.07.2022 - E.Sauerbier

#Parameter
$DeletionDay = "31" # legt fest ab welchen Dateialter die Backups gel�scht werden
$ScriptPath = "C:\Skripte\"
$ScriptName = $MyInvocation.MyCommand.Name
$TaskName = "DB Backup"
$BackupStartTime = "7pm"
$TaskDescription = "Verschieben des DB-Backups"
# Quellpfade festlegen
$DBBackupPath = "C:\Pfad zu DB-Sicherung"
# Zielpfad festlegen
$DestinationBackupPath="\\zielsystem\backup"

# Assembly f�r Hinweisboxen laden
[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

# Task pr�fen und ggf. anlegen

If (!(Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue)) {
    # Task nicht vorhanden, wird nun angelegt

    # Pr�fen ob Skript auf im richtigen Pfad liegt
     if (!(Test-Path "$ScriptPath\$ScriptName")){
     $msg = "Das Skript f�r den Task liegt nicht unter $ScriptPath `nBitte Skript dort ablegen und nochmal starten"
     $Header = "Das Skript f�r den Task fehlt"
     $Exclamation = [System.Windows.Forms.MessageBoxIcon]::Warning
     [System.Windows.Forms.Messagebox]::Show($msg,$header,1,$Exclamation)
     break
     }
    # Credentials f�r den Task abfragen
    $TaskCred = Get-Credential -Message "Bitte Benutzer mit Dom�nenkennung eingeben (z.B. dom\User)" 

    # Abgefragte Credentials pr�fen, wenn falsch Skript beenden
    $CurrentDomain = "LDAP://" + ([ADSI]"").distinguishedName
    $TestDomain = New-Object System.DirectoryServices.DirectoryEntry($CurrentDomain,($TaskCred.UserName),($TaskCred.GetNetworkCredential().Password))
    if ($TestDomain.name -eq $null) 
        {$msg = "Die eingegebene Benutzerkennung ist falsch"
         $Header = "Falsche Credentials"
         $Exclamation = [System.Windows.Forms.MessageBoxIcon]::Error
         [System.Windows.Forms.Messagebox]::Show($msg,$header,1,$Exclamation)
         break
        }

    # Task anlegen
    $TaskArgument = "-ExecutionPolicy Bypass -File " + $Scriptpath + $ScriptName
    $TaskAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $TaskArgument
    $TaskTrigger = New-ScheduledTaskTrigger -Daily -At $BackupStartTime
    $TaskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable -ExecutionTimeLimit 02:00:00
    $Task = New-ScheduledTask -Action $TaskAction -Trigger $TaskTrigger -Settings $TaskSettings -Description $TaskDescription
    Register-ScheduledTask $TaskName -InputObject $Task -User $TaskCred.Username -Password $TaskCred.GetNetworkCredential().Password
    
    # Task starten
    Start-ScheduledTask -TaskName $TaskName

    # Info Ausgeben
    $msg = "Der Backup-Taks f�r das DB-Backup wurde angelegt und gestartet `nBitte Backup-Pfad nach aktuellen Backups pr�fen"
    $Header = "Der Backup-Task wurde angelegt"
    $Exclamation = [System.Windows.Forms.MessageBoxIcon]::Information
    [System.Windows.Forms.Messagebox]::Show($msg,$header,0,$Exclamation)

    # Ziel-Backup-Pfad zum Pr�fen �ffnen
    explorer.exe $DestinationBackupPath

    # Skript beenden
    break
    }


# Backups zum Zielpfad verschieben/kopieren
Move-Item -Path (Get-ChildItem -Path $DBBackupPath).FullName  -Destination $DestinationBackupPath -Force

# Alte Backup-Dateien l�schen
Get-ChildItem -Path $DestinationBackupPath -Recurse | Where-Object {($_.LastWriteTime -lt (Get-Date).AddDays(-$DeletionDay))} | Remove-Item -Force