function Find-PackagePath{
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=1)]$packagesPath,
		[Parameter(Position=1, Mandatory=1)]$packageName
	)
	return (Get-ChildItem($packagesPath+"\"+$packageName+"*")).FullName | Sort-Object $_ | select -last 1
}

function Prepare-Tests
{
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=1)]$testRunnerName,
		[Parameter(Position=1, Mandatory=1)]$publishedTestDirectory,
		[Parameter(Position=2, Mandatory=1)]$testResultDirectory
	)
	$projects = Get-ChildItem $publishedTestDirectory

	if($projects.Count -eq 1)
	{
		Write-Host "1 $testRunnerName project has been found: "
	}
	else
	{
		Write-Host "$projects.Count $testRunnerName projects have been found:"
	}
	Write-Host ($projects | Select $_.Name)

	if(!(Test-Path $testResultDirectory)){
		Write-Host "Creating test results Dir"
		mkdir $testResultDirectory | Out-Null
	}

	#Get the list of test Dlls
	$testAssembliesPaths = $projects | ForEach-Object {$_.FullName+"\"+$_.Name+".dll"}
	$testAssemblies = [string]::Join(" ", $testAssembliesPaths)

	return $testAssemblies
}

function Update-XmlParameters{
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=1)]$xmlFile,
		[Parameter(Position=1, Mandatory=1)]$parameterName,
		[Parameter(Position=2, Mandatory=1)]$value
	)

	Write-Host "file = $xmlFile"
	Write-Host "name = $parameterName"
	Write-Host "value = $value"
	$xmlContent = [xml](Get-Content $xmlFile)

	Write-Host "Pint 17"
	Write-Host $xmlContent.GetElementsByTagName("supportedRuntime")
	Write-Host "Pint 18"

	$node = $xmlContent.parameters.setParameter | where {$_.name -eq $parameterName}
	Write-Host "Pint 19"
	Write-Host $node

	$node.value = $value
	$xmlContent.Save($xmlFile)
}