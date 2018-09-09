# Clean up
Stop-VM * -Force -TurnOff > $null
Remove-VM * -Force > $null
Remove-VMSwitch * -Force -ErrorAction SilentlyContinue > $null
Remove-Item -Force -Path 'C:\Users\Public\Documents\Hyper-V\Virtual hard disks\*.vhdx' > $null
Remove-NetNat * -Confirm:$false

$StationNumber = Read-Host -Prompt "Input your station number in lower case? (Example: cs01)"

$VHDDrive = Get-Volume | Out-GridView -PassThru -Title "Choose the VHD Drive"
$VHDPath = ($($VHDDrive).DriveLetter)
$ParentDisk = Get-Item -Path "$($VHDPath):\VHDs\Parent\*.vhdx" | Out-GridView -PassThru -Title "Choose the parent disk"

New-VMSwitch -Name Public -SwitchType Internal
New-NetIPAddress -IPAddress 172.16.0.1 -InterfaceAlias 'vEthernet (Public)' -PrefixLength 16
New-NetNat -Name Public -InternalIPInterfaceAddressPrefix 172.16.0.0/16

New-VHD -Path 'C:\Users\Public\Documents\Hyper-V\Virtual hard disks\dc.vhdx' -ParentPath $ParentDisk

New-VM -Name DC -SwitchName Public -VHDPath 'C:\Users\Public\Documents\Hyper-V\Virtual hard disks\dc.vhdx' -Generation 2 -Force

Set-VMMemory * -DynamicMemoryEnabled $true
Start-VM *

Read-Host -Prompt "Press enter when all of your VM's are fully booted"

$LocalUser = 'administrator'
$DomainUser = 'contoso\administrator'
$pwd = ConvertTo-SecureString 'Pa11word' -AsPlainText -Force
$LocalAuth = New-Object System.Management.Automation.PSCredential($LocalUser,$pwd)
$DomainAuth = New-Object System.Management.Automation.PSCredential($DomainUser,$pwd)

Invoke-Command -VMName DC -Credential $LocalAuth -ArgumentList $StationNumber -ScriptBlock {
    param($StationNumber)
    New-NetIPAddress -IPAddress 172.16.0.2 -PrefixLength 16 -DefaultGateway 172.16.0.1 -InterfaceAlias Ethernet
    Set-DnsClientServerAddress -ServerAddresses 10.13.2.5,10.13.2.7 -InterfaceAlias *
    Install-WindowsFeature -Name ad-domain-services -IncludeManagementTools -Restart
    Rename-Computer -NewName "$($StationNumber)-dc" -Restart
}

Read-Host -Prompt "Press enter once your DC is booted"

Invoke-Command -VMName DC -Credential $LocalAuth -ArgumentList $pwd -ScriptBlock {
    param($pwd)
    Install-ADDSForest -DomainName contoso.com -SafeModeAdministratorPassword $pwd -Force
}

Read-Host "Press enter once you can sign into your domain controller as the domain admin"

Invoke-Command -VMName DC -Credential $DomainAuth -ScriptBlock {
    Add-DnsServerPrimaryZone -NetworkID 172.16/16 -ReplicationScope Forest
    Register-DnsClient
}