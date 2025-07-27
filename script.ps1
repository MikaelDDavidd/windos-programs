#Requires -RunAsAdministrator

param(
    [switch]$SkipBloatware,
    [switch]$SkipPrograms,
    [switch]$SkipDrivers
)

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

$LogFile = "$env:TEMP\InstallLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$DriversFolder = "$env:TEMP\Drivers"
$GoogleDriveFolderID = "1ysArgN8PInr9NIc_ju1F5ueuOXWCgvkA"

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    $colors = @{
        "Green" = [ConsoleColor]::Green; "Red" = [ConsoleColor]::Red
        "Yellow" = [ConsoleColor]::Yellow; "Cyan" = [ConsoleColor]::Cyan
        "White" = [ConsoleColor]::White
    }
    Write-Host $Message -ForegroundColor $colors[$Color]
    Add-Content -Path $LogFile -Value "$(Get-Date -Format 'HH:mm:ss') - $Message"
}

function Show-Progress {
    param([string]$Activity, [int]$Current, [int]$Total, [string]$Status)
    $percent = [math]::Round(($Current / $Total) * 100)
    Write-Progress -Activity $Activity -Status $Status -PercentComplete $percent
}

function Test-Prerequisites {
    Write-ColorOutput "`n🔍 Verificando pré-requisitos..." "Cyan"
    
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-ColorOutput "❌ Execute como Administrador!" "Red"
        exit 1
    }
    
    if (-not (Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet)) {
        Write-ColorOutput "❌ Sem conexão com a internet!" "Red"
        exit 1
    }
    
    Write-ColorOutput "✅ Pré-requisitos OK" "Green"
}

function Install-PackageManagers {
    Write-ColorOutput "`n📦 Configurando gerenciadores de pacotes..." "Cyan"
    
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-ColorOutput "⚠️ Winget não encontrado. Instalando..." "Yellow"
        Invoke-WebRequest -Uri "https://aka.ms/getwinget" -OutFile "$env:TEMP\winget.msixbundle"
        Add-AppxPackage "$env:TEMP\winget.msixbundle"
    }
    
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-ColorOutput "⚠️ Chocolatey não encontrado. Instalando..." "Yellow"
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    }
    
    Write-ColorOutput "✅ Gerenciadores configurados" "Green"
}

function Remove-Bloatware {
    if ($SkipBloatware) { return }
    
    Write-ColorOutput "`n🗑️ FASE 1: Removendo bloatware..." "Cyan"
    
    $bloatware = @(
        "Microsoft.BingWeather", "Microsoft.GetHelp", "Microsoft.Getstarted",
        "Microsoft.Messaging", "Microsoft.MicrosoftOfficeHub", "Microsoft.OneConnect",
        "Microsoft.People", "Microsoft.Print3D", "Microsoft.SkypeApp",
        "Microsoft.Wallet", "Microsoft.WindowsMaps", "microsoft.windowscommunicationsapps",
        "Microsoft.WindowsSoundRecorder", "Microsoft.Xbox.TCUI", "Microsoft.XboxApp",
        "Microsoft.XboxGameOverlay", "Microsoft.XboxIdentityProvider", "Microsoft.XboxSpeechToTextOverlay",
        "Microsoft.ZuneMusic", "Microsoft.ZuneVideo", "Microsoft.YourPhone",
        "Microsoft.MixedReality.Portal", "Microsoft.ScreenSketch", "Microsoft.XboxGamingOverlay",
        "*EclipseManager*", "*ActiproSoftwareLLC*", "*AdobeSystemsIncorporated.AdobePhotoshopExpress*",
        "*Duolingo-LearnLanguagesforFree*", "*PandoraMediaInc*", "*CandyCrushSaga*",
        "*BubbleWitch3Saga*", "*Wunderlist*", "*Flipboard*", "*Twitter*", "*Facebook*",
        "*Spotify*", "*Minecraft*", "*Royal Revolt*", "*Sway*", "*Speed Test*", "*Dolby*"
    )
    
    $onedrive = @(
        "Microsoft.OneDrive", "Microsoft.OneDriveSync"
    )
    
    $allToRemove = $bloatware + $onedrive
    $total = $allToRemove.Count
    
    for ($i = 0; $i -lt $total; $i++) {
        $app = $allToRemove[$i]
        Show-Progress "Removendo Bloatware" ($i + 1) $total "Removendo: $app"
        
        try {
            Get-AppxPackage -Name $app -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
            Get-AppxProvisionedPackage -Online | Where-Object DisplayName -like $app | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
            Write-ColorOutput "✅ Removido: $app" "Green"
        }
        catch {
            Write-ColorOutput "⚠️ Não encontrado: $app" "Yellow"
        }
    }
    
    try {
        Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
        Start-Process -FilePath "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" -ArgumentList "/uninstall" -Wait -ErrorAction SilentlyContinue
        Write-ColorOutput "✅ OneDrive desinstalado" "Green"
    }
    catch {
        Write-ColorOutput "⚠️ OneDrive não encontrado" "Yellow"
    }
    
    Write-Progress "Removendo Bloatware" -Completed
    Write-ColorOutput "✅ FASE 1 CONCLUÍDA: Bloatware removido" "Green"
}

