$StationNumber = Read-Host -Prompt "Input your station number in lower case? (Example: cs01)"
$VHDDrive = Get-Volume | Out-GridView -PassThru -Title "Choose the VHD Drive"
$VHDPath = ($($VHDDrive).DriveLetter)
$ParentDisk = Get-Item -Path "$($VHDPath):\VHDs\Parent\*.vhdx" | Out-GridView -PassThru -Title "Choose the parent disk"

New-VHD -Path 'C:\Users\Public\Documents\Hyper-V\Virtual hard disks\client.vhdx' -ParentPath $ParentDisk
New-VM -Name Client -SwitchName Public -VHDPath 'C:\Users\Public\Documents\Hyper-V\Virtual hard disks\client.vhdx' -Generation 2
Set-VMMemory * -DynamicMemoryEnabled $true
Start-VM *

Read-Host -Prompt "Press enter when all of your VM's are fully booted"

$LocalUser = 'administrator'
$pwd = ConvertTo-SecureString 'Pa11word' -AsPlainText -Force
$LocalAuth = New-Object System.Management.Automation.PSCredential($LocalUser,$pwd)

Invoke-Command -VMName Client -Credential $LocalAuth -ArgumentList $StationNumber -ScriptBlock {
    param($StationNumber)
    Rename-Computer -NewName "$($StationNumber)-client" -Restart
}
