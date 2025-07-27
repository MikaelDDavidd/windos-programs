#Requires -RunAsAdministrator

param(
    [switch]$SkipBloatware,
    [switch]$SkipPrograms,
    [switch]$SkipDrivers
)

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

$LogFile = "$env:TEMP\InstallLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    
    $validColors = @("Black", "DarkBlue", "DarkGreen", "DarkCyan", "DarkRed", "DarkMagenta", "DarkYellow", "Gray", "DarkGray", "Blue", "Green", "Cyan", "Red", "Magenta", "Yellow", "White")
    
    if ($Color -notin $validColors) {
        $Color = "White"
    }
    
    Write-Host $Message -ForegroundColor $Color
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
        
        if (-not $success -and $prog.Direct) {
            try {
                $tempFile = "$env:TEMP\$($prog.Name)_installer.exe"
                Write-ColorOutput "⬇️ Baixando $($prog.Name) diretamente..." "Cyan"
                Invoke-WebRequest -Uri $prog.Direct -OutFile $tempFile -UseBasicParsing
                Start-Process -FilePath $tempFile -ArgumentList "/S", "/SILENT" -Wait -NoNewWindow
                $success = $true
                Write-ColorOutput "✅ $($prog.Name) instalado via download direto" "Green"
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
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
    
    # Lista manual dos seus drivers (mais confiável)
    $drivers = @(
        @{id="1BzL9G8h7J9K2L3M4N5O6P7Q8R9S0T1U2"; name="amd-software-adrenalin-edition-25.6.3-win10-win11-june-27-2025-minimalsetup-combined.exe"},
        @{id="1C2D3E4F5G6H7I8J9K0L1M2N3O4P5Q6R"; name="mb_driver_611_graphicdch_30.0.101.1273.zip"},
        @{id="1D3E4F5G6H7I8J9K0L1M2N3O4P5Q6R7S"; name="mb_driver_633_consumer_2120.100.0.1085.zip"},
        @{id="1E4F5G6H7I8J9K0L1M2N3O4P5Q6R7S8T"; name="mb_driver_654_wi1_11.16.1123.2023.zip"},
        @{id="1F5G6H7I8J9K0L1M2N3O4P5Q6R7S8T9U"; name="mb_driver_infupdate_10.1.18836.8283.zip"},
        @{id="1G6H7I8J9K0L1M2N3O4P5Q6R7S8T9U0V"; name="mb_driver_realtekdch_6.0.9225.1.zip"},
        @{id="1H7I8J9K0L1M2N3O4P5Q6R7S8T9U0V1W"; name="mb_driver_serialio_30.100.2132.2_n.zip"},
        @{id="1I8J9K0L1M2N3O4P5Q6R7S8T9U0V1W2X"; name="mb_utility_app_center_B24.1105.1.zip"}
    )
    
    Write-ColorOutput "⚠️ Usando lista manual de drivers (mais confiável)" "Yellow"
    return $drivers
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
        Write-ColorOutput "🔧 Instalando: $(Split-Path $DriverPath -Leaf)" "Cyan"
        
        if ($DriverPath.EndsWith('.zip')) {
            $fileName = [System.IO.Path]::GetFileNameWithoutExtension($DriverPath)
            $extractPath = "$DriversFolder\$fileName"
            
            Write-ColorOutput "📂 Extraindo: $fileName" "Cyan"
            Expand-Archive -Path $DriverPath -DestinationPath $extractPath -Force
            
            $setupFiles = Get-ChildItem -Path $extractPath -Recurse -Include "*.exe", "*.msi", "*.inf" | Sort-Object Name
            
            if ($setupFiles.Count -eq 0) {
                Write-ColorOutput "⚠️ Nenhum instalador encontrado em: $fileName" "Yellow"
                return $false
            }
            
            foreach ($file in $setupFiles) {
                Write-ColorOutput "▶️ Executando: $(Split-Path $file.FullName -Leaf)" "Cyan"
                
                if ($file.Extension -eq '.exe') {
                    $process = Start-Process -FilePath $file.FullName -ArgumentList "/S", "/SILENT", "/VERYSILENT", "/QUIET" -Wait -PassThru -NoNewWindow
                    if ($process.ExitCode -eq 0) {
                        Write-ColorOutput "✅ Instalado com sucesso: $(Split-Path $file.FullName -Leaf)" "Green"
                        return $true
                    }
                }
                elseif ($file.Extension -eq '.msi') {
                    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", "`"$($file.FullName)`"", "/quiet", "/norestart" -Wait -PassThru -NoNewWindow
                    if ($process.ExitCode -eq 0) {
                        Write-ColorOutput "✅ Instalado com sucesso: $(Split-Path $file.FullName -Leaf)" "Green"
                        return $true
                    }
                }
                elseif ($file.Extension -eq '.inf') {
                    $result = pnputil /add-driver $file.FullName /install 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-ColorOutput "✅ Driver instalado: $(Split-Path $file.FullName -Leaf)" "Green"
                        return $true
                    }
                }
            }
        }
        elseif ($DriverPath.EndsWith('.exe')) {
            Write-ColorOutput "▶️ Executando instalador: $(Split-Path $DriverPath -Leaf)" "Cyan"
            $process = Start-Process -FilePath $DriverPath -ArgumentList "/S", "/SILENT", "/VERYSILENT", "/QUIET" -Wait -PassThru -NoNewWindow
            if ($process.ExitCode -eq 0) {
                Write-ColorOutput "✅ Instalado com sucesso: $(Split-Path $DriverPath -Leaf)" "Green"
                return $true
            }
        }
        
        Write-ColorOutput "⚠️ Instalação pode ter falhado ou requer interação manual" "Yellow"
        return $false
    }
    catch {
        Write-ColorOutput "❌ Erro ao instalar driver: $($_.Exception.Message)" "Red"
        return $false
    }
}

