﻿$StationNumber = Read-Host -Prompt "Input your station number in lower case? (Example: cs01)"
$VHDDrive = Get-Volume | Out-GridView -PassThru -Title "Choose the VHD Drive"
$VHDPath = ($($VHDDrive).DriveLetter)
$ParentDisk = Get-Item -Path "$($VHDPath):\VHDs\Parent\*.vhdx" | Out-GridView -PassThru -Title "Choose the parent disk"

New-VHD -Path 'C:\Users\Public\Documents\Hyper-V\Virtual hard disks\ipam.vhdx' -ParentPath $ParentDisk
New-VM -Name IPAM -SwitchName Public -VHDPath 'C:\Users\Public\Documents\Hyper-V\Virtual hard disks\ipam.vhdx' -Generation 2
Set-VMMemory * -DynamicMemoryEnabled $true
Start-VM *

Read-Host -Prompt "Press enter when all of your VM's are fully booted"

$LocalUser = 'administrator'
$DomainUser = 'contoso\administrator'
$pwd = ConvertTo-SecureString 'Pa11word' -AsPlainText -Force
$LocalAuth = New-Object System.Management.Automation.PSCredential($LocalUser,$pwd)
$DomainAuth = New-Object System.Management.Automation.PSCredential($DomainUser,$pwd)

Invoke-Command -VMName IPAM -Credential $LocalAuth -ArgumentList $StationNumber,$DomainAuth -ScriptBlock {
    param($StationNumber,$DomainAuth)
    New-NetIPAddress -IPAddress 172.16.0.6 -PrefixLength 16 -InterfaceAlias Ethernet -DefaultGateway 172.16.0.1
    Set-DnsClientServerAddress -ServerAddresses 172.16.0.2,172.16.0.3 -InterfaceAlias Ethernet
    Install-WindowsFeature -Name ipam -IncludeManagementTools -Restart
    Add-Computer -NewName "$($StationNumber)-ipam" -DomainName contoso.com -Credential $DomainAuth -Restart
}