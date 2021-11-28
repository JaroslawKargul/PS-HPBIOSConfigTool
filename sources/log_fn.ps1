$GLOBAL:_Log_File = $null
$GLOBAL:_Log_Path = $null
$GLOBAL:_Log_FullPath = $null

function CurrentDate(){
    $date = (Get-Date -Format "HH:mm:ss dd/MM/yyyy" | Out-String).Trim()
    return $date
}

function AddMainLogEntry($line){
    if ($line -ne $null -and $GLOBAL:_Log_File -ne $null){
        $date = CurrentDate
        echo "`[$date`] `/`/===========================================================" | Out-File $GLOBAL:_Log_FullPath -Append -ErrorAction SilentlyContinue
        echo "`[$date`] `|`| $line" | Out-File $GLOBAL:_Log_FullPath -Append -ErrorAction SilentlyContinue
        echo "`[$date`] `\`\===========================================================" | Out-File $GLOBAL:_Log_FullPath -Append -ErrorAction SilentlyContinue
    }
}

function AddLogEntry($line){
    if ($line -ne $null -and $GLOBAL:_Log_File -ne $null){
        $date = CurrentDate
        echo "`[$date`] $line" | Out-File $GLOBAL:_Log_FullPath -Append -ErrorAction SilentlyContinue
    }
}

function FinishLog($exitcode){
    if ($GLOBAL:_Log_File -ne $null){
        $date = CurrentDate
        echo "`[$date`] `/`/===========================================================" | Out-File $GLOBAL:_Log_FullPath -Append -ErrorAction SilentlyContinue
        echo "`[$date`] `|`| ENDING SCRIPT WITH VALUE: $exitcode" | Out-File $GLOBAL:_Log_FullPath -Append -ErrorAction SilentlyContinue
        echo "`[$date`] `\`\===========================================================" | Out-File $GLOBAL:_Log_FullPath -Append -ErrorAction SilentlyContinue
    }
}

function ResetLogFile(){
    if ($GLOBAL:_Log_File -ne $null){
        Clear-Content -Path $GLOBAL:_Log_FullPath -Force -ErrorAction SilentlyContinue
    }
}

function CreateLogFile($logpath, $logname, $logappend, $scriptname){
    if ($logname -ne $null -and $logpath -ne $null){
        $GLOBAL:_Log_Path = $logpath
        $GLOBAL:_Log_FullPath = "$logpath`\$logname"
        $GLOBAL:_Log_File = $logname

        if ((Test-Path $logpath) -ne $true){
            New-Item -ItemType File -Force -Path $GLOBAL:_Log_FullPath -ErrorAction SilentlyContinue | Out-Null
        }

        if ($logappend -ne $true){
            ResetLogFile
        }

        AddMainLogEntry "STARTING SCRIPT: $scriptname"
    }
}