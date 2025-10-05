# ----- CONFIG -----
$Router = "http://192.168.0.1"
$LoginPath = "/goform/goform_set_cmd_process"

# ----- PASSWORD -----
# Use a secure string from file or prompt
$pwdFile = "$env:USERPROFILE\.router_pwd.txt"
if (Test-Path $pwdFile) {
    $enc = Get-Content $pwdFile -ErrorAction Stop
    $securePwd = $enc | ConvertTo-SecureString
    $plainPwd = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePwd)
    )
} else {
    $plainPwd = Read-Host "Enter router admin password" -AsSecureString
    $plainPwd = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($plainPwd)
    )
}

# ----- SESSION -----
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

# ----- STEP 1: GET INDEX.HTML to set cookie -----
$indexUrl = "$Router/index.html"
$dis = Invoke-WebRequest -Uri $indexUrl -WebSession $session -UseBasicParsing | Out-Null
Write-Host "Fetched index.html and obtained session cookie."
Write-Host $dis.content

# ----- STEP 2: GET LD NONCE -----
$timestamp = [int][double]::Parse((Get-Date -UFormat %s) + "000")
$ldUrl = "$Router/goform/goform_get_cmd_process?isTest=false&cmd=LD&_=$timestamp"

$headers = @{
    "Referer" = "$Router/"
    "X-Requested-With" = "XMLHttpRequest"
}

$ldResp = Invoke-WebRequest -Uri $ldUrl -WebSession $session -Headers $headers -UseBasicParsing
$respText = $ldResp.Content.Trim()

# Extract LD nonce from JSON or text
if ($respText -match '"LD"\s*:\s*"([0-9A-Fa-f]+)"') {
    $nonce = $matches[1].ToUpper()
} elseif ($respText -match 'LD\s*"([0-9A-Fa-f]+)"') {
    $nonce = $matches[1].ToUpper()
} else {
    Write-Error "Could not find nonce in LD response. Response excerpt:`n$($respText.Substring(0,[Math]::Min(400,$respText.Length)))"
    exit 1
}
Write-Host "Obtained LD nonce: $nonce"

# ----- STEP 3: HASH PASSWORD -----
function Get-SHA256Hex([string]$s) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($s)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $hash = $sha.ComputeHash($bytes)
    return ([BitConverter]::ToString($hash) -replace "-","").ToUpper()
}

$step1 = Get-SHA256Hex $plainPwd
$finalHash = Get-SHA256Hex ($step1 + $nonce)
Write-Host "Computed final password hash."

# ----- STEP 4: POST LOGIN -----
$loginBody = @{
    "isTest" = "false"
    "goformId" = "LOGIN"
    "password" = $finalHash
}

$loginResp = Invoke-WebRequest -Uri "$Router$LoginPath" -Method POST -Body $loginBody -WebSession $session -Headers $headers -UseBasicParsing
Write-Host "Login response raw: $($loginResp.Content)"
try {
    $obj = $loginResp.Content | ConvertFrom-Json
    Write-Host ("Parsed login result: " + ($obj.result -as [string]))
} catch {
    Write-Host "Login response not JSON."
}
