param(
    [ValidateRange(1, 65535)]
    [int]$Port = 8501,
    [string]$Address = ""
)

$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$venvPython = Join-Path $projectRoot ".venv\Scripts\python.exe"
$requirements = Join-Path $projectRoot "requirements.txt"
$app = Join-Path $projectRoot "app.py"

Write-Host ""
Write-Host "Pipeline Bucal - iniciador para celular" -ForegroundColor Cyan
Write-Host "Este terminal deve permanecer aberto durante toda a demonstracao."
Write-Host ""

if (-not (Test-Path -LiteralPath $venvPython)) {
    Write-Host "Preparando o ambiente do prototipo pela primeira vez..." -ForegroundColor Yellow
    $systemPython = Get-Command python -ErrorAction SilentlyContinue
    if ($null -eq $systemPython) {
        throw "Python nao foi encontrado. Siga primeiro o GUIA_DE_INSTALACAO.md."
    }
    & $systemPython.Source -m venv (Join-Path $projectRoot ".venv")
    if ($LASTEXITCODE -ne 0) {
        throw "Nao foi possivel criar o ambiente Python."
    }
}

$previousErrorActionPreference = $ErrorActionPreference
try {
    $ErrorActionPreference = "Continue"
    & $venvPython -c "import streamlit, PIL, qrcode" 2>$null
    $dependenciesReady = $LASTEXITCODE -eq 0
} finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
if (-not $dependenciesReady) {
    Write-Host "Instalando ou atualizando os componentes necessarios..." -ForegroundColor Yellow
    & $venvPython -m pip install -r $requirements
    if ($LASTEXITCODE -ne 0) {
        throw "A instalacao dos componentes falhou. Verifique a conexao com a internet."
    }
}

$networkCandidates = @(
    Get-NetIPConfiguration -ErrorAction SilentlyContinue |
        Where-Object { $_.NetAdapter.Status -eq "Up" } |
        ForEach-Object {
            $configuration = $_
            $_.IPv4Address |
                Where-Object {
                    $_.IPAddress -and
                    $_.IPAddress -ne "127.0.0.1" -and
                    -not $_.IPAddress.StartsWith("169.254.")
                } |
                ForEach-Object {
                    [PSCustomObject]@{
                        Interface = $configuration.InterfaceAlias
                        IP = $_.IPAddress
                    }
                }
        } |
        Sort-Object IP -Unique
)

if ($Address) {
    $selectedAddress = $Address.Trim()
} elseif ($networkCandidates.Count -eq 0) {
    throw "Nenhuma rede ativa foi encontrada. Conecte o computador ao Wi-Fi ou ative o Hotspot movel."
} elseif ($networkCandidates.Count -eq 1) {
    $selectedAddress = $networkCandidates[0].IP
    Write-Host ("Rede encontrada: {0} - {1}" -f $networkCandidates[0].Interface, $selectedAddress)
} else {
    Write-Host "Escolha a rede que tambem sera usada pelo iPhone:" -ForegroundColor Yellow
    for ($index = 0; $index -lt $networkCandidates.Count; $index++) {
        Write-Host ("  [{0}] {1} - {2}" -f ($index + 1), $networkCandidates[$index].Interface, $networkCandidates[$index].IP)
    }
    $choice = 0
    do {
        $answer = Read-Host "Digite o numero da rede"
        $validChoice = [int]::TryParse($answer, [ref]$choice) -and
            $choice -ge 1 -and $choice -le $networkCandidates.Count
    } until ($validChoice)
    $selectedAddress = $networkCandidates[$choice - 1].IP
}

if ($selectedAddress -notmatch "^[A-Za-z0-9.:-]+$") {
    throw "O endereco de rede selecionado e invalido."
}

$existingListener = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if ($existingListener) {
    throw "A porta $Port ja esta sendo usada. Feche a execucao anterior do prototipo e tente novamente."
}

$mobileUrl = "http://${selectedAddress}:$Port"
$env:PIPELINE_MOBILE_URL = $mobileUrl

Write-Host ""
Write-Host "Iniciando o servidor local..." -ForegroundColor Yellow
Set-Location -LiteralPath $projectRoot
$streamlitArguments = @(
    "-m", "streamlit", "run", ('"{0}"' -f $app),
    "--server.address", "0.0.0.0",
    "--server.port", $Port,
    "--server.headless", "true",
    "--browser.gatherUsageStats", "false"
)
$serverProcess = $null
try {
    $serverProcess = Start-Process `
        -FilePath $venvPython `
        -ArgumentList $streamlitArguments `
        -PassThru `
        -NoNewWindow

    $healthUrl = "http://127.0.0.1:$Port/_stcore/health"
    $deadline = (Get-Date).AddSeconds(45)
    $serverReady = $false
    do {
        if ($serverProcess.HasExited) {
            break
        }
        Start-Sleep -Milliseconds 250
        try {
            $health = Invoke-WebRequest -UseBasicParsing -Uri $healthUrl -TimeoutSec 2
            $serverReady = $health.StatusCode -eq 200
        } catch {
            $serverReady = $false
        }
    } until ($serverReady -or (Get-Date) -ge $deadline)

    if (-not $serverReady) {
        throw "O servidor nao respondeu em ate 45 segundos. Consulte a mensagem exibida acima."
    }

    Write-Host ""
    Write-Host "Pronto para a demonstracao." -ForegroundColor Green
    Write-Host "No iPhone, abra este endereco:" -ForegroundColor Cyan
    Write-Host $mobileUrl -ForegroundColor White
    Write-Host "O mesmo endereco e um QR na barra lateral do aplicativo."
    Write-Host "Se o Firewall do Windows perguntar, permita o Python na rede usada na reuniao."
    Write-Host "Para encerrar, volte a este terminal e pressione ENTER."
    Write-Host ""

    Start-Process $mobileUrl
    $null = Read-Host "Pressione ENTER para encerrar o Pipeline Bucal"
    Write-Host "Servidor encerrado."
} finally {
    if ($null -ne $serverProcess -and -not $serverProcess.HasExited) {
        Stop-Process -Id $serverProcess.Id -ErrorAction SilentlyContinue
    }
}