function Install-Programs {
    if ($SkipPrograms) { return }
    
    Write-ColorOutput "`n📥 FASE 2: Instalando programas..." "Cyan"
    
    $programs = @(
        @{Name="Driver Booster"; Winget="IObit.DriverBooster"; Choco="driverbooster"},
        @{Name="Google Chrome"; Winget="Google.Chrome"; Choco="googlechrome"},
        @{Name="Discord"; Winget="Discord.Discord"; Choco="discord"},
        @{Name="Steam"; Winget="Valve.Steam"; Choco="steam"},
        @{Name="EA Desktop"; Winget="ElectronicArts.EADesktop"; Choco="ea-desktop"},
        @{Name="Epic Games Launcher"; Winget="EpicGames.EpicGamesLauncher"; Choco="epicgameslauncher"},
        @{Name="Riot Client"; Winget="RiotGames.RiotClient"; Choco="riot-games"},
        @{Name="MSI Afterburner"; Winget="Guru3D.Afterburner"; Choco="msiafterburner"},
        @{Name="Blitz"; Winget="Blitz.Blitz"; Choco="blitz"}
    )
    
    $total = $programs.Count
    
    for ($i = 0; $i -lt $total; $i++) {
        $prog = $programs[$i]
        Show-Progress "Instalando Programas" ($i + 1) $total "Instalando: $($prog.Name)"
        
        $success = $false
        
        if ($prog.Winget) {
            try {
                $result = winget install --id $prog.Winget --silent --accept-package-agreements --accept-source-agreements 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $success = $true
                    Write-ColorOutput "✅ $($prog.Name) instalado via Winget" "Green"
                }
            }
            catch {}
        }
        
        if (-not $success -and $prog.Choco) {
            try {
                choco install $prog.Choco -y --limit-output | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    $success = $true
                    Write-ColorOutput "✅ $($prog.Name) instalado via Chocolatey" "Green"
                }
            }
            catch {}
        }
        
        if (-not $success) {
            Write-ColorOutput "❌ Falha ao instalar: $($prog.Name)" "Red"
        }
    }
    
    Write-Progress "Instalando Programas" -Completed
    Write-ColorOutput "✅ FASE 2 CONCLUÍDA: Programas instalados" "Green"
}

function Get-GoogleDriveFiles {
    param([string]$FolderID)
    
    try {
        $apiUrl = "https://www.googleapis.com/drive/v3/files?q='$FolderID'+in+parents&key=AIzaSyB0wLNh1MD05si3JMVzQhSBW4i4zK7-dBI"
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get
        return $response.files
    }
    catch {
        Write-ColorOutput "❌ Erro ao acessar Google Drive: $($_.Exception.Message)" "Red"
        return @()
    }
}

function Download-GoogleDriveFile {
    param([string]$FileID, [string]$FileName, [string]$Destination)
    
    try {
        $downloadUrl = "https://drive.google.com/uc?export=download&id=$FileID"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $Destination -UseBasicParsing
        return $true
    }
    catch {
        Write-ColorOutput "❌ Erro ao baixar $FileName`: $($_.Exception.Message)" "Red"
        return $false
    }
}

