
function ClearSystem {
    Stop-VM * -Force
    Stop-VM * -Force
    Remove-VM * -Force
    Remove-Item -Path 'C:\Users\Public\Documents\Hyper-V\Virtual hard disks\*.vhdx'
    Remove-VMSwitch * -Force
    Remove-NetNat * -Confirm:$false
}


function Login {
    $LocalAdmin = 'administrator'
    $Password = ConvertTo-SecureString 'Pa11word' -AsPlainText -Force
    $AuthObject = New-Object System.Management.Automation.PSCredential($LocalAdmin, $Password)
    return $AuthObject
}


function InitVMs {
    New-VHD -Path 'C:\Users\Public\Documents\Hyper-V\Virtual hard disks\DNS1.vhdx' -ParentPath $VHDX_ParentDrive
    New-VHD -Path 'C:\Users\Public\Documents\Hyper-V\Virtual hard disks\DNS2.vhdx' -ParentPath $VHDX_ParentDrive
    New-VHD -Path 'C:\Users\Public\Documents\Hyper-V\Virtual hard disks\WWW.vhdx' -ParentPath $VHDX_ParentDrive
    New-VHD -Path 'C:\Users\Public\Documents\Hyper-V\Virtual hard disks\DHCP.vhdx' -ParentPath $VHDX_ParentDrive
    New-VM -Name DNS1 -SwitchName Public -VHDPath 'C:\Users\Public\Documents\Hyper-V\Virtual hard disks\DNS1.vhdx' -Generation 2
    New-VM -Name DNS2 -SwitchName Public -VHDPath 'C:\Users\Public\Documents\Hyper-V\Virtual hard disks\DNS2.vhdx' -Generation 2
    New-VM -Name WWW -SwitchName Public -VHDPath 'C:\Users\Public\Documents\Hyper-V\Virtual hard disks\WWW.vhdx' -Generation 2
    New-VM -Name DHCP -SwitchName Public -VHDPath 'C:\Users\Public\Documents\Hyper-V\Virtual hard disks\DHCP.vhdx' -Generation 2
    Set-VMMemory * -DynamicMemoryEnabled $true
    Start-VM *

    Read-Host -Prompt "Press enter when all of your VM's are fully booted"
}


function main {
    
    ClearSystem

    $StationNumber = Read-Host 'Please insert your Station Number: ';
    $VHDX_Drive = Get-Volume | ogv -Title 'Pick Virtual Drive: ' -PassThru;
    $VHDX_Path = $VHDX_Drive.DriveLetter
    $VHDX_ParentDrive = Get-Item -Path "$($VHDX_Path):\Users\Public\Documents\Hyper-V\Parent Hard Disks\*.vhdx" | ogv -Title 'Pick Parent Disk:' -PassThru

    New-VMSwitch -Name Public -SwitchType Internal # Creates Virtual Switch
    New-NetIPAddress -IPAddress 172.16.0.1 -PrefixLength 16 -InterfaceAlias 'vEthernet (Public)' # Sets virtual's swtich default gateway and prefix
    New-NetNat -Name Public -InternalIPInterfaceAddressPrefix 172.16.0.0/16 # Sets 

    InitVMs

    $loginCred = Login

Invoke-Command -VMName DNS1 -Credential $loginCred -ArgumentList $StationNumber -ScriptBlock {
    param($StationNumber)
    New-NetIPAddress -IPAddress 172.16.0.2 -PrefixLength 16 -InterfaceAlias Ethernet -DefaultGateway 172.16.0.1
    Set-DnsClientServerAddress -ServerAddresses 127.0.0.1,172.16.0.3 -InterfaceAlias Ethernet
    Install-WindowsFeature -Name DNS -IncludeManagementTools -Restart
    Rename-Computer -NewName "$($StationNumber)-dns1" -Restart
}

Invoke-Command -VMName DNS2 -Credential $loginCred -ArgumentList $StationNumber -ScriptBlock {
    param($StationNumber)
    New-NetIPAddress -IPAddress 172.16.0.3 -PrefixLength 16 -InterfaceAlias Ethernet -DefaultGateway 172.16.0.1
    Set-DnsClientServerAddress -ServerAddresses 127.0.0.1,172.16.0.2 -InterfaceAlias Ethernet
    Install-WindowsFeature -Name DNS -IncludeManagementTools -Restart
    Rename-Computer -NewName "$($StationNumber)-dns2" -Restart
}

Invoke-Command -VMName DHCP -Credential $loginCred -ArgumentList $StationNumber -ScriptBlock {
    param($StationNumber)
    New-NetIPAddress -IPAddress 172.16.0.4 -PrefixLength 16 -InterfaceAlias Ethernet -DefaultGateway 172.16.0.1
    Set-DnsClientServerAddress -ServerAddresses 172.16.0.2,172.16.0.3 -InterfaceAlias Ethernet
    Install-WindowsFeature -Name dhcp -IncludeManagementTools -Restart
    Rename-Computer -NewName "$($StationNumber)-dhcp" -Restart
}

Invoke-Command -VMName WWW -Credential $loginCred -ArgumentList $StationNumber -ScriptBlock {
    param($StationNumber)
    New-NetIPAddress -IPAddress 172.16.0.5 -PrefixLength 16 -InterfaceAlias Ethernet -DefaultGateway 172.16.0.1
    Set-DnsClientServerAddress -ServerAddresses 172.16.0.2,172.16.0.3 -InterfaceAlias Ethernet
    Install-WindowsFeature -Name Web-WebServer -IncludeManagementTools -Restart
    Rename-Computer -NewName "$($StationNumber)-www" -Restart
}

}


main
















