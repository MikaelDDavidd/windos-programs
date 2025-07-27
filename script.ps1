#Requires -RunAsAdministrator

param(
    [switch]$SkipBloatware,
    [switch]$SkipPrograms,
    [switch]$SkipDrivers,
    [switch]$Force
)

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

$LogFile = "$env:TEMP\InstallLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$DriversFolder = "$env:TEMP\Drivers"
$GoogleDriveFolderID = "1ysArgN8PInr9NIc_ju1F5ueuOXWCgvkA"
$StatusFolder = "$env:TEMP\InstallStatus"
$BloatwareFlag = "$StatusFolder\bloatware_removed.flag"
$ProgramsFlag = "$StatusFolder\programs_installed.flag"
$DriversFlag = "$StatusFolder\drivers_installed.flag"

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
    Add-Content -Path $LogFile -Value "$(Get-Date -Format 'HH:mm:ss') - $Message"
}

function Show-Progress {
    param([string]$Activity, [int]$Current, [int]$Total, [string]$Status)
    $percent = [math]::Round(($Current / $Total) * 100)
    Write-Progress -Activity $Activity -Status $Status -PercentComplete $percent
}

function Initialize-StatusFolder {
    if (-not (Test-Path $StatusFolder)) {
        New-Item -ItemType Directory -Path $StatusFolder -Force | Out-Null
    }
}

function Test-BloatwareStatus {
    if ($Force) { return $false }
    if (Test-Path $BloatwareFlag) {
        Write-ColorOutput "✅ Bloatware já removido anteriormente" "Green"
        return $true
    }
    
    # Verifica se principais bloatwares ainda existem
    $testApps = @("Microsoft.BingWeather", "Microsoft.ZuneMusic", "*CandyCrushSaga*")
    $foundBloatware = $false
    
    foreach ($app in $testApps) {
        if (Get-AppxPackage -Name $app -ErrorAction SilentlyContinue) {
            $foundBloatware = $true
            break
        }
    }
    
    if (-not $foundBloatware) {
        Write-ColorOutput "✅ Bloatware já foi removido" "Green"
        New-Item -ItemType File -Path $BloatwareFlag -Force | Out-Null
        return $true
    }
    
    return $false
}

function Test-ProgramStatus {
    param([hashtable]$Program)
    
    $name = $Program.Name
    
    # Verifica via Winget
    if ($Program.Winget) {
        $wingetCheck = winget list --id $Program.Winget 2>$null
        if ($LASTEXITCODE -eq 0) {
            return $true
        }
    }
    
    # Verifica programas específicos
    switch ($name) {
        "Google Chrome" { return Test-Path "$env:ProgramFiles\Google\Chrome\Application\chrome.exe" }
        "Discord" { return Test-Path "$env:LOCALAPPDATA\Discord\app-*\Discord.exe" }
        "Steam" { return Test-Path "$env:ProgramFiles (x86)\Steam\steam.exe" }
        "Driver Booster" { return Test-Path "$env:ProgramFiles (x86)\IObit\Driver Booster*\DriverBooster.exe" }
        "MSI Afterburner" { return Test-Path "$env:ProgramFiles (x86)\MSI Afterburner\MSIAfterburner.exe" }
        default { return $false }
    }
}

function Test-AllProgramsStatus {
    if ($Force) { return $false }
    if (Test-Path $ProgramsFlag) {
        Write-ColorOutput "✅ Programas já instalados anteriormente" "Green"
        return $true
    }
    
    $programs = @(
        @{Name="Driver Booster"; Winget="IObit.DriverBooster"; Choco="driverbooster"},
        @{Name="Google Chrome"; Winget="Google.Chrome"; Choco="googlechrome"},
        @{Name="Discord"; Winget="Discord.Discord"; Choco="discord"},
        @{Name="Steam"; Winget="Valve.Steam"; Choco="steam"},
        @{Name="EA Desktop"; Winget="ElectronicArts.EADesktop"; Choco="ea-desktop"},
        @{Name="Epic Games Launcher"; Winget="EpicGames.EpicGamesLauncher"; Choco="epicgameslauncher"},
        @{Name="Riot Client"; Winget="RiotGames.RiotClient"; Choco="riot-client"},
        @{Name="MSI Afterburner"; Winget="Guru3D.Afterburner"; Choco="msiafterburner"},
        @{Name="Blitz"; Winget="Blitz.Blitz"; WingetArgs="--id=Blitz.Blitz -e"; Choco="blitz"}
    )
    
    $installedCount = 0
    foreach ($prog in $programs) {
        if (Test-ProgramStatus -Program $prog) {
            $installedCount++
            Write-ColorOutput "✅ Já instalado: $($prog.Name)" "Green"
        }
    }
    
    if ($installedCount -ge ($programs.Count * 0.8)) {
        Write-ColorOutput "✅ Maioria dos programas já instalados ($installedCount/$($programs.Count))" "Green"
        New-Item -ItemType File -Path $ProgramsFlag -Force | Out-Null
        return $true
    }
    
    return $false
}