function Install-Driver {
    param([string]$DriverPath)
    
    try {
        if ($DriverPath.EndsWith('.zip')) {
            $extractPath = "$DriversFolder\$(Split-Path $DriverPath -LeafBase)"
            Expand-Archive -Path $DriverPath -DestinationPath $extractPath -Force
            
            $setupFiles = Get-ChildItem -Path $extractPath -Recurse -Include "*.exe", "*.msi", "*.inf" | Sort-Object Name
            
            foreach ($file in $setupFiles) {
                if ($file.Extension -eq '.exe') {
                    Start-Process -FilePath $file.FullName -ArgumentList "/S", "/SILENT", "/VERYSILENT" -Wait -NoNewWindow
                    return $true
                }
                elseif ($file.Extension -eq '.msi') {
                    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", "`"$($file.FullName)`"", "/quiet", "/norestart" -Wait -NoNewWindow
                    return $true
                }
                elseif ($file.Extension -eq '.inf') {
                    pnputil /add-driver $file.FullName /install
                    return $true
                }
            }
        }
        
        return $false
    }
    catch {
        Write-ColorOutput "❌ Erro ao instalar driver: $($_.Exception.Message)" "Red"
        return $false
    }
}

function Install-Drivers {
    if ($SkipDrivers) { return }
    
    Write-ColorOutput "`n🔧 FASE 3: Instalando drivers..." "Cyan"
    
    if (-not (Test-Path $DriversFolder)) {
        New-Item -ItemType Directory -Path $DriversFolder -Force | Out-Null
    }
    
    Write-ColorOutput "📡 Conectando ao Google Drive..." "Cyan"
    $driveFiles = Get-GoogleDriveFiles -FolderID $GoogleDriveFolderID
    
    if ($driveFiles.Count -eq 0) {
        Write-ColorOutput "❌ Nenhum driver encontrado no Google Drive" "Red"
        return
    }
    
    Write-ColorOutput "📁 Encontrados $($driveFiles.Count) arquivos" "Green"
    
    for ($i = 0; $i -lt $driveFiles.Count; $i++) {
        $file = $driveFiles[$i]
        Show-Progress "Instalando Drivers" ($i + 1) $driveFiles.Count "Baixando: $($file.name)"
        
        $localPath = "$DriversFolder\$($file.name)"
        
        Write-ColorOutput "⬇️ Baixando: $($file.name)" "Cyan"
        $downloaded = Download-GoogleDriveFile -FileID $file.id -FileName $file.name -Destination $localPath
        
        if ($downloaded) {
            Write-ColorOutput "📦 Instalando: $($file.name)" "Cyan"
            $installed = Install-Driver -DriverPath $localPath
            
            if ($installed) {
                Write-ColorOutput "✅ Driver instalado: $($file.name)" "Green"
            }
            else {
                Write-ColorOutput "❌ Falha ao instalar: $($file.name)" "Red"
            }
        }
    }
    
    Write-Progress "Instalando Drivers" -Completed
    Write-ColorOutput "✅ FASE 3 CONCLUÍDA: Drivers processados" "Green"
}

function Main {
    Clear-Host
    Write-ColorOutput "🚀 SCRIPT DE INSTALAÇÃO AUTOMÁTICA" "Cyan"
    Write-ColorOutput "=" * 50 "Cyan"
    Write-ColorOutput "Log: $LogFile" "Yellow"
    
    Test-Prerequisites
    Install-PackageManagers
    
    Remove-Bloatware
    Install-Programs
    Install-Drivers
    
    Write-ColorOutput "`n🎉 INSTALAÇÃO CONCLUÍDA!" "Green"
    Write-ColorOutput "📄 Log salvo em: $LogFile" "Yellow"
    Write-ColorOutput "🔄 Reinicie o sistema para finalizar" "Yellow"
    
    Read-Host "`nPressione Enter para sair"
}

Main
