Include ".\helpers.ps1"
properties {
	$testMessage = "Executed Test!!"
	$solutionDirectory = (Get-Item $solutionFile).DirectoryName
	$outputDirectory= "$solutionDirectory\.build"
	$temporaryOutputDirectory = "$outputDirectory\temp"
	$testResultDirectory = "$outputDirectory\TestResults"
	$MSTestResultsDirectory = "$testResultDirectory\MSTest"
	$buildConfiguration = "Release"
	$buildPlatform = "Any CPU"
	$vsTestExe = (Get-ChildItem ("C:\Program Files (x86)\Microsoft Visual Studio*\Common7\IDE\CommonExtensions\Microsoft\TestWindow\vstest.console.exe")).FullName | Sort-Object $_ | select -last 1
	#$msTestExe =  (Get-ChildItem ("C:\Program Files*\Microsoft Visual Studio*\Common7\IDE\MSTest.exe")).FullName | Sort-Object $_ | select -last 1
	$dbUpExecutableName = "SchemaMigration.exe"
	$DBConnectionString = "Data Source=.\SQLEXPRESS;Integrated Security=True;Initial Catalog=Connection"
}
FormatTaskName "`r`n`r`n------- Executing {0} Task --------"

task default -depends Test

task Init -description 'Initialises the build by removing previous artifacts and creating output directories' -requiredVariables outputDirectory, temporaryOutputDirectory {
	Assert -conditionToCheck ("Debug", "Release" -contains $buildConfiguration) `
			-failureMessage "Invalid build Configuration $buildConfiguration. Valid values are Debug or Release"
	Assert ("x86", "x64", "Any CPU" -contains $buildPlatform) `
	"Invalid build platform $buildPlatform."
	Assert (Test-Path $vsTestExe) "vsTestExe missing"
	if(Test-Path $outputDirectory){
		Remove-Item $outputDirectory -Force -Recurse 
	}

	Write-Host "Creating output directory located at $outputDirectory"
	New-Item "$outputDirectory" -ItemType Directory | Out-Null
	New-Item "$temporaryOutputDirectory" -ItemType Directory | Out-Null
}


task Clean -description "Remove temp files" {
	Write-Host 'Executed Clean!'
}

task Compile -depends Init `
-requiredVariables solutionFile, buildConfiguration, buildPlatform, temporaryOutputDirectory `
 {
	Write-Host 'Building $solutionFile'
	Exec {
	 msbuild $solutionFile "/p:Configuration=$buildConfiguration;Platform=$buildPlatform;OutDir=$temporaryOutputDirectory"
	}
}

task Test -depends Compile ,databaseMigration, TestMSTest{
	Write-Host $testMessage
}

task TestMSTest -depends Compile -description "Run MSTest test" `
	-precondition {return Test-Path $temporaryOutputDirectory} {
		$testdlls = (Get-ChildItem($temporaryOutputDirectory+"\"+"*.tests.dll")).FullName
		$testAssemblies = [string]::Join(" ",$testdlls)
		if(!(Test-Path $testResultDirectory)){
			Write-Host "Creating test results Dir"
			mkdir $MSTestResultsDirectory | Out-Null
		}
		Push-Location $MSTestResultsDirectory
		Exec { &$vsTestExe $testAssemblies /Logger:trx }
		#Exec { &$msTestExe $testAssemblies /Logger:trx }
		Pop-Location

		Move-Item -path $MSTestResultsDirectory\TestResults\*.trx -destination $MSTestResultsDirectory\MSTest.trx
		Remove-Item $MSTestResultsDirectory\TestResults
}

task databaseMigration -depends Compile -description "Run Dbup based Schema Migration" {
	Write-Host "Running database Migration"
	$migrationExe = (Get-ChildItem($temporaryOutputDirectory+"\"+$dbUpExecutableName))
	Assert (Test-Path $migrationExe) "Db Exe missing at $migrationExe"
	Exec { &$migrationExe $DBConnectionString /CreateDatabaseIfMissing}
}
