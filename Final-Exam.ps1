
Stop-VM * -Force
Remove-VM * -Force
Remove-Item -Path 'C:\Users\Public\Documents\Hyper-V\Virtual hard disks\*.vhdx' -Force
Remove-VMSwitch * -Force
Remove-NetNat * -Confirm:$false

<# # Turn on in class
$vhd_disk = Get-Volume -FileSystemLabel VHD
$vhd_path = ($($vhd_disk).DriveLetter)
$parent_disk = Get-Item -Path "$($vhd_path):\VHDs\Parent\*.vhdx" | Out-GridView -Title "Choose the parent disk" -PassThru
#>

    # Turn on at home
$VHDX_Drive = Get-Volume | ogv -Title 'Pick Virtual Drive: ' -PassThru;
$VHDX_Path = $VHDX_Drive.DriveLetter
$parent_disk = Get-Item -Path "$($VHDX_Path):\Users\Public\Documents\Hyper-V\Parent Hard Disks\*.vhdx" | ogv -Title 'Pick Parent Disk:' -PassThru



<# # Turn on in class
New-VMSwitch -SwitchType Private -Name WEST
New-VMSwitch -SwitchType Private -Name WAN
New-VMSwitch -SwitchType Private -Name EAST
$publicNIC = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
New-VMSwitch -NetAdapterInterfaceDescription $publicNIC.InterfaceDescription -Name Public
#>

    # Turn on at home
New-VMSwitch -SwitchType Private -Name WEST
New-VMSwitch -SwitchType Private -Name WAN
New-VMSwitch -SwitchType Private -Name EAST
$publicNIC = Get-NetAdapter | Where-Object { $_.Name -eq "Ethernet" }
New-VMSwitch -NetAdapterInterfaceDescription $publicNIC.InterfaceDescription -Name Public


$server_array = "DC1", "DC2", "DC3", "RouterA"

foreach ($server_name in $server_array) {
    New-VHD -ParentPath $parent_disk -Path "C:\Users\Public\Documents\Hyper-V\Virtual hard disks\$($server_name).vhdx"
    New-VM -Name "$($server_name)" -SwitchName WEST -VHDPath "C:\Users\Public\Documents\Hyper-V\Virtual hard disks\$($server_name).vhdx" -Generation 2
}

$server_array = "DC4", "DC5", "CA", "WWW", "RouterB"

foreach ($server_name in $server_array) {
    New-VHD -ParentPath $parent_disk -Path "C:\Users\Public\Documents\Hyper-V\Virtual hard disks\$($server_name).vhdx"
    New-VM -Name "$($server_name)" -SwitchName EAST -VHDPath "C:\Users\Public\Documents\Hyper-V\Virtual hard disks\$($server_name).vhdx" -Generation 2
}

Set-VMMemory -DynamicMemoryEnabled $true *

$server_array = "DC1", "DC2", "DC3", "DC4", "DC5", "CA", "WWW", "RouterA", "RouterB"

foreach ($server_name in $server_array) {
    Start-VM $server_name
}


function Wait-ForBoot() {
    $Menu = [ordered]@{
        1 = 'No'
        2 = 'Yes'
    }

    $Result = $Menu | Out-GridView -PassThru  -Title 'Are the machines booted'
    Switch ($Result)  {
        {$Result.Name -eq 1} { Wait-ForBoot }
        {$Result.Name -eq 2} { Configure-Machine }  
    }
}

