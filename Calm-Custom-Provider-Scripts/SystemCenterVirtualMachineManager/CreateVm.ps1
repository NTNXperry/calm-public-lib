#name             "CreateVm"
#maintainer       "Calm.io"
#maintainer_email "ops.calm.io"
#description      "This script creates VM using existing vm in system center virtual machine manager"

#Input Args:
## VM_NAME
## VM_IMAGE
## CPU
## MEMORY
#Output Args
## HOST_IP

$vmmServerName = "localhost"
$vmName = "@@{VM_NAME}@@"
$HostName ="svrdell1.mtc.com"
$VMPath = "C:\ProgramData\Microsoft\Windows\Hyper-V"
$ScsiAdapterCount="1"
$cpuCount="@@{CPU}@@"
$reqRamSize="@@{MEMORY}@@"
$DVDDriveCount="1"
$networkAdapterCount = "1"
$Description = "This is $($vmName) Profile"
$vm_image="@@{VM_IMAGE}@@"

Import-Module "C:\Program Files\Microsoft System Center 2012 R2\Virtual Machine Manager\bin\psModules\virtualmachinemanager\virtualmachinemanager.psd1"

$JobGroup = [System.Guid]::NewGuid()
$ProfileName = "Temp_$vmName"

if($vm_image -eq "centos"){
  $ImageName="centos"
  $ImageId="9d6bfe61-581a-425a-b859-423e2135ae10"
  $VirtualNetworkAdapter = Get-SCVirtualNetworkAdapter -VMMServer localhost -Name "centos" -ID "f47856cf-4f6e-4feb-9b56-9d3d35bc9ddd"
}
elseif($vm_image -eq "windows"){
  $ImageName="Test"
  $ImageId="fb049a5a-34d2-4c49-9675-a245916cd873"
  $VirtualNetworkAdapter = Get-SCVirtualNetworkAdapter -VMMServer localhost -Name "Test" -ID "be1b548d-017b-454c-8410-d43f5bda43ab"
}
elseif($vm_image -eq "ubuntu"){
  $ImageName="ubuntu-image"
  $ImageId="769b445f-ec2f-400f-8d94-cd2bc88d5c78"
  $VirtualNetworkAdapter = Get-SCVirtualNetworkAdapter -VMMServer localhost -Name "ubuntu-image" -ID "3fb23c8c-60ff-4441-bd8e-e0f71a753f74"
}



if (Get-SCVirtualMachine -VMMServer $vmmServerName -VMHost $HostName -Name $vmName)
{
 Write-Output "VM with name $vmName already exists on the Host $HostName.."
 Write-Output "Kindly provide different VM Name to proceed further.."
}
else
{
 Write-Output "Fetching the Host for $vmName.."
 $VMHost = get-SCVMHost -ComputerName $HostName
   if (!$VMHost )
   {
    Write-Output "HostName $HostName not found in VMM Server..Provide correct Host Name"
   }
 else
   {
     for($i=0 ; $i -lt $ScsiAdapterCount ;$i++)
   {
   Write-Output "Adding $i SCSI Adapter to HardwareProfile Template"
   New-SCVirtualScsiAdapter -VMMServer $vmmServerName -JobGroup $JobGroup -AdapterID 255 -ShareVirtualScsiAdapter $false -ScsiControllerType DefaultTypeNoType
   }

  for($j=0 ; $j -lt $DVDDriveCount ;$j++)
  {
   Write-Output "Adding $j DVD Drive to HardwareProfile Template"
   New-SCVirtualDVDDrive -VMMServer $vmmServerName -JobGroup $JobGroup -Bus 1 -LUN 0
  }
  Write-Output "Checking whether the HardwareProfile Exists or Not"

  if ( Get-SCHardwareProfile -VMMServer $vmmServerName | where { $_.Name -eq $ProfileName } )
  {
   Write-Output "HardwareProfile $ProfileName exists and proceeding to remove it"
   Get-SCHardwareProfile -VMMServer $vmmServerName | where { $_.Name -eq $ProfileName } | Remove-SCHardwareProfile | out-null
  }
  $VMNetwork = Get-SCVMNetwork -VMMServer $vmmServerName -Name "MTC" -ID "05c30e42-f108-49c8-b2ac-b4d7b4b4713c"
  if (!$VMNetwork){
  Write-Output "Vm Network not found"
  exit
  }

  Write-Output "Creating HardwareProfile Template creating for Static RAM"
  $HardwareProfile = New-SCHardwareProfile -VMMServer $vmmServerName -Name $ProfileName -Description $Description -CPUCount $cpuCount -MemoryMB $reqRamSize -DynamicMemoryEnabled $false -MemoryWeight 5000 -VirtualVideoAdapterEnabled $false -CPUExpectedUtilizationPercent 20 -DiskIops 0 -CPUMaximumPercent 100 -CPUReserve 0 -NumaIsolationRequired $false -NetworkUtilizationMbps 0 -CPURelativeWeight 100 -HighlyAvailable $false -DRProtectionRequired $false -NumLock $true -BootOrder "CD", "IdeHardDrive", "PxeBoot", "Floppy" -CPULimitFunctionality $false -CPULimitForMigration $false -JobGroup $JobGroup
  Set-SCVirtualNetworkAdapter -VirtualNetworkAdapter $VirtualNetworkAdapter -NoLogicalNetwork -VLanEnabled $false -VirtualNetwork "External" -NoPortClassification -JobGroup $JobGroup
  $VM = Get-SCVirtualMachine -VMMServer localhost -Name $ImageName -ID $ImageId | where {$_.VMHost.Name -eq $VMHost}
  if (!$VM){
  Write-Output "Vm image not available"
  }
  while(Get-SCJob | where { $_.Status -eq "Running" }){
    Write-Output "waiting for other process to complete"
    sleep $(Get-Random -Minimum 1 -Maximum 10)
  }
  Write-Output "Creating New VM $vmName on $VMHost"
  $NewVM = New-SCVirtualMachine -VM $VM -Name $vmName -Description "" -JobGroup $JobGroup -UseDiffDiskOptimization -RunAsynchronously  -VMHost $VMHost -Path $VMPath -HardwareProfile $HardwareProfile -StartAction AlwaysAutoTurnOnVM -DelayStartSeconds 0 -StopAction SaveVM -StartVM
}
}
while($true){

    if((Get-SCVirtualMachine $VmName | select "Status" -ExpandProperty "Status") -eq "Running"){
        break
    }
    else{
        sleep 3
    }
}


Write-Output "Vm $($VmName) Running"

while($true){
    if((get-SCVirtualNetworkAdapter -VM $VmName -ErrorAction SilentlyContinue | select IPv4Addresses -ExpandProperty "IPv4Addresses") -eq $Null){
    sleep 3
    }
    else{
    $IP=get-SCVirtualNetworkAdapter -VM $VmName | select IPv4Addresses -ExpandProperty "IPv4Addresses"
    Write-Output "HOST_IP=$($IP)"
    break
    }
}