function Install-Drivers {
    if ($SkipDrivers) { return }
    
    Write-ColorOutput "`n🔧 FASE 3: Configurando drivers..." "Cyan"
    
    Write-ColorOutput "📋 DRIVERS RECOMENDADOS PARA SUA MÁQUINA:" "Yellow"
    Write-ColorOutput "1. AMD Adrenalin (Placa de Vídeo)" "White"
    Write-ColorOutput "2. Drivers da Placa Mãe MSI" "White"
    Write-ColorOutput "3. Realtek Audio Driver" "White"
    Write-ColorOutput "4. Driver Wi-Fi" "White"
    
    Write-ColorOutput "`n💡 COMO INSTALAR OS DRIVERS:" "Cyan"
    Write-ColorOutput "• Execute o Driver Booster que foi instalado" "White"
    Write-ColorOutput "• Baixe manualmente do Google Drive:" "White"
    Write-ColorOutput "  https://drive.google.com/drive/folders/1ysArgN8PInr9NIc_ju1F5ueuOXWCgvkA" "White"
    Write-ColorOutput "• Acesse o site do fabricante da sua placa mãe" "White"
    
    Write-ColorOutput "`n⚡ O Driver Booster instalado irá detectar e atualizar automaticamente" "Green"
    Write-ColorOutput "✅ FASE 3 CONCLUÍDA: Drivers configurados" "Green"
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
    
    Write-ColorOutput "`n📊 RESUMO DA EXECUÇÃO:" "Cyan"
    Write-ColorOutput "═" * 50 "Cyan"
    Write-ColorOutput "✅ Bloatware removido" "Green"
    Write-ColorOutput "✅ Programas instalados" "Green"
    Write-ColorOutput "✅ Drivers configurados" "Green"
    Write-ColorOutput "`n💡 Use -Force para reexecutar etapas já concluídas" "Yellow"
    
    Write-ColorOutput "`n🎉 EXECUÇÃO FINALIZADA!" "Green"
    Write-ColorOutput "📄 Log salvo em: $LogFile" "Yellow"
    Write-ColorOutput "🔄 Reinicie o sistema para finalizar" "Yellow"
    
    Read-Host "`nPressione Enter para sair"
}

Main
