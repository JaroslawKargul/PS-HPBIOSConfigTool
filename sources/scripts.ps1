<#
.NOTES
Module Name  : BCU Front End for HP BIOS Config Utility tool
Created by   : Jaroslaw Kargul
Date Coded   : 08/09/2020
#>

param ($NotRetry)

#######################################
##########-PRE-START-LOGGING-##########
#######################################

. "$PSScriptRoot\log_fn.ps1"

$GLOBAL:FILEPATH = "$ENV:TEMP`\BCU"
$GLOBAL:FILEPATH |% { if (-not (Test-Path $_)){ New-Item -ItemType Directory -Path $ENV:TEMP -Name "BCU" }}

CreateLogFile $GLOBAL:FILEPATH "HP_BIOS_Configuration_Tool.log" $true "scripts.ps1"
AddLogEntry "Starting the HP BIOS Configuration Tool as user `"$ENV:USERNAME`" on computer `"$ENV:COMPUTERNAME`""


# This script cannot work without admin rights - stop executing if user doesn't have them
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")){
    if ($NotRetry){
        AddLogEntry "User does not have administrative rights on current machine."
        AddLogEntry "NotRetry parameter declares that we shouldn't try restarting again. Displaying an error message..."

        [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
        [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
        Add-Type -AssemblyName PresentationCore,PresentationFramework

        $ButtonType = [System.Windows.MessageBoxButton]::"OK"
        $MessageIcon = [System.Windows.MessageBoxImage]::"Error"
        $MessageBody = "This software requires administrator rights to run.`n`nRun this application as regular user and provide administrator credentials when prompted."
        $MessageTitle = "Error"
 
        $Result = [System.Windows.MessageBox]::Show($MessageBody,$MessageTitle,$ButtonType,$MessageIcon)
        $Result

        AddMainLogEntry "FINISHED THE APPLICATION WITH EXITCODE: 1"
    }
    else{
        AddLogEntry "User does not have administrative rights on current machine."
        AddLogEntry "NotRetry parameter not declared, trying to restart the script and ask for elevation..."
        Start-Process powershell.exe -WindowStyle Minimized "-NoProfile -ExecutionPolicy Bypass -Command `"& { . '$($MyInvocation.MyCommand.Source)' '1'; GenerateBIOS-Form }`"" -Verb RunAs
    }
    exit
}

#################################
##########-GLOBAL-VARS-##########
#################################

$GLOBAL:exportedCFGpath = "$FILEPATH\$($ENV:COMPUTERNAME)_export.cfg"
$GLOBAL:customCFGpath = "$FILEPATH\$($ENV:COMPUTERNAME)_custom.cfg"
$GLOBAL:BIOS_PWD_Path = "$FILEPATH\$($ENV:COMPUTERNAME)_pwd.bin"
$GLOBAL:BCU_Path = "$PSSCRIPTROOT`\BCU\BCU.exe"
$GLOBAL:BCUPW_Path = "$PSSCRIPTROOT`\BCU\BCUPW.exe"

$GLOBAL:PW = ""

$GLOBAL:SEARCHBOX = $null
$GLOBAL:ShouldSearch = $false
$GLOBAL:Passed_X_Coordinate = $null
$GLOBAL:Passed_Y_Coordinate = $null

$GLOBAL:PWBOX_WAS_CLOSED_WITH_CONTROLS = $false

$GLOBAL:CheckboxGroups = @()
$GLOBAL:CheckboxGroups_exceptions = @()

$GLOBAL:CheckboxGroups_InitButtonData = @()
$GLOBAL:CheckboxGroups_InitButtonData += @{a='b'}

$GLOBAL:ToolTip_object = $null
$GLOBAL:ToolTipList = $null

# Due to how checkboxes work, we have to implement a specific workaround...
$GLOBAL:Checkbox_to_check = $null
$GLOBAL:num_checkboxes_in_group = 0
$GLOBAL:num_checkboxes_in_group_temp = 0

# All errorcodes described by HP
$GLOBAL:BCU_ErrorTable = @{
    1 = "Setting not supported on the system. No changes to BIOS were made."
    2 = "Unknown error. No changes to BIOS were made."
    3 = "Operation timed out. No changes to BIOS were made."
    4 = "Operation failed. No changes to BIOS were made."
    5 = "Invalid parameter. No changes to BIOS were made."
    6 = "Access denied. No changes to BIOS were made."
    10 = "Invalid password. No changes to BIOS were made."
    11 = "Invalid config file. No changes to BIOS were made."
    12 = "Error in config file. No changes to BIOS were made."
    13 = "Failed to change one or more settings."
    14 = "Failed to write file. No changes to BIOS were made."
    15 = "Syntax error. No changes to BIOS were made."
    16 = "Unable to write to file/system. No changes to BIOS were made."
    17 = "Failed to change settings. No changes to BIOS were made."
    18 = "Unchanged setting. No changes to BIOS were made."
    19 = "One of settings is read-only. No changes to BIOS were made."
    20 = "Invalid setting name. No changes to BIOS were made."
    21 = "Invalid setting value. No changes to BIOS were made."
    23 = "Unsupported system. No changes to BIOS were made."
    24 = "Unsupported system. No changes to BIOS were made."
    25 = "Unsupported system. No changes to BIOS were made."
    30 = "Password file error. No changes to BIOS were made."
    31 = "Password not F10 compatible. No changes to BIOS were made."
    32 = "Unsupported Unicode password. No changes to BIOS were made."
    33 = "No settings found. No changes to BIOS were made."
    35 = "Missing parameter. No changes to BIOS were made."
    36 = "Missing parameter. No changes to BIOS were made."
    37 = "Missing parameter. No changes to BIOS were made."
    38 = "Corrupt or missing file. No changes to BIOS were made."
    39 = "DLL file error. No changes to BIOS were made."
    40 = "DLL file error. No changes to BIOS were made."
    41 = "Invalid UID. No changes to BIOS were made."
}


function Set-WindowStyle {
param(
    [Parameter()]
    [ValidateSet('FORCEMINIMIZE', 'HIDE', 'MAXIMIZE', 'MINIMIZE', 'RESTORE', 
                 'SHOW', 'SHOWDEFAULT', 'SHOWMAXIMIZED', 'SHOWMINIMIZED', 
                 'SHOWMINNOACTIVE', 'SHOWNA', 'SHOWNOACTIVATE', 'SHOWNORMAL')]
    $Style = 'SHOW',
    [Parameter()]
    $MainWindowHandle = (Get-Process -Id $pid).MainWindowHandle
)
    $WindowStates = @{
        FORCEMINIMIZE   = 11; HIDE            = 0
        MAXIMIZE        = 3;  MINIMIZE        = 6
        RESTORE         = 9;  SHOW            = 5
        SHOWDEFAULT     = 10; SHOWMAXIMIZED   = 3
        SHOWMINIMIZED   = 2;  SHOWMINNOACTIVE = 7
        SHOWNA          = 8;  SHOWNOACTIVATE  = 4
        SHOWNORMAL      = 1
    }
    Write-Verbose ("Set Window Style {1} on handle {0}" -f $MainWindowHandle, $($WindowStates[$style]))
    AddLogEntry "Setting Window Style $($WindowStates[$style]) on Window Handle: $MainWindowHandle`..."

    $Win32ShowWindowAsync = Add-Type –memberDefinition @” 
    [DllImport("user32.dll")] 
    public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
“@ -name “Win32ShowWindowAsync” -namespace Win32Functions –passThru

    $Win32ShowWindowAsync::ShowWindowAsync($MainWindowHandle, $WindowStates[$Style]) | Out-Null
}

#Below code lets us operate on taskbar and mouse cursor - we can hide/show it anytime
$Source = @"
using System;
using System.Runtime.InteropServices;

public class Taskbar
{
    [DllImport("user32.dll")]
    private static extern int FindWindow(string className, string windowText);
    [DllImport("user32.dll")]
    private static extern int ShowWindow(int hwnd, int command);

    private const int SW_HIDE = 0;
    private const int SW_SHOW = 1;

    protected static int Handle
    {
        get
        {
            return FindWindow("Shell_TrayWnd", "");
        }
    }

    private Taskbar()
    {
        // hide ctor
    }

    public static void Show()
    {
        ShowWindow(Handle, SW_SHOW);
    }

    public static void Hide()
    {
        ShowWindow(Handle, SW_HIDE);
    }
}
"@
Add-Type -ReferencedAssemblies 'System', 'System.Runtime.InteropServices' -TypeDefinition $Source -Language CSharp

# Get active window
Add-Type @"
  using System;
  using System.Runtime.InteropServices;
  public class ForeGroundWindowSeer {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
}
"@

function Display-AsyncPopUpWindow($title, $location){
    $objForm = New-Object System.Windows.Forms.Form

    if (-not $location){
        AddLogEntry "Starting asynchrous pop-up window with title `"$title`" at the center of the screen..."
        $objForm.StartPosition = 'CenterScreen'
    }
    else{
        AddLogEntry "Starting asynchrous pop-up window with title `"$title`" at: $location"
        $objForm.StartPosition = 'Manual'
        $objForm.Location = $location
    }

    $objForm.Size = New-Object System.Drawing.Size(220,100)
    $objForm.Text = $title
    $objForm.ControlBox = $false
    $objForm.Icon = [System.IconExtractor]::Extract($GLOBAL:BCU_Path, 0, $true)

    $objLabel = [System.Windows.Forms.Label]::New()
    $objLabel.Location = New-Object System.Drawing.Size(50,18) 
    $objLabel.Size = New-Object System.Drawing.Size(0,0) #100,20
    $objLabel.Text = ""

    $objForm.Controls.Add($objLabel)

    # Sometimes PowerShell window appears too late and/or form appears too fast and PS window is getting
    # brought to the front of the screen instead of the form. Hopefully this fixes the issue...
    Start-Sleep -Milliseconds 10

    $ShownError = $objForm.Show()

    $ActiveWindow = [ForeGroundWindowSeer]::GetForegroundWindow()
    $PSWindowHandle = (Get-Process -Id $pid).MainWindowHandle

    if (-not $ShownError -and $objForm.Visible -eq $true){ #NET-BroadcastEventWindow
        # Force push the form in front of everything else
        AddLogEntry "Trying to push the asynchrous pop-up window with Window Handle `"$PSWindowHandle`" to front..."
        Set-WindowStyle -MainWindowHandle $PSWindowHandle -Style SHOWNORMAL
    }
    else{
        # If we cannot display the form - hide the console
        AddLogEntry "Anynchrous pop-up window was not visible or it had an error - trying to hide the console window..."
        Set-WindowStyle -MainWindowHandle $PSWindowHandle -Style HIDE
    }

    if (-not ($(Get-Process | Where-Object {$_.MainWindowHandle -eq $ActiveWindow}).MainWindowTitle -like "*$title*")){
        # If currently active window title is not like the form title - that means user sees PS console window - immediately hide it!
        AddLogEntry "Currently active window's title is different from pop-up window title! Trying to hide the active window..."
        Set-WindowStyle -MainWindowHandle $PSWindowHandle -Style HIDE
    }

    # Pass the form as a variable so that it can be interacted with from other functions
    return $objForm
}

function Display-PopUpMessageWindow([string]$title, [string]$message, [string]$buttons, [string]$icon){
    AddLogEntry "Starting a pop-up message window with message: `"$message`"."

    $ButtonType = [System.Windows.MessageBoxButton]::$buttons
    $MessageIcon = [System.Windows.MessageBoxImage]::$icon
    $MessageBody = $message
    $MessageTitle = $title
 
    $Result = [System.Windows.MessageBox]::Show($MessageBody,$MessageTitle,$ButtonType,$MessageIcon)
    return $Result
}

function Display-SpecialTextMessage([string]$message){
    AddLogEntry "Starting a special text message window: `"$message`"."
    # Calculate form length
    $_fontsize = 10
    $_x = 350

    if ($message){
        $AllLines = ($message | Measure-Object -Line).Lines
        $_y = $($AllLines*($_fontsize*1.75))
    }
    else{
        $_y = 420
    }

    $form = New-Object System.Windows.Forms.Form
    $form.Size = New-Object System.Drawing.Size($_x,$_y)
    $form.StartPosition = 'CenterScreen'
    $form.Icon = [System.IconExtractor]::Extract($GLOBAL:BCU_Path, 0, $true)
    $form.MinimizeBox = $false
    $form.MaximizeBox = $false
    $form.Text = ”Info - HP BIOS Settings”
    $form.FormBorderStyle = 'FixedSingle'

    $textbox = New-Object System.Windows.Forms.TextBox
    $textbox.Text = $message #`r`n to add newline
    $textbox.Multiline = $true 
    $textbox.Location = New-Object System.Drawing.Size(5,5) 
    $textbox.Size = New-Object System.Drawing.Size($($_x-30),$_y)
    $textbox.BorderStyle = 0
    $textbox.TabStop = $false
    $textbox.ReadOnly = $true

    $Font = New-Object System.Drawing.Font("Times New Roman",$_fontsize)
    $textbox.Font = $Font

    $form.controls.Add($textbox)

    $form.ShowDialog()
}

function Get-BIOSPassword($location){
    $Font = New-Object System.Drawing.Font("Times New Roman",10)

    $objForm = New-Object System.Windows.Forms.Form 
    $objForm.Text = "Password Entry"
    $objForm.Size = New-Object System.Drawing.Size(300,180)

    if ($location){
        AddLogEntry "Requesting BIOS password... Displaying the request window at: $location"

        $objForm.StartPosition = 'Manual'
        $objForm.Location = $location
    }
    else{
        AddLogEntry "Requesting BIOS password... Displaying the request window at the center of the screen..."

        $objForm.StartPosition = "CenterScreen"
    }
    if ($objForm.KeyPreview -ne $null){ 
        $objForm.KeyPreview = $True
    }
    $objForm.Add_KeyDown({if ($_.KeyCode -eq "Enter"){
        AddLogEntry "User pressed the `"Enter`" key..."
        $GLOBAL:PWBOX_WAS_CLOSED_WITH_CONTROLS = $true
        $objForm.Close()}
    })
    $objForm.Add_KeyDown({
        if ($_.KeyCode -eq "Escape"){
            AddLogEntry "User closed the window with `"Esc`" key..."
            $GLOBAL:PWBOX_WAS_CLOSED_WITH_CONTROLS = $true
            $MaskedTextBox.Text = "PASSWORD_INPUT_CANCELLED"
            $objForm.Close()
        }
    })
    $objForm.Icon = [System.IconExtractor]::Extract($GLOBAL:BCU_Path, 0, $true)
    $objForm.MinimizeBox = $false
    $objForm.MaximizeBox = $false
    $objForm.FormBorderStyle = 'FixedSingle'
    $objForm.Add_Closing({
        if ($GLOBAL:PWBOX_WAS_CLOSED_WITH_CONTROLS -ne $true){
            AddLogEntry "User closed the window with the `"X`" in the upper right window corner..."
            $MaskedTextBox.Text = "PASSWORD_INPUT_CANCELLED"
        }
    })
    
    $OKButton = New-Object System.Windows.Forms.Button
    $OKButton.Location = New-Object System.Drawing.Size(30,80)
    $OKButton.Size = New-Object System.Drawing.Size(100,40)
    $OKButton.Text = "OK"
    $OKButton.Add_Click({
        AddLogEntry "User pressed the `"OK`" button..."
        $GLOBAL:PWBOX_WAS_CLOSED_WITH_CONTROLS = $true
        $objForm.Close()
    })
    $objForm.Controls.Add($OKButton)

    $CancelButton = New-Object System.Windows.Forms.Button
    $CancelButton.Location = New-Object System.Drawing.Size(150,80)
    $CancelButton.Size = New-Object System.Drawing.Size(100,40)
    $CancelButton.Text = "Cancel"
    $CancelButton.Add_Click({
        AddLogEntry "User closed the window with the `"Cancel`" button..."
        $GLOBAL:PWBOX_WAS_CLOSED_WITH_CONTROLS = $true
        $MaskedTextBox.Text = "PASSWORD_INPUT_CANCELLED"
        $objForm.Close()
    })

    $objForm.Controls.Add($CancelButton)
    $objLabel = New-Object System.Windows.Forms.Label
    $objLabel.Location = New-Object System.Drawing.Size(10,20) 
    $objLabel.Size = New-Object System.Drawing.Size(280,20) 
    $objLabel.Text = "Please enter BIOS password:"
    $objForm.Controls.Add($objLabel)
    $objForm.Font = $Font

    $MaskedTextBox = New-Object System.Windows.Forms.MaskedTextBox
    $MaskedTextBox.PasswordChar = '*'
    $MaskedTextBox.Location = New-Object System.Drawing.Size(10,45)
    $MaskedTextBox.Size = New-Object System.Drawing.Size(260,50)
    $MaskedTextBox.Font = $Font

    $objForm.Controls.Add($MaskedTextBox) 
    $objForm.Topmost = $True
    $objForm.Add_Shown({
        $objForm.Activate()
    })
    [void] $objForm.ShowDialog()

    # Reset global check - we check here if user closed the window with 'X'
    $GLOBAL:PWBOX_WAS_CLOSED_WITH_CONTROLS = $false

    if($MaskedTextBox.Text -eq 'PASSWORD_INPUT_CANCELLED'){
        AddLogEntry "Password input cancelled!"
        return $false
    }
    else{
        AddLogEntry "Acquired BIOS password... Passing further..."
        $GLOBAL:PW = $MaskedTextBox.Text
    }
}

function Set-FormBIOSSettings($invokingObject){
    AddLogEntry "Trying to save BIOS settings using current form choices..."

    $temp_setting_title = $null
    $temp_new_setting = $null
    $temp_allconfigs = Get-Content $GLOBAL:exportedCFGpath -Encoding UTF8

    foreach ($checkboxgroup in $CheckboxGroups.GetEnumerator()) { 
        if ($checkboxgroup.keys){
            $checkboxgroup.values |% {
            if ($_.Checked -eq $true -or $_.GetType().Name -eq "Button"){
                    $is_button = $_.GetType().Name -eq "Button"
                    $temp_buttons = @()

                    $temp_setting_title = $_.Name
                    $temp_new_setting = $_.Text
                    $find_setting = $false

                    $line_nr = -1

                    if ($is_button){
                        # Get all settings from current collection
                        foreach ($checkboxgroup in $CheckboxGroups.GetEnumerator()) { 
                            if ($checkboxgroup.keys -like "*$temp_setting_title*"){
                                $checkboxgroup.values |% {
                                    $temp_buttons += $_.Text
                                }
                            }
                        }

                        ForEach ($line in $temp_allconfigs){
                            $line_nr++
                            if ($line -like $temp_setting_title -and $find_setting -eq $false){
                                $find_setting = $true
                            }
                            elseif ($find_setting -eq $true){
                                
                                $temp_buttons |% {
                                    if ($temp_allconfigs[$line_nr] -match "\t"){
                                        $temp_allconfigs[$line_nr] = "`t$_"
                                        $line_nr++
                                    }
                                }

                                $find_setting = $false
                                break
                            }
                        }
                    }
                    else{
                        ForEach ($line in $temp_allconfigs){
                            $line_nr++
                            if ($line -like $temp_setting_title -and $find_setting -eq $false){
                                $find_setting = $true
                            }
                            elseif ($find_setting -eq $true){
                                if ($line -match "\t"){
                                    if ($line.Contains("*") -and -not ($line -eq "`t`*$($temp_new_setting -replace(' \(Default\)',''))")){
                                        $temp_allconfigs[$line_nr] = $temp_allconfigs[$line_nr].replace('*','')
                                    }
                                    elseif (-not $line.Contains("*") -and $line -eq "`t$($temp_new_setting -replace(' \(Default\)',''))"){
                                        $temp_allconfigs[$line_nr] = $temp_allconfigs[$line_nr].replace("`t","`t*")
                                    }
                                }
                                else{
                                    $find_setting = $false
                                    break
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    AddLogEntry "Saving custom CFG file..."
    # Create a custom cfg file
    $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
    [System.IO.File]::WriteAllLines($GLOBAL:customCFGpath, $temp_allconfigs, $Utf8NoBomEncoding)

    if ($invokingObject){
        AddLogEntry "BIOS password needed..."
        $_pw = Get-BIOSPassword "$(($invokingObject.Parent.Location.X)+275),$(($invokingObject.Parent.Location.Y)+175)"
    }
    else{
        AddLogEntry "BIOS password needed... No window location parameters were passed..."
        $_pw = Get-BIOSPassword
    }

    if ($_pw -eq $false){
        AddLogEntry "BIOS password was not passed successfully. Aborting!"
        return
    }

    AddLogEntry "Creating password file with provided data..."
    $CreatePWAttempt = Start-Process $GLOBAL:BCUPW_Path -ArgumentList "/f$GLOBAL:BIOS_PWD_Path", "/s", "/p$GLOBAL:PW" -PassThru -WindowStyle Hidden -Wait
    AddLogEntry "BCUPW.exe has finished creating password file with exitcode: $($CreatePWAttempt.ExitCode)"

    #####################################
    ####-IMPORT-NEW-SETTINGS-TO-BIOS-####
    #####################################

    AddLogEntry "Trying to import settings from generated CFG file into the BIOS..."
    $ImportCfgAttempt = Start-Process $GLOBAL:BCU_Path -ArgumentList "/Set:$($GLOBAL:customCFGpath)", "/cspwdfile:$($GLOBAL:BIOS_PWD_Path)" -PassThru -WindowStyle Hidden -Wait

    # Check if we were able to change the BIOS settings
    if ($ImportCfgAttempt.ExitCode -ne 0)
    {
        if ($GLOBAL:BCU_ErrorTable[$ImportCfgAttempt.ExitCode]){
            AddLogEntry "Import failed with error: `"$($GLOBAL:BCU_ErrorTable[$ImportCfgAttempt.ExitCode])`""
            Display-PopUpMessageWindow "Error" $($GLOBAL:BCU_ErrorTable[$ImportCfgAttempt.ExitCode]) "OK" "Error"
        }
        else{
            AddLogEntry "Import failed with an unsupported exitcode! Exitcode: $($ImportCfgAttempt.ExitCode)"
            Display-PopUpMessageWindow "Error" "Unsupported error. No changes to BIOS were made." "OK" "Error"
        }
    }
    else
    {
        AddLogEntry "Successfully saved BIOS settings!"
        Display-PopUpMessageWindow "Success" "BIOS settings have been saved successfully." "OK" "None"
    }
}

function Get-BIOSSettings($DisplayError){
    AddLogEntry "Trying to export BIOS settings..."

    # Delete old temp BIOS data files
    $GLOBAL:exportedCFGpath,
    $GLOBAL:customCFGpath,
    $GLOBAL:BIOS_PWD_Path |% { if (Test-Path $_){ Remove-Item -Path $_ -Force -ErrorAction SilentlyContinue | Out-Null } }

    # Extract setting from BIOS into a file
    $ExportCfgAttempt = Start-Process $GLOBAL:BCU_Path -ArgumentList "/Get:$GLOBAL:exportedCFGpath" -PassThru -WindowStyle Hidden -Wait

    # Check if we could export the settings
    if ($ExportCfgAttempt.ExitCode -ne 0)
    {
        if ($DisplayError){
            if ($($GLOBAL:BCU_ErrorTable[$ExportCfgAttempt.ExitCode])){
                AddLogEntry "Exporting BIOS settings failed with error: `"$($($GLOBAL:BCU_ErrorTable[$ExportCfgAttempt.ExitCode] -replace 'No changes to BIOS were made.', '').TrimEnd())`""
                Display-PopUpMessageWindow "Error" "Failed to load BIOS settings: $($($GLOBAL:BCU_ErrorTable[$ExportCfgAttempt.ExitCode] -replace 'No changes to BIOS were made.', '').TrimEnd())" "OK" "Error"
            }
            else{
                AddLogEntry "Exporting BIOS settings failed with an unsupported exitcode. Exitcode: $($ExportCfgAttempt.ExitCode)"
                Display-PopUpMessageWindow "Error" "Failed to load BIOS settings: Unsupported error." "OK" "Error"
            }
        }
        Throw "Get-BIOSSettings : Failed to export BIOS settings. BCU did not export a configuration file successfully.`nYou may be missing proper rights for this action."
        AddMainLogEntry "FINISHED THE APPLICATION WITH EXITCODE: 2"
        return
    }
    AddLogEntry "Successfully exported BIOS settings into a file. Parsing data into an object which can be easily iterated through..."
    
    # Catch all settings into an object
    $all_configs = @()

    $temp_settingname = ""
    $temp_settings = @()

    $counter = 1

    foreach ($line in $(Get-Content $GLOBAL:exportedCFGpath -Encoding UTF8 | Select-Object -Skip 1)){
        if ($line -notlike "*;*" -and $line -notmatch "\t" -and $line -ne ""){
            # Beginning of a new setting
            if ([string]::IsNullOrEmpty($temp_settingname)){
                $temp_settingname = $line
            }
            elseif ($temp_settingname -ne $line){
                $all_configs += @{$temp_settingname = $temp_settings}
                $temp_settings = @()
                $temp_settingname = $line
            }
        }
        elseif ($line -notlike "*;*" -and $line -match "\t"){
            $temp_settings += $($line -replace "\t", "")
        }
    }

    return $all_configs
}

$IconModule = @"
using System;
using System.Drawing;
using System.Runtime.InteropServices;

namespace System
{
	public class IconExtractor
	{

	 public static Icon Extract(string file, int number, bool largeIcon)
	 {
	  IntPtr large;
	  IntPtr small;
	  ExtractIconEx(file, number, out large, out small, 1);
	  try
	  {
	   return Icon.FromHandle(largeIcon ? large : small);
	  }
	  catch
	  {
	   return null;
	  }

	 }
	 [DllImport("Shell32.dll", EntryPoint = "ExtractIconExW", CharSet = CharSet.Unicode, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
	 private static extern int ExtractIconEx(string sFile, int iIndex, out IntPtr piLargeVersion, out IntPtr piSmallVersion, int amountIcons);

	}
}
"@
Add-Type -TypeDefinition $IconModule -ReferencedAssemblies System.Drawing

function PrepareEnvironment-BeforeSearch($invokingObject){
    AddLogEntry "Resetting global variables before starting search..."

    $GLOBAL:ShouldSearch = $true

    $GLOBAL:Passed_X_Coordinate = $invokingObject.Parent.Location.X
    $GLOBAL:Passed_Y_Coordinate = $invokingObject.Parent.Location.Y

    $GLOBAL:CheckboxGroups = @()
    $GLOBAL:CheckboxGroups_exceptions = @()

    $GLOBAL:CheckboxGroups_InitButtonData = @()
    $GLOBAL:CheckboxGroups_InitButtonData += @{a='b'}

    $GLOBAL:Checkbox_to_check = $null
    $GLOBAL:num_checkboxes_in_group = 0
    $GLOBAL:num_checkboxes_in_group_temp = 0
}

function Add-SearchBarToForm($FORM, $Y_AXIS){
    AddLogEntry "Adding search bar to main form..."

    $SearchButton = New-Object System.Windows.Forms.Button
    $SearchButton.Location = New-Object System.Drawing.Point(420,$($Y_AXIS*3.3))
    $SearchButton.Size = New-Object System.Drawing.Size(75,20)
    $SearchButton.Text = 'Search'
    $SearchButton.add_MouseHover($GLOBAL:ToolTipList)
    $SearchButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $SearchButton.Add_Click({
        PrepareEnvironment-BeforeSearch $this
        $this.Parent.Close()
    })
    $FORM.Controls.Add($SearchButton)

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(20,$Y_AXIS)
    $label.Size = New-Object System.Drawing.Size(500,20)
    $label.Text = 'Input search keyword. Searching will reset all currently chosen unsaved settings.'
    $FORM.Controls.Add($label)

    $textBox_search = New-Object System.Windows.Forms.TextBox
    $textBox_search.Location = New-Object System.Drawing.Point(22,$($Y_AXIS*3.3))
    $textBox_search.Size = New-Object System.Drawing.Size(380,20)
    $textBox_search.MaxLength = 36
    $textBox_search.Font = New-Object System.Drawing.Font("Times New Roman",11,[System.Drawing.FontStyle]::Regular)
    $textBox_search.KeyPreview = $True
    $textBox_search.Add_KeyDown({if ($_.KeyCode -eq "Enter"){
        if ($this.Focused -eq $true){ #$($this.Text).Length -gt 0
            PrepareEnvironment-BeforeSearch $this
            $this.Parent.Close()
        }
    }})
    $FORM.Controls.Add($textBox_search)

    $GLOBAL:SEARCHBOX = $textBox_search
}

function Add-LabelToForm($FORM, $Y_AXIS, $TEXT, $TEXTCOLOR){
    AddLogEntry "Adding label to main form with text: $TEXT"

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(30,$Y_AXIS)
    $label.Size = New-Object System.Drawing.Size(660,20)
    $label.Text = $TEXT
    if ($TEXTCOLOR){
        $label.ForeColor = $TEXTCOLOR
    }
    $FORM.Controls.Add($label)
}

function Add-CheckboxToForm($FORM, $Y_AXIS, $TEXT, $CHECKED, $GROUPNAME){
    $checkbox = new-object System.Windows.Forms.checkbox
    $checkbox.Location = new-object System.Drawing.Size(30,$Y_AXIS)
    $checkbox.Size = new-object System.Drawing.Size(650,50)
    $checkbox.Text = $TEXT
    $checkbox.Checked = $CHECKED
    $checkbox.Name = $GROUPNAME

    $GLOBAL:CheckboxGroups += @{$GROUPNAME = $checkbox}

    $FORM.Controls.Add($checkbox)

    # Uncheck all other checkboxes from the same group on click
    $checkbox.Add_CheckStateChanged({
        if ($GLOBAL:num_checkboxes_in_group -gt 0){
            return
        }

        $GLOBAL:Checkbox_to_check = $this

        foreach ($checkboxgroup in $CheckboxGroups.GetEnumerator()) { 
            if ($checkboxgroup.keys -eq $this.Name){
                $checkboxgroup.values |% {
                    $GLOBAL:num_checkboxes_in_group = $GLOBAL:num_checkboxes_in_group+1
                }
            }
        }
        
        $GLOBAL:num_checkboxes_in_group_temp = $GLOBAL:num_checkboxes_in_group

        foreach ($checkboxgroup in $CheckboxGroups.GetEnumerator()) { 

            if ($checkboxgroup.keys -eq $this.Name){
                $checkboxgroup.values |% {
                    if ($_ -ne $GLOBAL:Checkbox_to_check -and $_.Name -eq $GLOBAL:Checkbox_to_check.Name -and $_.Checked -eq $true -and $GLOBAL:num_checkboxes_in_group_temp -gt 0){
                         $_.Checked = $false
                         $GLOBAL:num_checkboxes_in_group_temp--
                    }
                    elseif ($_ -eq $GLOBAL:Checkbox_to_check -and $GLOBAL:num_checkboxes_in_group_temp -gt 0){
                         $_.Checked = $true
                         $GLOBAL:num_checkboxes_in_group_temp--
                    }
                    else{
                        $GLOBAL:num_checkboxes_in_group_temp--
                    }
                }
            }
        }

        # Enable all buttons which have been disabled by user (enable only settings which have more than 1 setting in the group)
        foreach ($checkboxgroup in $CheckboxGroups.GetEnumerator()) { 
            $checkboxgroup.values |% {
                if ($_.GetType().Name -eq "Button" -and -not ($_ -in $GLOBAL:CheckboxGroups_exceptions)){
                    $_.Enabled = $true
                }
            }
        }

        $GLOBAL:num_checkboxes_in_group = 0
        $GLOBAL:num_checkboxes_in_group_temp = 0
    })
}

function Add-ButtonOptionsToForm($FORM, $Y_AXIS, $TEXT, $GROUPNAME){
    AddLogEntry "Adding button to main form with text: $TEXT"

    $Button = new-object System.Windows.Forms.Button
    $Button.Location = new-object System.Drawing.Size(30,$Y_AXIS)
    $Button.Size = new-object System.Drawing.Size(260,30)
    $Button.Text = $TEXT
    $Button.Name = $GROUPNAME

    $GLOBAL:CheckboxGroups += @{$GROUPNAME = $Button}

    $Button.Add_Click({
         foreach ($checkboxgroup in $CheckboxGroups.GetEnumerator()) { 
            if ($checkboxgroup.keys -eq $this.Name){
                $checkboxgroup.values |% {
                    if ($_.Enabled -eq $false -and $_ -ne $this){
                        $this_text = $this.Text

                        $this.Text = $_.Text
                        $_.Text = $this_text

                        $_.Enabled = $true
                        $this.Enabled = $true

                        break
                    }
                    else{
                        $this.Enabled = $false
                    }
                }
            }
        }
    })

    $FORM.Controls.Add($Button)

    # Return the button so that we can access it from other functions
    return $Button
}

function GenerateBIOS-Form($UsedFilter, $posX, $posY){
    AddLogEntry "Starting to generate the main form... Loading assemblies..."

    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
    Add-Type -AssemblyName PresentationCore,PresentationFramework
    
    # Hide launcher window
    Set-WindowStyle -MainWindowHandle $(Get-Process |? {$_.MainWindowTitle -like "*launcher_shortcut" -and $_.ProcessName -eq "cmd"}).MainWindowHandle -Style HIDE

    if (-not $UsedFilter -and -not $posX -and -not $posY){
        $LoadingScreen = Display-AsyncPopUpWindow "Loading..." $false 
    }
    else{
        if ($posX -and $posY){
            $LoadingScreen = Display-AsyncPopUpWindow "Searching..." "$($posX+300),$($posY+200)"
        }
        else{
            $LoadingScreen = Display-AsyncPopUpWindow "Searching..." $false
        }
    }
    
    # Set the size of the form
    $Form = New-Object System.Windows.Forms.Form
    $Form.width = 800
    $Form.height = 600
    $Form.Text = ”HP BIOS Settings”
    $Form.AutoScroll = $true
    $Form.MinimizeBox = $false
    $Form.MaximizeBox = $false
 
    # Set the font of the text to be used within the form
    $Font = New-Object System.Drawing.Font("Times New Roman",10)
    $Form.Font = $Font

    $GLOBAL:ToolTip_object = New-Object System.Windows.Forms.ToolTip
    $GLOBAL:ToolTipList = {
        Switch ($this.Text) {
            "Reset"  {$tip = "Reset current selection to settings which were originally set (marked as `"Default`")."}
            "Save"   {$tip = "Save currently selected settings."}
            "Info"   {$tip = "Display more detailed information about this computer."}
            "Search" {$tip = "Search will reload all settings directly from BIOS."}
            "Exit"   {$tip = "Close the application."}
        }
        $GLOBAL:ToolTip_object.SetToolTip($this,$tip)
    }

    Add-SearchBarToForm $Form 10

    $temp_Y_axis = 20

    # Add a Save button
    $ButtonHorizontalPx = 20

    $SaveButton = new-object System.Windows.Forms.Button
    $SaveButton.Location = new-object System.Drawing.Size($ButtonHorizontalPx,$($temp_Y_axis+50))
    $SaveButton.Size = new-object System.Drawing.Size(100,40)
    $SaveButton.Text = "Save"
    $SaveButton.add_MouseHover($GLOBAL:ToolTipList)
    $SaveButton.Add_Click({
        AddLogEntry "User clicked the `"Save`" button..."

        $SaveBufferScreen = Display-AsyncPopUpWindow "Saving..." "$(($this.Parent.Location.X)+300),$(($this.Parent.Location.Y)+200)"

        Set-FormBIOSSettings $this

        $SaveBufferScreen.Close() | Out-Null
    })
    $form.Controls.Add($SaveButton)

    # Add a Reset button
    $ResetButton = new-object System.Windows.Forms.Button
    $ResetButton.Location = new-object System.Drawing.Size($($ButtonHorizontalPx+(125*1)),$($temp_Y_axis+50))
    $ResetButton.Size = new-object System.Drawing.Size(100,40)
    $ResetButton.Text = "Reset"
    $ResetButton.add_MouseHover($GLOBAL:ToolTipList)
    $ResetButton.Add_Click({
        AddLogEntry "User clicked the `"Reset`" button..."

        $ResetBufferScreen = Display-AsyncPopUpWindow "Resetting..." "$(($this.Parent.Location.X)+300),$(($this.Parent.Location.Y)+200)"
        $nr_setting = 0
        $last_settingname = ""

        foreach ($checkboxgroup in $CheckboxGroups.GetEnumerator()) { 

            if ($checkboxgroup.keys){
                $checkboxgroup.values |% {

                    if (-not ($_.GetType().Name -eq "Button") -and $_.Text -like "*(Default)*"){
                        $_.Checked = $true
                    }
                    elseif ($_.GetType().Name -eq "Button" -and -not ($_ -in $GLOBAL:CheckboxGroups_exceptions)){
                        $initbuttondata_temp = $GLOBAL:CheckboxGroups_InitButtonData[0]."$($_.Name)"

                        if ($initbuttondata_temp -ne $null -and $initbuttondata_temp.Count -gt $nr_setting){
                            if ($last_settingname -ne $_.Name){
                                $last_settingname = $_.Name
                                $nr_setting = 0
                                $_.Text = $initbuttondata_temp[$nr_setting]
                            }
                            else{
                                $nr_setting++
                                $_.Text = $initbuttondata_temp[$nr_setting]
                            }
                        }
                        $_.Enabled = $true
                    }
                }
            }
        }

        $ResetBufferScreen.Close() | Out-Null
    })
    $form.Controls.Add($ResetButton)

    # Add Info button
    $InfoButton = new-object System.Windows.Forms.Button
    $InfoButton.Location = new-object System.Drawing.Size($($ButtonHorizontalPx+(125*2)),$($temp_Y_axis+50))
    $InfoButton.Size = new-object System.Drawing.Size(100,40)
    $InfoButton.Text = "Info"
    $InfoButton.add_MouseHover($GLOBAL:ToolTipList)
    $InfoButton.Add_Click({
        AddLogEntry "User clicked the `"Info`" button..."

        $InfoBufferScreen = Display-AsyncPopUpWindow "Processing..." "$(($this.Parent.Location.X)+300),$(($this.Parent.Location.Y)+200)"

        # Generate info string
        if (Test-Path $GLOBAL:exportedCFGpath){
            $catch_next_line = $false
            $next_line_title = ""
            $AllInfoToDisplay = ""

            $possible_eq = @(
                "Product Name"
                "Serial Number"
                "System BIOS Version"
                "System Board CT Number"
                "SKU Number"
                "Asset Tracking Number"
            )

            ForEach ($line in $(Get-Content $GLOBAL:exportedCFGpath | Select-Object -Skip 1)){
                if ($line -in $possible_eq -or $line -like "*UUID*" -or $line -match "Processor [0-9] Type" -or $line -like "*MAC Address*"){
                    $catch_next_line = $true
                    $next_line_title = $line
                    continue
                }

                if ($catch_next_line -and $line -match "\t"){
                    $AllInfoToDisplay += "`[$next_line_title`]`r`n$($line.replace(`"`t`",`"`"))`r`n`r`n"

                    $catch_next_line = $false
                }
            }
            $InfoBufferScreen.Close() | Out-Null
            Display-SpecialTextMessage $($AllInfoToDisplay.TrimEnd())
        }
        else{
            $InfoBufferScreen.Close() | Out-Null
            Display-PopUpMessageWindow "Error" "Failed to generate info. File not found." "OK" "Error"
        }
    })
    $form.Controls.Add($InfoButton)

    # Add a Cancel button
    $CancelButton = new-object System.Windows.Forms.Button
    $CancelButton.Location = new-object System.Drawing.Size($($ButtonHorizontalPx+(125*3)),$($temp_Y_axis+50))
    $CancelButton.Size = new-object System.Drawing.Size(100,40)
    $CancelButton.Text = "Exit"
    $CancelButton.add_MouseHover($GLOBAL:ToolTipList)
    $CancelButton.Add_Click({
        AddLogEntry "User clicked the `"Close`" button. Trying to close the form..."
        $Form.Close()
    })
    $form.Controls.Add($CancelButton)

    $temp_Y_axis = 80
    $temp_setting_nr = 1
    $temp_search_nr = 0

    $BIOS_Settings = Get-BIOSSettings $true

    ForEach ($config in $($BIOS_Settings.GetEnumerator())){
        
        if ($config.values -match "\*"){
            ForEach ($value_pair in $config.values){
                if ($UsedFilter -ne $null -and -not $($config.keys -like "*$UsedFilter*")){
                    $temp_setting_nr++
                    continue
                }
                elseif ($UsedFilter -ne $null -and $config.keys -like "*$UsedFilter*"){
                    $temp_search_nr++
                }

                Add-LabelToForm $Form $($temp_Y_axis+70) "$temp_setting_nr`. $($config.keys)"
                $temp_setting_nr = $temp_setting_nr+1
                $temp_Y_axis = $temp_Y_axis+70

                $val_count = 0
                $value_pair |% { 
                    $val_count = $val_count+1
                    $txt = $_
                    if ($_.Contains("*")){
                        $txt = "$($_.replace('*','')) (Default)"
                    }
                    if ($val_count -gt 1){
                        Add-CheckboxToForm $Form $($temp_Y_axis+35) $txt $($_.Contains("*")) $($config.keys)
                        $temp_Y_axis = $temp_Y_axis+35
                    }
                    else{
                        Add-CheckboxToForm $Form $($temp_Y_axis+20) $txt $($_.Contains("*")) $($config.keys)
                        $temp_Y_axis = $temp_Y_axis+20
                    }
                }
            }
        }
        elseif ($config.values -notmatch "\*" -and $config.keys -like "*Boot Order"){
            ForEach ($value_pair in $config.values){
                if ($UsedFilter -ne $null -and -not $($config.keys -like "*$UsedFilter*")){
                    $temp_setting_nr++
                    continue
                }
                elseif ($UsedFilter -ne $null -and $config.keys -like "*$UsedFilter*"){
                    $temp_search_nr++
                }

                Add-LabelToForm $Form $($temp_Y_axis+70) "$temp_setting_nr`. $($config.keys)"
                $temp_setting_nr = $temp_setting_nr+1
                $temp_Y_axis = $temp_Y_axis+70

                $val_count = 0
                $value_pair |% { 
                    $val_count = $val_count+1
                    $txt = $_
                    if ($val_count -gt 1){
                        $Button = Add-ButtonOptionsToForm $Form $($temp_Y_axis+35) $txt $($config.keys)
                        $temp_Y_axis = $temp_Y_axis+35
                    }
                    else{
                        $Button = Add-ButtonOptionsToForm $Form $($temp_Y_axis+20) $txt $($config.keys)
                        $temp_Y_axis = $temp_Y_axis+20
                    }
                    AddLogEntry "Adding options under the label. Number of options: $val_count"

                    $GLOBAL:CheckboxGroups_InitButtonData[0]."$($config.keys)" += @($txt)
                }
                # Disable button if there is only 1 option available in a category
                if ($val_count -eq 1 -and $Button -ne $null){
                    $Button.Enabled = $false
                    $GLOBAL:CheckboxGroups_exceptions += $Button
                }
            }
        }
    }

    # This line displays ABOVE the bios settings
    if ($UsedFilter){
        Add-LabelToForm $Form 120 "Showing results for keyword: `"$UsedFilter`". Number of results: $temp_search_nr" "Gray"
    }

    # Set window position if we were reset because of searching
    if (-not $GLOBAL:Passed_X_Coordinate -and -not $GLOBAL:Passed_Y_Coordinate){
        $form.StartPosition = 'CenterScreen'
    }
    else{
        if (-not $GLOBAL:Passed_X_Coordinate){
            $GLOBAL:Passed_X_Coordinate = 0
        }
        elseif (-not $GLOBAL:Passed_Y_Coordinate){
            $GLOBAL:Passed_Y_Coordinate = 0
        }
        $form.StartPosition = 'Manual'
        $form.Location = "$($GLOBAL:Passed_X_Coordinate),$($GLOBAL:Passed_Y_Coordinate)"
    }

    # Reset ShouldSearch and passed coordinates
    $GLOBAL:ShouldSearch = $false
    $GLOBAL:Passed_X_Coordinate = $null
    $GLOBAL:Passed_Y_Coordinate = $null

    # Empty line to make the bottom of the screen look nicer
    Add-LabelToForm $Form $($temp_Y_axis+55) ""

    # Set custom icon
    $form.Icon = [System.IconExtractor]::Extract($GLOBAL:BCU_Path, 0, $true)

    # Lock window size - do not allow resizing (resizing made the window look buggy and unprofessional)
    $form.FormBorderStyle = 'FixedSingle' 
    
    # We are about to display the application - kill our loading screen
    if ($LoadingScreen){
        $LoadingScreen.Close() | Out-Null
    }

    $PID_MainWindowHandle = $(Get-Process -Id $pid).MainWindowHandle

    if ($PID_MainWindowHandle){
        AddLogEntry "Hiding MainWindowHandle: $PID_MainWindowHandle of PS window. If MainWindowHandle ID is different from 0, the window was not hidden at this point yet - it was either visible to user or minimized."
        Set-WindowStyle -MainWindowHandle $PID_MainWindowHandle -Style HIDE
    }

    # Activate the form
    $Form.Add_Shown({$Form.Activate()})
    [void] $Form.ShowDialog()

    AddLogEntry "Form has been closed by the user."
    AddMainLogEntry "FINISHED THE APPLICATION WITH EXITCODE: 0"

    # Check if we should search after closing the form
    if ($GLOBAL:ShouldSearch -eq $true){
        AddLogEntry "User wants to search a phrase: `"$($GLOBAL:SEARCHBOX.Text)`". Generating a new form..."
        GenerateBIOS-Form $($GLOBAL:SEARCHBOX.Text) $GLOBAL:Passed_X_Coordinate $GLOBAL:Passed_Y_Coordinate
    }

    # Clean after ourselves
    if (Test-Path $GLOBAL:BIOS_PWD_Path){
        AddLogEntry "BIOS password file found. Deleting..."
        Remove-Item $GLOBAL:BIOS_PWD_Path -Force -ErrorAction SilentlyContinue | Out-Null
    }
}