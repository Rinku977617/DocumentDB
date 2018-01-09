<# 
.SYNOPSIS 
  Install DocumentDB Hadoop Connector to HDInsight cluster.
   
.DESCRIPTION 
  This installs DocumentDB Hadoop Connector on HDInsight cluster.
  
.EXAMPLE
  .\documentdb-hadoop-installer-v02.ps1
#> 

# Download config action module from a well-known directory.
$CONFIGACTIONURI = "https://hdiconfigactions.blob.core.windows.net/configactionmodulev01/HDInsightUtilities-v01.psm1";
$CONFIGACTIONMODULE = "C:\apps\dist\HDInsightUtilities.psm1";
$webclient = New-Object System.Net.WebClient;
$webclient.DownloadFile($CONFIGACTIONURI, $CONFIGACTIONMODULE);

# (TIP) Import config action helper method module to make writing config action easy.
if (Test-Path ($CONFIGACTIONMODULE))
{ 
    Import-Module $CONFIGACTIONMODULE;
} 
else
{
    Write-Output "Failed to load HDInsightUtilities module, exiting ...";
    exit;
}

# (TIP) Write-HDILog is the way to write to STDOUT and STDERR in HDInsight config action script.
Write-HDILog "Starting DocumentDB Hadoop Connector installation at: $(Get-Date)";

# Define inputs for the DocumenDB Hadoop Connector installation script.
$connectorname = "azure-documentdb-hadoop-1.2.0";
$src = "http://portalcontent.blob.core.windows.net/samples/azure-documentdb-hadoop-1.2.0.zip";
$connectorinstallationdir = $env:HADOOP_HOME + '\share\hadoop\common\lib';

# (TIP) Test whether the destination file already exists and this makes the script idempotent so it functions properly upon reboot and reimage.
if (Test-Path ($connectorinstallationdir + '\' + $connectorname + '.jar'))
{
	Write-HDILog "Destination: $connectorinstallationdir\$connectorname.jar already exists, exiting ...";
	exit;
}

# Download the jar file into local file system.
# (TIP) It is always good to download to user temporary location.
$connectorintermediate = $env:temp + '\' + $connectorname + [guid]::NewGuid() + '.zip';
Save-HDIFile -SrcUri $src -DestFile $connectorintermediate;

# Download extra dependency jar files into local file system.
$jsonname = 'json-20140107';
$jsonsrc = "http://search.maven.org/remotecontent?filepath=org/json/json/20140107/json-20140107.jar";
$jsonintermediate = $env:temp + '\' + $jsonname + [guid]::NewGuid() + '.jar';
Save-HDIFile -SrcUri $jsonsrc -DestFile $jsonintermediate;
$lang3name = 'commons-lang3-3.3.2';
$lang3src = "http://search.maven.org/remotecontent?filepath=org/apache/commons/commons-lang3/3.3.2/commons-lang3-3.3.2.jar";
$lang3intermediate = $env:temp + '\' + $lang3name + [guid]::NewGuid() + '.jar';
Save-HDIFile -SrcUri $lang3src -DestFile $lang3intermediate;

# Unzip the file into final destination
Expand-HDIZippedFile -ZippedFile $connectorintermediate -UnzipFolder $connectorinstallationdir;

# Move dependencies into final destination
Copy-Item -Path $jsonintermediate -Destination ($connectorinstallationdir + '\' + $jsonname + '.jar');
Copy-Item -Path $lang3intermediate -Destination ($connectorinstallationdir + '\' + $lang3name + '.jar');

# Move THIRDPARTYNOTICES to doc directory
New-Item -ItemType directory -Path ($env:HADOOP_HOME + '\share\doc\hadoop\' + $connectorname);
Copy-Item -Path ($connectorinstallationdir + '\THIRDPARTYNOTICES.txt') -Destination ($env:HADOOP_HOME + '\share\doc\hadoop\' + $connectorname);

# Remove the intermediate files we created.
# (TIP) Please clean up temporary files when no longer needed.
Remove-Item $connectorintermediate;
Remove-Item $jsonintermediate;
Remove-Item $lang3intermediate;
Remove-Item ($connectorinstallationdir + '\THIRDPARTYNOTICES.txt');

# Block until /example/jars directory is created on WASB.
while ($true) {
    $output = Invoke-HDICmdScript -CmdToExecute "hadoop fs -ls /example | findstr /c:`"/example/jars`"";
    Write-HDILog $output;
	if ($output) 
    {
		Write-HDILog $output;
        break;
    }
}

# Upload Connector jars to WASB and clean up example jar from directory.
# (TIP) This is the way to capture STDOUT and STDERR for processes printing to console as only Write-HDILog is the way to print to STDOUT and STDERR.
$output = Invoke-HDICmdScript -CmdToExecute "%HADOOP_HOME%\bin\hadoop fs -copyFromLocal $connectorinstallationdir\TallyProperties-v01.jar /example/jars/";
Write-HDILog $output;
$output = Invoke-HDICmdScript -CmdToExecute "%HADOOP_HOME%\bin\hadoop fs -chmod 644 /example/jars/TallyProperties-v01.jar";
Write-HDILog $output;
Remove-Item ($connectorinstallationdir + '\TallyProperties-v01.jar');

Write-HDILog "Done with DocumentDB Hadoop Connector installation at: $(Get-Date)";
Write-HDILog "Installed DocumentDB Hadoop Connector at: $connectorinstallationdir\$connectorname";