function Configure-Machine() {

    $localUser = 'administrator'
    $domainUser = 'contoso\administrator'
    $pwd = ConvertTo-SecureString 'Pa11word' -AsPlainText -Force
    $localAuth = New-Object System.Management.Automation.PSCredential($localUser,$pwd)
    $domainAuth = New-Object System.Management.Automation.PSCredential($domainUser,$pwd)

    Invoke-Command -VMName DC1 -Credential $localAuth -ScriptBlock {
        New-NetIPAddress -IPAddress 172.16.0.2 -PrefixLength 21 -InterfaceAlias Ethernet -DefaultGateway 172.16.0.1
        Set-DnsClientServerAddress -ServerAddresses 10.13.2.5,10.13.2.7 -InterfaceAlias *
        Install-WindowsFeature -Name ad-domain-services -IncludeManagementTools -Restart
        Rename-Computer -NewName cs03-dc1 -Restart
    }


    Invoke-Command -VMName RouterA -Credential $localAuth -ScriptBlock {
        Rename-NetAdapter -Name Ethernet -NewName WEST
        New-NetIPAddress -IPAddress 172.16.0.1 -PrefixLength 21 -InterfaceAlias WEST
    }

    Add-VMNetworkAdapter -VMName RouterA -SwitchName WAN

    Invoke-Command -VMName RouterA -Credential $localAuth -ScriptBlock {
        Rename-NetAdapter -Name Ethernet -NewName WAN
        New-NetIPAddress -IPAddress 172.16.16.1 -PrefixLength 30 -InterfaceAlias WAN
    }

    Add-VMNetworkAdapter -VMName RouterA -SwitchName Public

    Invoke-Command -VMName RouterA -Credential $localAuth -ScriptBlock {
        Rename-NetAdapter -Name Ethernet -NewName Public
        New-NetIPAddress -IPAddress 10.3.13.3 -PrefixLength 22  -InterfaceAlias Public -DefaultGateway 10.3.12.1
        Set-DnsClientServerAddress -ServerAddresses 172.16.0.2 -InterfaceAlias *
        Install-WindowsFeature -Name routing -IncludeManagementTools -Restart
        Rename-Computer -NewName cs03-routera -Restart
    }


    Invoke-Command -VMName DC2 -Credential $localAuth -ScriptBlock {
        New-NetIPAddress -IPAddress 172.16.0.3 -PrefixLength 21 -InterfaceAlias Ethernet -DefaultGateway 172.16.0.1
        Set-DnsClientServerAddress -ServerAddresses 172.16.0.2 -InterfaceAlias *
        Install-WindowsFeature -Name ad-domain-services -IncludeManagementTools -Restart
        Rename-Computer -NewName cs03-dc2 -Restart
    }


    Invoke-Command -VMName DC3 -Credential $localAuth -ScriptBlock {
        New-NetIPAddress -IPAddress 172.16.0.4 -PrefixLength 21 -InterfaceAlias Ethernet -DefaultGateway 172.16.0.1
        Set-DnsClientServerAddress -ServerAddresses 172.16.0.2 -InterfaceAlias *
        Install-WindowsFeature -Name ad-domain-services -IncludeManagementTools -Restart
        Rename-Computer -NewName cs03-dc3 -Restart
    }


#------------------------------------------------------------------------------------------------------------------------
    Invoke-Command -VMName RouterB -Credential $LocalAuth -ScriptBlock {
        Rename-NetAdapter -Name Ethernet -NewName EAST
        New-NetIPAddress -IPAddress 172.16.8.1 -PrefixLength 21 -InterfaceAlias EAST
    }

    Add-VMNetworkAdapter -VMName RouterB -SwitchName WAN

    Invoke-Command -VMName RouterB -Credential $LocalAuth -ScriptBlock {
        Rename-NetAdapter -Name Ethernet -NewName WAN
        New-NetIPAddress -IPAddress 172.16.16.2 -PrefixLength 30 -InterfaceAlias WAN
    }

    Add-VMNetworkAdapter -VMName RouterB -SwitchName Public

    Invoke-Command -VMName RouterB -Credential $LocalAuth -ScriptBlock {
        Rename-NetAdapter -Name Ethernet -NewName Public
        New-NetIPAddress -IPAddress 10.3.14.1 -PrefixLength 22  -InterfaceAlias Public -DefaultGateway 10.3.12.1
        Install-WindowsFeature -Name routing -IncludeManagementTools -Restart
        Rename-Computer -NewName cs03-routerb -Restart
    }

     Invoke-Command -VMName DC4 -Credential $localAuth -ScriptBlock {
        New-NetIPAddress -IPAddress 172.16.8.2 -PrefixLength 21 -InterfaceAlias Ethernet -DefaultGateway 172.16.8.1
        Set-DnsClientServerAddress -ServerAddresses 172.16.0.2 -InterfaceAlias *
        Install-WindowsFeature -Name ad-domain-services -IncludeManagementTools -Restart
        Rename-Computer -NewName cs03-dc4 -Restart
    }

    Invoke-Command -VMName DC5 -Credential $localAuth -ScriptBlock {
        New-NetIPAddress -IPAddress 172.16.8.3 -PrefixLength 21 -InterfaceAlias Ethernet -DefaultGateway 172.16.8.1
        Set-DnsClientServerAddress -ServerAddresses 172.16.0.2 -InterfaceAlias *
        Install-WindowsFeature -Name ad-domain-services -IncludeManagementTools -Restart
        Rename-Computer -NewName cs03-dc5 -Restart
    }

    Invoke-Command -VMName CA -Credential $localAuth -ScriptBlock {
        New-NetIPAddress -IPAddress 172.16.8.4 -PrefixLength 21 -InterfaceAlias Ethernet -DefaultGateway 172.16.8.1
        Set-DnsClientServerAddress -ServerAddresses 172.16.8.2 -InterfaceAlias *
        #Install-WindowsFeature -Name Adcs-Cert-Authority -IncludeManagementTools -Restart
        Rename-Computer -NewName cs03-ca -Restart
    }

    Invoke-Command -VMName WWW -Credential $localAuth -ScriptBlock {
        New-NetIPAddress -IPAddress 172.16.8.5 -PrefixLength 21 -InterfaceAlias Ethernet -DefaultGateway 172.16.8.1
        Set-DnsClientServerAddress -ServerAddresses 172.16.8.2 -InterfaceAlias *
        #Install-WindowsFeature -Name web-server,web-asp-net,web-management-console -IncludeManagementTools -Restart
        Rename-Computer -NewName cs03-www -Restart
    }


}




