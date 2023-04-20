PARAM ($Objectname = ($env:username), $ADAttrs = $true, $ReplMetadata = $false, $ToVariable = $false)
#************************************************
# GetADObjectData.ps1
# Version 1.0
# Date: 10/22/2014
# Author: Tim Springston [MS]
# Description: This script will take the parameter of an object name (should work for
#  most object classes) and query AD for that objects distinguishedname
#  in order to query for the AD object attributes and attribute values, and/or will return 
#  the objects per-attribute  AD replication metadata. Attr value is from GC; repl metadata from DC.
#************************************************
$global:FormatEnumerationLimit = -1
$ExportFile = $env:windir + "\temp\ADObjectData.txt"
cls

function GetADObjectDNbyName 
    {
	param ($objectname)
	$ForestInfo = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
	$RootString = "GC://" + $ForestInfo.Name
	$Root = New-Object  System.DirectoryServices.DirectoryEntry($RootString)
	$searcher = New-Object DirectoryServices.DirectorySearcher($Root)
	$searcher.Filter="(|(samaccountname=$objectname)(name=$objectname))"
	$results=$searcher.findone()
		if ($results -ne $null)
			{
			$DN = $results.properties.distinguishedname[0]
			return $DN
			}
	}

	 
function GetADObjectAttrs
    {
	param ([string]$objectname)
	$ForestInfo = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
	$RootString = "GC://" + $ForestInfo.Name
	$Root = New-Object  System.DirectoryServices.DirectoryEntry($RootString)
	$searcher = New-Object DirectoryServices.DirectorySearcher($Root)
	$searcher.Filter="(&(distinguishedname=$objectname))"
	$results=$searcher.findone()
	if ($results -ne $null)
		{
		$Attributes = New-Object PSObject
		[hashtable]	$Attrs = $results.properties
		[array]$keys  = $Attrs.get_Keys()
		foreach ($key in $keys)
			{
			$value = $Attrs.get_item($key)
			Add-Member -InputObject $Attributes -MemberType NoteProperty -Name $key -Value $value
			$value = $null
			}
		}
	return $Attributes
	}
	

function GetObjectMetaData
	{
	param ([string] $objectDN)
	$Domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
	$ContextType = [System.DirectoryServices.ActiveDirectory.DirectoryContextType]"domain"
	$context = new-object System.DirectoryServices.ActiveDirectory.DirectoryContext($ContextType,$Domain.Name)
	$dc = [System.DirectoryServices.ActiveDirectory.DomainController]::findOne($context)
	$metadata = $dc.GetReplicationMetadata($objectDN)
	if ($metadata -ne $null)
		{
		$ReplData = @{}
		foreach ($Value in $metadata.values)
			{
			$replvalues = @{}
			$replvalues.Add("version",$value.version)
			$replvalues.Add("LastOriginatingChangeTime",$value.LastOriginatingChangeTime)
			$replvalues.Add("LastOriginatingInvocationID",$value.LastOriginatingInvocationID)
			$replvalues.Add("OriginatingChangeUsn",$value.OriginatingChangeUsn)
			$replvalues.Add("LocalChangeUsn",$value.LocalChangeUsn)
			$replvalues.Add("OriginatingServer",$value.OriginatingServer)
			$Repldata.Add($value.name,$replvalues)
			}
		return $ReplData
		}
	}


$DN = GetADObjectDNbyName $Objectname
if ($ToVariable -eq $false)
	{
	if ($ADAttrs -eq $true)
		{
		$objectattrs = GetADObjectAttrs $DN
		"Active Directory Attributes for $DN" |  Out-File -FilePath $ExportFile 
		"Active Directory Attributes for $DN" | Out-Host
		"***************************************" | Out-File -FilePath $ExportFile -Append
		"***************************************" | Out-Host
		$objectattrs | Out-File -FilePath $ExportFile -Append
		$objectattrs | Out-Host
		}
	if ($ReplMetaData -eq $true)
		{
		$objectReplData = GetObjectMetaData $DN
		"Active Directory Replication Metadata for $DN" | Out-File -FilePath $ExportFile -Append
		"Active Directory Replication Metadata for $DN" | FL
		 "***************************************" | Out-File -FilePath $ExportFile -Append
		  "***************************************" | Out-Host
		$keys = $objectReplData.get_Keys()
		foreach ($key in $keys)
			{
			$ReplValue = $objectReplData.Item($key)
			"Replication Metadata: $Key" | Out-File -FilePath $ExportFile -Append
			"Replication Metadata: $Key" | Out-Host 
			"********************" | Out-File -FilePath $ExportFile -Append
			"********************" | Out-Host
			$ReplKeys = $ReplValue.Get_Keys()
			foreach ($ReplKey in $ReplKeys)
				{
				$value = $ReplValue.Item($ReplKey)
				"$ReplKey : $value" | Out-File -FilePath $ExportFile -Append
				"$ReplKey : $value" | Out-Host
				}
			" "  | Out-File -FilePath $ExportFile -Append
			" "  | FL
			}
		}
	}
if ($ToVariable -eq $true)
	{
	$ReturnObject = New-Object PSObject
	if ($ADAttrs -eq $true)
		{
		$objectattrs = GetADObjectAttrs $DN
		"Active Directory Attributes for $DN" |  Out-File -FilePath $ExportFile 
		"***************************************" | Out-File -FilePath $ExportFile -Append
		$objectattrs | Out-File -FilePath $ExportFile -Append
		$ADAttrName = "Attributes"
		Add-Member -InputObject $ReturnObject -MemberType NoteProperty -Name $ADAttrName -Value $objectattrs
		}
	if ($ReplMetaData -eq $true)
		{
		$objectReplData = GetObjectMetaData $DN
		$ADMetadataName = "Metadata"
		Add-Member -InputObject $ReturnObject -MemberType NoteProperty -Name $ADMetadataName -Value $objectReplData
		"Active Directory Replication Metadata for $DN" | Out-File -FilePath $ExportFile -Append
		 "***************************************" | Out-File -FilePath $ExportFile -Append
		$keys = $objectReplData.get_Keys()
		foreach ($key in $keys)
			{
			$ReplValue = $objectReplData.Item($key)
			"Replication Metadata: $Key" | Out-File -FilePath $ExportFile -Append
			"********************" | Out-File -FilePath $ExportFile -Append
			$ReplKeys = $ReplValue.Get_Keys()
			foreach ($ReplKey in $ReplKeys)
				{
				$value = $ReplValue.Item($ReplKey)
				"$ReplKey : $value" | Out-File -FilePath $ExportFile -Append
				}
			" "  | Out-File -FilePath $ExportFile -Append
			}
		}
	return $ReturnObject
	}