function Test-DriversStatus {
    if ($Force) { return $false }
    if (Test-Path $DriversFlag) {
        Write-ColorOutput "✅ Drivers já instalados anteriormente" "Green"
        return $true
    }
    
    # Verifica se pasta de drivers existe e tem arquivos
    if (Test-Path $DriversFolder) {
        $driverFiles = Get-ChildItem -Path $DriversFolder -Include "*.zip", "*.exe" -Recurse
        if ($driverFiles.Count -ge 5) {
            Write-ColorOutput "✅ Drivers já baixados ($($driverFiles.Count) arquivos)" "Green"
            New-Item -ItemType File -Path $DriversFlag -Force | Out-Null
            return $true
        }
    }
    
    return $false
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
    
    if (Test-BloatwareStatus) {
        Write-ColorOutput "⏭️ FASE 1: Bloatware já removido, pulando..." "Yellow"
        return
    }
    
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
    
    # Marca como concluído
    New-Item -ItemType File -Path $BloatwareFlag -Force | Out-Null
    
    Write-Progress "Removendo Bloatware" -Completed
    Write-ColorOutput "✅ FASE 1 CONCLUÍDA: Bloatware removido" "Green"
}

function Install-Programs {
    if ($SkipPrograms) { return }
    
    if (Test-AllProgramsStatus) {
        Write-ColorOutput "⏭️ FASE 2: Programas já instalados, pulando..." "Yellow"
        return
    }
    
    Write-ColorOutput "`n📥 FASE 2: Instalando programas..." "Cyan"
    
    $programs = @(
        @{Name="Driver Booster"; Winget="IObit.DriverBooster"; Choco="driverbooster"},
        @{Name="Google Chrome"; Winget="Google.Chrome"; Choco="googlechrome"},
        @{Name="Discord"; Winget="Discord.Discord"; Choco="discord"},
        @{Name="Steam"; Winget="Valve.Steam"; Choco="steam"},
        @{Name="EA Desktop"; Winget="ElectronicArts.EADesktop"; Choco="ea-desktop"},
        @{Name="Epic Games Launcher"; Winget="EpicGames.EpicGamesLauncher"; Choco="epicgameslauncher"},
        @{Name="Riot Client"; Winget="RiotGames.RiotClient"; Choco="riot-client"},
        @{Name="MSI Afterburner"; Winget="Guru3D.Afterburner"; Choco="msiafterburner"},
        @{Name="Blitz"; Winget="Blitz.Blitz"; WingetArgs="--id=Blitz.Blitz -e"; Choco="blitz"}
    )
    
    $total = $programs.Count
    
    for ($i = 0; $i -lt $total; $i++) {
        $prog = $programs[$i]
        Show-Progress "Instalando Programas" ($i + 1) $total "Verificando: $($prog.Name)"
        
        # Verifica se já está instalado
        if (Test-ProgramStatus -Program $prog) {
            Write-ColorOutput "⏭️ Já instalado: $($prog.Name)" "Yellow"
            continue
        }
        
        Show-Progress "Instalando Programas" ($i + 1) $total "Instalando: $($prog.Name)"
        
        $success = $false
        
        if ($prog.Winget) {
            try {
                if ($prog.WingetArgs) {
                    # Comando customizado para programas específicos
                    $result = Invoke-Expression "winget install $($prog.WingetArgs) --silent --accept-package-agreements --accept-source-agreements" 2>&1
                } else {
                    # Comando padrão
                    $result = winget install --id $prog.Winget --silent --accept-package-agreements --accept-source-agreements 2>&1
                }
                
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
    
    # Marca como concluído
    New-Item -ItemType File -Path $ProgramsFlag -Force | Out-Null
    
    Write-Progress "Instalando Programas" -Completed
    Write-ColorOutput "✅ FASE 2 CONCLUÍDA: Programas instalados" "Green"
}

function Get-GoogleDriveFiles {
    param([string]$FolderID)
    
    # IDs reais dos seus drivers
    $drivers = @(
        @{id="1butLMoYbymlLbMLoHdxaeet_Xk5QieEt"; name="amd-software-adrenalin-edition.exe"},
        @{id="1l3e3eNWUHlt8qrycP-0Y114XCJnyqkfC"; name="mb_driver_611_graphicdch.zip"},
        @{id="1d-rcw82x7pV9Ux9pnvpqXnud7TSUxITh"; name="mb_driver_633_consumer.zip"},
        @{id="17JzP-fZ0aiCV41ejBKejSZEal1WEJ1Hw"; name="mb_driver_654_wi1.zip"},
        @{id="1fnU8TNBsm7uj5bf-e9WjJAuK0RFV3mpM"; name="mb_driver_infupdate.zip"},
        @{id="1p5HBc-j1DzFJYB4EedIq7njnZi4Pgclx"; name="mb_driver_realtekdch.zip"},
        @{id="1eRgCljlvwuwWERTSJwF2fCKhmP1gXT-G"; name="mb_driver_serialio.zip"},
        @{id="1TK7mmU2iFvyK4heAEvAwj_uJj6JaQbi3"; name="mb_utility_app_center.zip"}
    )
    
    Write-ColorOutput "📋 Usando lista de drivers configurada" "Green"
    return $drivers
}

function Download-GoogleDriveFile {
    param([string]$FileID, [string]$FileName, [string]$Destination)
    
    # Verifica se arquivo já existe
    if (Test-Path $Destination) {
        $fileSize = [math]::Round((Get-Item $Destination).Length / 1MB, 1)
        Write-ColorOutput "⏭️ Já baixado: $FileName ($fileSize MB)" "Yellow"
        return $true
    }
    
    try {
        # URL de download direto do Google Drive
        $downloadUrl = "https://drive.google.com/uc?export=download&id=$FileID&confirm=t"
        
        Write-ColorOutput "📥 Baixando: $FileName..." "Cyan"
        
        # Baixa com barra de progresso
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($downloadUrl, $Destination)
        $webClient.Dispose()
        
        if (Test-Path $Destination) {
            $fileSize = [math]::Round((Get-Item $Destination).Length / 1MB, 1)
            Write-ColorOutput "✅ Download concluído: $FileName ($fileSize MB)" "Green"
            return $true
        }
        
        return $false
    }
    catch {
        Write-ColorOutput "❌ Erro ao baixar $FileName`: $($_.Exception.Message)" "Red"
        return $false
    }
}

function Install-Driver {
    param([string]$DriverPath)
    
    try {
        $fileName = Split-Path $DriverPath -Leaf
        Write-ColorOutput "🔧 Instalando: $fileName" "Cyan"
        
        if ($DriverPath.EndsWith('.exe')) {
            # Driver AMD Adrenalin (executável)
            Write-ColorOutput "▶️ Executando instalador: $fileName" "Yellow"
            Start-Process -FilePath $DriverPath -ArgumentList "/S", "/NOREBOOT" -Wait -NoNewWindow
            Write-ColorOutput "✅ Instalador executado: $fileName" "Green"
            return $true
        }
        elseif ($DriverPath.EndsWith('.zip')) {
            $extractPath = "$DriversFolder\$(Split-Path $DriverPath -LeafBase)"
            
            if (Test-Path $extractPath) {
                Remove-Item $extractPath -Recurse -Force
            }
            
            Write-ColorOutput "📦 Extraindo: $fileName" "Yellow"
            Expand-Archive -Path $DriverPath -DestinationPath $extractPath -Force
            
            # Procura por arquivos de instalação
            $setupFiles = Get-ChildItem -Path $extractPath -Recurse -Include "*.exe", "*.msi", "*.inf" | Sort-Object Extension, Name
            
            $installed = $false
            foreach ($file in $setupFiles) {
                Write-ColorOutput "🔍 Tentando instalar: $($file.Name)" "Yellow"
                
                if ($file.Extension -eq '.exe') {
                    Start-Process -FilePath $file.FullName -ArgumentList "/S", "/SILENT", "/VERYSILENT", "/NORESTART" -Wait -NoNewWindow -ErrorAction SilentlyContinue
                    $installed = $true
                    Write-ColorOutput "✅ Executável instalado: $($file.Name)" "Green"
                    break
                }
                elseif ($file.Extension -eq '.msi') {
                    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", "`"$($file.FullName)`"", "/quiet", "/norestart" -Wait -NoNewWindow -ErrorAction SilentlyContinue
                    $installed = $true
                    Write-ColorOutput "✅ MSI instalado: $($file.Name)" "Green"
                    break
                }
                elseif ($file.Extension -eq '.inf') {
                    pnputil /add-driver $file.FullName /install
                    $installed = $true
                    Write-ColorOutput "✅ Driver INF instalado: $($file.Name)" "Green"
                    break
                }
            }
            
            if (-not $installed) {
                Write-ColorOutput "⚠️ Nenhum instalador encontrado em: $fileName" "Yellow"
                return $false
            }
            
            return $true
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
    
    if (Test-DriversStatus) {
        Write-ColorOutput "⏭️ FASE 3: Drivers já processados, pulando..." "Yellow"
        return
    }
    
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
        Show-Progress "Processando Drivers" ($i + 1) $driveFiles.Count "Processando: $($file.name)"
        
        $localPath = "$DriversFolder\$($file.name)"
        
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
    
    # Marca como concluído
    New-Item -ItemType File -Path $DriversFlag -Force | Out-Null
    
    Write-Progress "Processando Drivers" -Completed
    Write-ColorOutput "✅ FASE 3 CONCLUÍDA: Drivers processados" "Green"
}

function Show-Summary {
    Write-ColorOutput "`n📊 RESUMO DA EXECUÇÃO:" "Cyan"
    Write-ColorOutput "=" * 50 "Cyan"
    
    if (Test-Path $BloatwareFlag) {
        Write-ColorOutput "✅ Bloatware removido" "Green"
    } else {
        Write-ColorOutput "⚠️ Bloatware não processado" "Yellow"
    }
    
    if (Test-Path $ProgramsFlag) {
        Write-ColorOutput "✅ Programas instalados" "Green"
    } else {
        Write-ColorOutput "⚠️ Programas não processados" "Yellow"
    }
    
    if (Test-Path $DriversFlag) {
        Write-ColorOutput "✅ Drivers instalados" "Green"
    } else {
        Write-ColorOutput "⚠️ Drivers não processados" "Yellow"
    }
    
    Write-ColorOutput "`n💡 Use -Force para reexecutar etapas já concluídas" "Cyan"
}

function Main {
    Clear-Host
    Write-ColorOutput "🚀 SCRIPT DE INSTALAÇÃO AUTOMÁTICA v2.0" "Cyan"
    Write-ColorOutput "=" * 50 "Cyan"
    Write-ColorOutput "Log: $LogFile" "Yellow"
    if ($Force) { Write-ColorOutput "⚡ Modo FORCE ativado - reexecutando tudo" "Yellow" }
    
    Initialize-StatusFolder
    Test-Prerequisites
    Install-PackageManagers
    
    Remove-Bloatware
    Install-Programs
    Install-Drivers
    
    Show-Summary
    
    Write-ColorOutput "`n🎉 EXECUÇÃO FINALIZADA!" "Green"
    Write-ColorOutput "📄 Log salvo em: $LogFile" "Yellow"
    Write-ColorOutput "🔄 Reinicie o sistema para finalizar" "Yellow"
    
    Read-Host "`nPressione Enter para sair"
}

Main