function Setup-Machines(){

    $localUser = 'administrator'
    $domainUser = 'contoso\administrator'
    $pwd = ConvertTo-SecureString 'Pa11word' -AsPlainText -Force
    $localAuth = New-Object System.Management.Automation.PSCredential($localUser,$pwd)
    $domainAuth = New-Object System.Management.Automation.PSCredential($domainUser,$pwd)

    Invoke-Command -VMName RouterB -Credential $LocalAuth -ScriptBlock {
        New-NetRoute -DestinationPrefix "172.16.0.0" -InterfaceIndex 30 -NextHop 172.16.16.1 #255.255.248.0
    }

    Invoke-Command -VMName RouterA -Credential $LocalAuth -ScriptBlock {
        New-NetRoute -DestinationPrefix "172.16.8.0" -InterfaceIndex 30 -NextHop 172.16.16.2 #255.255.248.0
    }

    Invoke-Command -VMName DC1 -Credential $localAuth -ArgumentList $pwd -ScriptBlock {
        param($pwd)
        Install-AddsForest -DomainName contoso.com -SafeModeAdministratorPassword $pwd -Force
   
       
    }

    Read-Host "Wait for DC1 to complete"


    Invoke-Command -VMName DC1 -Credential $domainAuth -ArgumentList $pwd -ScriptBlock {
        Add-DnsServerPrimaryZone -NetworkId 172.16/16 -ReplicationScope Forest
        Register-DnsClient
        Add-DnsServerZoneDelegation -Name "contoso.com" -ChildZoneName "child" -NameServer "cs03-dc2.child.contoso.com" -IPAddress 172.16.0.3
        Add-DnsServerConditionalForwarderZone -Name "adatum.com" -ReplicationScope "Forest" -MasterServers 172.16.0.4
        New-ADReplicationSubnet -Name "172.16.0.0/21" 
        New-ADReplicationSubnet -Name "172.16.8.0/21" 

    }
    Read-Host "Make the Static Routes."
    Read-Host "Wait for DC1-2 to complete"


    Invoke-Command -VMName DC3 -Credential (Get-Credential adatum\administrator) -ArgumentList $pwd, $domainAuth -ScriptBlock {
        param($pwd, $domainAuth)
        Install-AddsForest -DomainName adatum.com -SafeModeAdministratorPassword $pwd -Force
        
    }

    Read-Host "Wait for DC3 to complete"
    Read-Host "Setup Trust between 2 forests"
    Read-Host "Configure Replication to 15 mins."


    Invoke-Command -VMName DC3 -Credential (Get-Credential adatum\administrator) -ArgumentList $pwd -ScriptBlock {
        Add-DnsServerPrimaryZone -NetworkId 172.16/16 -ReplicationScope Forest
        Register-DnsClient
        
    }
    
    Read-Host "Wait for DC3-2 to complete"


    Invoke-Command -VMName DC4 -Credential $localAuth -ArgumentList $pwd, $domainAuth -ScriptBlock {
        param($pwd, $domainAuth)
        Install-AddsDomainController -DomainName contoso.com -SafeModeAdministratorPassword $pwd -Credential (Get-Credential contoso\administrator) -NoDnsOnNetwork -NoGlobalCatalog -MoveInfrastructureOperationMasterRoleIfNecessary -Force 
        
    }

    Read-Host "Wait for DC4 to complete"


    Invoke-Command -VMName DC2 -Credential $localAuth -ArgumentList $pwd, $domainAuth -ScriptBlock {
        param($pwd, $domainAuth)
        Install-AddsDomain -NewDomainName child -ParentDomainName contoso.com -SafeModeAdministratorPassword $pwd -Credential (Get-Credential contoso\administrator) -Force
    }

    Read-Host "Wait for DC2 to complete"


     Invoke-Command -VMName DC5 -Credential $localAuth -ArgumentList $pwd, $domainAuth -ScriptBlock {
        param($pwd, $domainAuth)
        Install-AddsDomainController -DomainName child.contoso.com -SafeModeAdministratorPassword $pwd -Credential (Get-Credential child\administrator)  -Force
        
        Read-Host "Wait for DC5 to complete"
    }


}



