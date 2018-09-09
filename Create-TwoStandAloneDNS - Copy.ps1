Stop-VM * -Force
Remove-VM * -Force
Remove-Item -Path 'C:\Users\Public\Documents\Hyper-V\Virtual hard disks\*.vhdx'
Remove-VMSwitch * -Force
Remove-NetNat * -Confirm:$false

$StationNumber = Read-Host -Prompt "Input your station number in lower case? (Example: cs01)"
$VHDDrive = Get-Volume | Out-GridView -PassThru -Title "Choose the VHD Drive"
$VHDPath = ($($VHDDrive).DriveLetter)
$ParentDisk = Get-Item -Path "$($VHDPath):\VHDs\Parent\*.vhdx" | Out-GridView -PassThru -Title "Choose the parent disk"

New-VMSwitch -Name Public -SwitchType Internal
New-NetIPAddress -IPAddress 172.16.0.1 -PrefixLength 16 -InterfaceAlias 'vEthernet (Public)'
New-NetNat -Name Public -InternalIPInterfaceAddressPrefix 172.16.0.0/16

New-VHD -Path 'C:\Users\Public\Documents\Hyper-V\Virtual hard disks\dns1.vhdx' -ParentPath $ParentDisk
New-VM -Name DNS1 -SwitchName Public -VHDPath 'C:\Users\Public\Documents\Hyper-V\Virtual hard disks\dns1.vhdx' -Generation 2
New-VHD -Path 'C:\Users\Public\Documents\Hyper-V\Virtual hard disks\dns2.vhdx' -ParentPath $ParentDisk
New-VM -Name DNS2 -SwitchName Public -VHDPath 'C:\Users\Public\Documents\Hyper-V\Virtual hard disks\dns2.vhdx' -Generation 2
Set-VMMemory * -DynamicMemoryEnabled $true
Start-VM *

Read-Host -Prompt "Press enter when all of your VM's are fully booted"

$LocalUser = 'administrator'
$pwd = ConvertTo-SecureString 'Pa11word' -AsPlainText -Force
$LocalAuth = New-Object System.Management.Automation.PSCredential($LocalUser,$pwd)

Invoke-Command -VMName DNS1 -Credential $LocalAuth -ArgumentList $StationNumber -ScriptBlock {
    param($StationNumber)
    New-NetIPAddress -IPAddress 172.16.0.2 -PrefixLength 16 -InterfaceAlias Ethernet -DefaultGateway 172.16.0.1
    Set-DnsClientServerAddress -ServerAddresses 127.0.0.1,172.16.0.3 -InterfaceAlias Ethernet
    Install-WindowsFeature -Name DNS -IncludeManagementTools -Restart
    Rename-Computer -NewName "$($StationNumber)-dns1" -Restart
}

Invoke-Command -VMName DNS2 -Credential $LocalAuth -ArgumentList $StationNumber -ScriptBlock {
    param($StationNumber)
    New-NetIPAddress -IPAddress 172.16.0.3 -PrefixLength 16 -InterfaceAlias Ethernet -DefaultGateway 172.16.0.1
    Set-DnsClientServerAddress -ServerAddresses 127.0.0.1,172.16.0.2 -InterfaceAlias Ethernet
    Install-WindowsFeature -Name DNS -IncludeManagementTools -Restart
    Rename-Computer -NewName "$($StationNumber)-dns2" -Restart
}