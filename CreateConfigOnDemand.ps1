# Taken from http://foxdeploy.com/code-and-scripts/dsc-create-configuration-on-demand/

$session = New-PSSession -ComputerName DC01

Write-host "Opening Session to PullServer" 
Invoke-Command -session $session -ScriptBlock {

    #Create our $guid
    $guid = [guid]::NewGuid().Guid

    #Remove-item $env:windir\system32\MonitoringSoftware -Confirm -Force

    Configuration CreateConfig_Install7Zip
    {
    param([string[]]$MachineName="localhost")
    
        Node $MachineName
        {
            File InstallFilesPresent
                {
                Ensure = "Present"
                SourcePath = "\\dc01\Installer"
                DestinationPath = "C:\InstallFiles"
                Type = "Directory"
                Recurse=$true       # can only use this guy on a Directory
                }

            Package MonitoringSoftware
                {
                Ensure = "Present"  # You can also set Ensure to "Absent"
                Path  = "$Env:SystemDrive\Temp\Monitoring\7z920-x64.msi"
                Name = "7-Zip"
                ProductId = "23170F69-40C1-2702-0920-000001000000"
                DependsOn= "[File]InstallFilesPresent"
                }
         
            }
        #EndOFDSC Config
        }

        #Create the .mof for the imaging machine
        $newMof = CreateConfig_Install7Zip -MachineName $guid -OutputPath "$env:PROGRAMFILES\WindowsPowerShell\DscService\Configuration"
        Write-host "Config Created!"
        
        New-DSCCheckSum $newMof.FullName
        
}

Write-Host "Exited Remote Session"
Write-Host "Retrieving `$guid"

$GetGuid = Invoke-Command -session $session -ScriptBlock {$guid}
Write-Host "Retrieved! `n GUID : $GetGuid"

Write-Host "Closing Remote Session"
Remove-PSSession $session



configuration SetPullMode
{
    param ($NodeId)    

    LocalConfigurationManager
    {
        AllowModuleOverwrite = 'True'
        ConfigurationID = $NodeId
        ConfigurationModeFrequencyMins = 60 
        ConfigurationMode = 'ApplyAndAutoCorrect'
        RebootNodeIfNeeded = 'True'
        RefreshMode = 'PULL' 
        DownloadManagerName = 'WebDownloadManager'
        DownloadManagerCustomData = (@{ServerUrl = "http://dc01:8080/psdscpullserver.svc"; AllowUnsecureConnection = “TRUE”})
        
    }
}

Write-Host "Setting Pull Mode for DSC"

SetPullMode -NodeId $GetGuid -OutputPath C:\temp\SetPullMode.mof 
Set-DscLocalConfigurationManager -path C:\temp\SetPullMode.mof -Verbose 

#Get-DscLocalConfigurationManager