Wait-ForBoot

Read-Host "Pres Enter to Setup Machines."

Setup-Machines




<# Use this within the workstations.

$pwd = ConvertTo-SecureString Pa11word -AsPlaintext -Force

Write-Host  "Waiting for all workstations to be ready."

Install-AddsForest -DomainName contoso.com -SafeModeAdministratorPassword $pwd -Force
Add-DnsServerPrimaryZone -NetworkId 172.16/16 -ReplicationScope Forest
Register-DnsClient

Write-Host  "Waiting for DC1 to be complete"

Install-AddsDomainController -DomainName contoso.com SafeModeAdministratorPassword $pwd -Credential (Get-Credential contoso\administrator) -NoDnsOnNetwork -Force

Write-Host  "Waiting for DC2 to be complete."

Install-AddsDomain -NewDomainName child -ParentDomainName contoso.com SafeModeAdministratorPassword $pwd -Credential (Get-Credential contoso\administrator) -NoDnsonNetwork -Force

Write-Host  "Waiting for DC3 to be complete."

Install-AddsDomainController -DomainName child.contoso SafeModeAdministratorPassword $pwd -Credential (Get-Credential contoso\administrator) -NoGlobalCatalog -Force

Write-Host  "Waiting for DC4 to be complete."

Install-AddsDomainController -DomainName child.contoso SafeModeAdministratorPassword $pwd -Credential (Get-Credential contoso\administrator) -NoGlobalCatalog -Force

Write-Host  "Waiting for DC4 to be complete."

Install-AddsDomainController -DomainName child.contoso SafeModeAdministratorPassword $pwd -Credential (Get-Credential contoso\administrator) -NoGlobalCatalog -Force

Write-Host  "Waiting for DC4 to be complete."

Install-AddsDomainController -DomainName child.contoso SafeModeAdministratorPassword $pwd -Credential (Get-Credential contoso\administrator) -NoGlobalCatalog -Force

Write-Host  "Waiting for DC4 to be complete."

Install-AddsDomainController -DomainName child.contoso SafeModeAdministratorPassword $pwd -Credential (Get-Credential contoso\administrator) -NoGlobalCatalog -Force

Write-Host  "Waiting for DC4 to be complete."

#> # Use this within the workstations.



# DC1 DC2 DC5 DC6 are Parent
# DC3 DC4 DC7 DC8 are Child