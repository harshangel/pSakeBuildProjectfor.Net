Include ".\helpers.ps1"
Include ".\teamcity.ps1"
properties {
	$base_dir = resolve-path .\..
	$settingsDirectory = "$base_dir\Build\Settings"
	. $settingsDirectory\$env.ps1
	$build_artifacts_dir = "$base_dir\build_artifacts"
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
	$dbUpExecutable = "$temporaryOutputDirectory\SchemaMigration.exe"
	$databaseScriptsDirectory = "CI\Updates"
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

task UpdateConfig -depends Compile -description "Updates config files after compile"{
	#Update database path in web.config and app.config
	Get-ChildItem("$temporaryOutputDirectory\*.dll.config") | ForEach-Object {Update-XmlParameters `
		-xmlFile $_.FullName -parameter}
}

task Test -depends Compile,CreateBuildNumberFile, TestMSTest, Init{
	Write-Host $testMessage
}

task TestMSTest -depends Compile, Init -description "Run MSTest test" `
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

task databaseMigration  -depends initDeploy -description "Run Dbup based Schema Migration" `
-requiredVariables env, dbUpExecutable, databaseScriptsDirectory {
	Write-Host "Running database Migration"
		Write-Output "&$dbUpExecutable $db_Connectionstring $databaseScriptsDirectory /CreateDatabaseIfMissing" 
		Exec { &$dbUpExecutable "$db_Connectionstring" "$databaseScriptsDirectory" /CreateDatabaseIfMissing }
}

task deploy -depends initDeploy, SetDeployBuildNumber, databaseMigration{
	Write-Output "Starting Deploy task" 
	Write-Output "env =" $env
}

task initDeploy -description "Initialized the deploy steps" `
	-requiredVariables env , databaseScriptsDirectory{
	Assert (Test-Path $settingsDirectory\$env.ps1) "enviromental Setting files not found."
	Assert (Test-Path "$build_artifacts_dir\build.number") "Build Number file not found"
	Assert (Test-Path $dbUpExecutable) "Dbup executable not found at $dbUpExecutable"
	#Assert (Test-Path $databaseScriptsDirectory) "Database scripts not found at $databaseScriptsDirectory"
}

task CreateBuildNumberFile{
	"$env:build_number" | Out-File "$temporaryOutputDirectory\build.number" -Encoding ascii -Force
}
task SetDeployBuildNumber {
	$Script:build_no = Get-Content "$build_artifacts_dir\build.number"
	TeamCity-SetBuildNumber $Script:build_no
	Write-Output "Setting build number to "$Script:build_no
}