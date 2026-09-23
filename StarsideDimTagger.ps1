[CmdletBinding()]
param(
    [switch]$Apply,
    [switch]$ResetCredentials,
    [switch]$SelfTest,
    [switch]$ShowReadme,
    [switch]$EnsureDimOpen,
    [switch]$TutorialOnly
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$DataDir = Join-Path $Root "data"
$StateDir = Join-Path $Root "state"
$LogDir = Join-Path $Root "logs"
$CredentialsPath = Join-Path $StateDir "credentials.json"
$TokenPath = Join-Path $StateDir "oauth-token.json"
$ShoppingPath = Join-Path $DataDir "starside-shopping.json"
$ItemsPath = Join-Path $DataDir "manifest-items.json"
$PlugsPath = Join-Path $DataDir "weapon-plug-names.json"
$UpdaterPath = Join-Path $Root "StarsideUpdater.ps1"
$WeaponBuckets = @(1498876634, 2465295065, 953998645)

function Write-Section([string]$Text) {
    Write-Host ""
    Write-Host "=== $Text ===" -ForegroundColor Cyan
}

function Show-ReadmeDialog {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing

        $form = New-Object Windows.Forms.Form
        $form.Text = "Starside DIM 自动标签 - 配置说明与密钥获取教程"
        $form.StartPosition = "CenterScreen"
        $form.Size = New-Object Drawing.Size(900, 760)
        $form.MinimumSize = New-Object Drawing.Size(700, 560)
        $form.BackColor = [Drawing.Color]::White

        $title = New-Object Windows.Forms.Label
        $title.Text = "Starside DIM 自动标签工具"
        $title.Dock = "Top"
        $title.Height = 58
        $title.Padding = New-Object Windows.Forms.Padding(18, 14, 0, 0)
        $title.Font = New-Object Drawing.Font("Microsoft YaHei UI", 18, [Drawing.FontStyle]::Bold)
        $title.ForeColor = [Drawing.Color]::FromArgb(35, 55, 85)

        $textBox = New-Object Windows.Forms.RichTextBox
        $textBox.Dock = "Fill"
        $textBox.ReadOnly = $true
        $textBox.DetectUrls = $true
        $textBox.BorderStyle = "None"
        $textBox.ZoomFactor = 1.08
        $textBox.BackColor = [Drawing.Color]::White
        $textBox.Font = New-Object Drawing.Font("Microsoft YaHei UI", 10)
        $textBox.Text = @'
【运行流程】

关闭本教程后，程序会依次：
1. 读取并校验 Starside 最新的白弹、绿弹、威能和其他购物清单；
2. 检测 DIM 是否已经打开，未检测到时自动打开 DIM；
3. 首次运行询问开发者信息并打开 Bungie 授权；
4. 读取你的武器并写入 DIM 标签。

标签规则：4/4 = 归档，3/4 = 青睐，2/4 = 保留，其余 = 垃圾。
异域与锻造武器不加标签。程序不会移动、拆解、锁定或解锁物品。

────────────────────────────────────────
【第一步：注册 Bungie 开发者应用】

1. 登录 Bungie 后打开官方开发者页面：
https://www.bungie.net/en/Application

2. 点击“Create New App”，建议这样填写：
   • Application Name：任意不重复名称，例如 YourName-StarsideTagger
   • OAuth Client Type：Confidential
   • Redirect URL：必须准确填写
     http://127.0.0.1:8765/callback
   • Origin Header：填写
     http://localhost:3000
   • 选择读取 Destiny 账号和物品所需权限，接受条款后创建。

3. 创建成功后，从应用详情页复制：
   • API Key → “Bungie API Key”
   • OAuth Client ID → “Bungie OAuth Client ID”
   • OAuth Client Secret → “Bungie OAuth Client Secret”

Client Secret 不要发送给其他人，也不要上传到网盘或公开仓库。

────────────────────────────────────────
【第二步：申请 DIM API Key】

DIM 官方说明：
https://github.com/DestinyItemManager/dim-api#get-an-api-key

DIM 注册需要三项内容：
   • id：你自己取的唯一名称，建议格式 username-dev
   • bungieApiKey：第一步得到的 Bungie API Key
   • origin：http://localhost:3000

按照 DIM 官方说明向下面的接口提交注册信息：
https://api.destinyitemmanager.com/new_app

最直接的方法是在 Windows PowerShell 中运行下面的命令。
先把 YOUR_NAME-dev 和 YOUR_BUNGIE_API_KEY 替换成你自己的内容：

$body = @{
  id = "YOUR_NAME-dev"
  bungieApiKey = "YOUR_BUNGIE_API_KEY"
  origin = "http://localhost:3000"
} | ConvertTo-Json

Invoke-RestMethod -Method Post `
  -Uri "https://api.destinyitemmanager.com/new_app" `
  -ContentType "application/json" `
  -Body $body

返回结果里的 dimApiKey 就是脚本需要的“DIM API Key”。
脚本询问“DIM 注册时填写的 Origin”时，请输入同一个：
http://localhost:3000

────────────────────────────────────────
【第三步：首次运行时填写】

关闭本窗口后，按顺序粘贴：
1. Bungie API Key
2. Bungie OAuth Client ID
3. Bungie OAuth Client Secret
4. Redirect URI（直接按回车使用默认值）
5. DIM API Key
6. DIM Origin（直接按回车使用默认值）

随后浏览器会打开 Bungie。登录并点击授权即可。
密钥和登录令牌会使用 Windows DPAPI 加密，只能由当前电脑的当前 Windows 用户读取。

【换电脑】
复制并解压完整工具包，在新电脑上重新输入上述开发者信息并登录 Bungie。
不要复制旧电脑生成的 state 文件夹。
'@
        $textBox.Add_LinkClicked({
            param($sender, $eventArgs)
            Start-Process $eventArgs.LinkText
        })

        $buttonPanel = New-Object Windows.Forms.FlowLayoutPanel
        $buttonPanel.Dock = "Bottom"
        $buttonPanel.Height = 58
        $buttonPanel.FlowDirection = "RightToLeft"
        $buttonPanel.Padding = New-Object Windows.Forms.Padding(10, 8, 12, 6)

        $button = New-Object Windows.Forms.Button
        $button.Text = "我已了解，开始运行"
        $button.Size = New-Object Drawing.Size(220, 38)
        $button.Font = New-Object Drawing.Font("Microsoft YaHei UI", 10, [Drawing.FontStyle]::Bold)
        $button.Add_Click({ $form.Close() })

        $dimButton = New-Object Windows.Forms.Button
        $dimButton.Text = "打开 DIM 官方教程"
        $dimButton.Size = New-Object Drawing.Size(205, 38)
        $dimButton.Add_Click({ Start-Process "https://github.com/DestinyItemManager/dim-api#get-an-api-key" })

        $bungieButton = New-Object Windows.Forms.Button
        $bungieButton.Text = "打开 Bungie 开发者页面"
        $bungieButton.Size = New-Object Drawing.Size(230, 38)
        $bungieButton.Add_Click({ Start-Process "https://www.bungie.net/en/Application" })

        $buttonPanel.Controls.Add($button)
        $buttonPanel.Controls.Add($dimButton)
        $buttonPanel.Controls.Add($bungieButton)

        $form.Controls.Add($textBox)
        $form.Controls.Add($title)
        $form.Controls.Add($buttonPanel)
        [void]$form.ShowDialog()
        $form.Dispose()
    } catch {
        Write-Host "无法显示图形教程：$($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "Bungie 开发者页面：https://www.bungie.net/en/Application"
        Write-Host "DIM API Key 教程：https://github.com/DestinyItemManager/dim-api#get-an-api-key"
    }
}

function Test-DimWindow {
    $titleMatch = Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.MainWindowTitle -match "Destiny Item Manager|\bDIM\b"
    } | Select-Object -First 1
    if ($titleMatch) { return $true }
    try {
        $commandMatch = Get-CimInstance Win32_Process -ErrorAction Stop | Where-Object {
            $_.Name -match "^(chrome|msedge|firefox|brave|opera|vivaldi).*\.exe$" -and
            $_.CommandLine -match "app\.destinyitemmanager\.com"
        } | Select-Object -First 1
        return [bool]$commandMatch
    } catch {
        return $false
    }
}

function Confirm-DimWindow {
    Write-Section "检测 DIM"
    if (Test-DimWindow) {
        Write-Host "已检测到 DIM 窗口。" -ForegroundColor Green
        return
    }
    Write-Host "未检测到 DIM，正在打开网页……" -ForegroundColor Yellow
    Start-Process "https://app.destinyitemmanager.com/"
    $deadline = [DateTime]::UtcNow.AddSeconds(20)
    while ([DateTime]::UtcNow -lt $deadline) {
        Start-Sleep -Milliseconds 500
        if (Test-DimWindow) {
            Write-Host "DIM 已打开。" -ForegroundColor Green
            return
        }
    }
    Write-Host "无法从窗口标题确认 DIM；将继续通过 DIM API 验证连接。" -ForegroundColor Yellow
}

function Get-PropertyValue($Object, [string]$Name) {
    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Protect-SecureValue([Security.SecureString]$Value) {
    return ConvertFrom-SecureString -SecureString $Value
}

function Unprotect-Value([string]$Value) {
    $secure = ConvertTo-SecureString -String $Value
    return (New-Object Management.Automation.PSCredential("unused", $secure)).GetNetworkCredential().Password
}

function Read-Required([string]$Prompt, [string]$Default = "") {
    while ($true) {
        $suffix = if ($Default) { " [$Default]" } else { "" }
        $value = Read-Host "$Prompt$suffix"
        if (-not $value -and $Default) { return $Default }
        if ($value) { return $value.Trim() }
        Write-Host "此项不能为空。" -ForegroundColor Yellow
    }
}

function Read-Protected([string]$Prompt) {
    $value = Read-Host $Prompt -AsSecureString
    return Protect-SecureValue $value
}

function Initialize-Credentials {
    New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
    Write-Section "首次配置"
    Write-Host "请输入你在 Bungie 与 DIM 开发者页面获得的信息。"
    Write-Host "秘密值会用 Windows DPAPI 加密，只能由当前电脑上的当前用户解密。"
    $credentials = [ordered]@{
        version = 1
        bungieApiKey = Read-Protected "Bungie API Key（输入时隐藏）"
        bungieClientId = Read-Protected "Bungie OAuth Client ID（输入时隐藏）"
        bungieClientSecret = Read-Protected "Bungie OAuth Client Secret（输入时隐藏）"
        redirectUri = Read-Required "Bungie Redirect URI" "http://127.0.0.1:8765/callback"
        dimApiKey = Read-Protected "DIM API Key（输入时隐藏）"
        dimOrigin = Read-Required "DIM 注册时填写的 Origin" "http://localhost:3000"
    }
    $credentials | ConvertTo-Json | Set-Content -LiteralPath $CredentialsPath -Encoding UTF8
    Write-Host "配置已加密保存：$CredentialsPath" -ForegroundColor Green
    return [pscustomobject]$credentials
}

function Load-Credentials {
    if (-not (Test-Path -LiteralPath $CredentialsPath)) {
        return Initialize-Credentials
    }
    return Get-Content -LiteralPath $CredentialsPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Decode-Credentials($Stored) {
    return [pscustomobject]@{
        bungieApiKey = Unprotect-Value $Stored.bungieApiKey
        bungieClientId = Unprotect-Value $Stored.bungieClientId
        bungieClientSecret = Unprotect-Value $Stored.bungieClientSecret
        redirectUri = [string]$Stored.redirectUri
        dimApiKey = Unprotect-Value $Stored.dimApiKey
        dimOrigin = [string]$Stored.dimOrigin
    }
}

function Get-UnixTime {
    return [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
}

function Save-OAuthToken($Token, $Previous) {
    New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
    $now = Get-UnixTime
    $refreshToken = [string](Get-PropertyValue $Token "refresh_token")
    if (-not $refreshToken -and $Previous) { $refreshToken = $Previous.refreshToken }
    $membershipId = [string](Get-PropertyValue $Token "membership_id")
    if (-not $membershipId -and $Previous) { $membershipId = $Previous.bungieMembershipId }
    $state = [ordered]@{
        accessToken = Protect-SecureValue (ConvertTo-SecureString ([string]$Token.access_token) -AsPlainText -Force)
        refreshToken = Protect-SecureValue (ConvertTo-SecureString $refreshToken -AsPlainText -Force)
        accessExpiresAt = $now + [int](Get-PropertyValue $Token "expires_in")
        refreshExpiresAt = $now + [int](Get-PropertyValue $Token "refresh_expires_in")
        bungieMembershipId = $membershipId
    }
    $state | ConvertTo-Json | Set-Content -LiteralPath $TokenPath -Encoding UTF8
    return [pscustomobject]@{
        accessToken = [string]$Token.access_token
        refreshToken = $refreshToken
        accessExpiresAt = [int64]$state.accessExpiresAt
        refreshExpiresAt = [int64]$state.refreshExpiresAt
        bungieMembershipId = $membershipId
    }
}

function Load-OAuthToken {
    if (-not (Test-Path -LiteralPath $TokenPath)) { return $null }
    try {
        $stored = Get-Content -LiteralPath $TokenPath -Raw -Encoding UTF8 | ConvertFrom-Json
        return [pscustomobject]@{
            accessToken = Unprotect-Value $stored.accessToken
            refreshToken = Unprotect-Value $stored.refreshToken
            accessExpiresAt = [int64]$stored.accessExpiresAt
            refreshExpiresAt = [int64]$stored.refreshExpiresAt
            bungieMembershipId = [string]$stored.bungieMembershipId
        }
    } catch {
        Remove-Item -LiteralPath $TokenPath -Force -ErrorAction SilentlyContinue
        return $null
    }
}

function Invoke-BungieToken($Config, [hashtable]$Body, $Previous) {
    $basicBytes = [Text.Encoding]::UTF8.GetBytes("$($Config.bungieClientId):$($Config.bungieClientSecret)")
    $headers = @{
        "X-API-Key" = $Config.bungieApiKey
        Authorization = "Basic $([Convert]::ToBase64String($basicBytes))"
    }
    try {
        $token = Invoke-RestMethod -Method Post -Uri "https://www.bungie.net/Platform/App/OAuth/token/" -Headers $headers -ContentType "application/x-www-form-urlencoded" -Body $Body
        if (-not $token.access_token) { throw "Bungie 没有返回 access_token。" }
        return Save-OAuthToken $token $Previous
    } catch {
        throw "Bungie OAuth 失败：$($_.Exception.Message)"
    }
}

function Parse-Query([string]$Query) {
    $result = @{}
    foreach ($part in $Query.TrimStart("?").Split("&")) {
        if (-not $part) { continue }
        $pair = $part.Split("=", 2)
        $key = [Uri]::UnescapeDataString($pair[0].Replace("+", " "))
        $value = if ($pair.Count -gt 1) { [Uri]::UnescapeDataString($pair[1].Replace("+", " ")) } else { "" }
        $result[$key] = $value
    }
    return $result
}

function Wait-LoopbackCode([Uri]$RedirectUri, [string]$ExpectedState, [string]$AuthorizeUri) {
    $listener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, $RedirectUri.Port)
    $listener.Start()
    try {
        Start-Process $AuthorizeUri
        $deadline = [DateTime]::UtcNow.AddMinutes(5)
        while (-not $listener.Pending()) {
            if ([DateTime]::UtcNow -ge $deadline) { throw "等待 Bungie 登录超时。" }
            Start-Sleep -Milliseconds 200
        }
        $client = $listener.AcceptTcpClient()
        try {
            $stream = $client.GetStream()
            $reader = New-Object IO.StreamReader($stream, [Text.Encoding]::ASCII, $false, 1024, $true)
            $requestLine = $reader.ReadLine()
            while ($reader.ReadLine()) { }
            $target = $requestLine.Split(" ")[1]
            $requestUri = [Uri]("http://127.0.0.1:{0}{1}" -f $RedirectUri.Port, $target)
            $query = Parse-Query $requestUri.Query
            $html = "<html><meta charset='utf-8'><body style='font-family:sans-serif'><h2>授权完成</h2><p>可以关闭此页面并返回脚本。</p></body></html>"
            $bytes = [Text.Encoding]::UTF8.GetBytes($html)
            $header = "HTTP/1.1 200 OK`r`nContent-Type: text/html; charset=utf-8`r`nContent-Length: $($bytes.Length)`r`nConnection: close`r`n`r`n"
            $headerBytes = [Text.Encoding]::ASCII.GetBytes($header)
            $stream.Write($headerBytes, 0, $headerBytes.Length)
            $stream.Write($bytes, 0, $bytes.Length)
            $stream.Flush()
            if ($query.state -ne $ExpectedState) { throw "OAuth state 不匹配，请重新运行。" }
            if ($query.error) { throw "Bungie 拒绝授权：$($query.error)" }
            if (-not $query.code) { throw "回调中没有授权码。" }
            return [string]$query.code
        } finally {
            $client.Close()
        }
    } finally {
        $listener.Stop()
    }
}

function Get-AuthorizationCode($Config) {
    $state = [Guid]::NewGuid().ToString("N")
    $authorizeUri = "https://www.bungie.net/en/OAuth/Authorize?client_id=$([Uri]::EscapeDataString($Config.bungieClientId))&response_type=code&state=$state"
    $redirect = [Uri]$Config.redirectUri
    $isLoopback = $redirect.Scheme -eq "http" -and ($redirect.Host -eq "127.0.0.1" -or $redirect.Host -eq "localhost")
    if ($isLoopback) {
        Write-Host "即将打开 Bungie 登录页面，脚本会自动接收回调。"
        return Wait-LoopbackCode $redirect $state $authorizeUri
    }
    Start-Process $authorizeUri
    Write-Host "当前 Redirect URI 不是本地地址。登录跳转后，请复制浏览器地址栏中的完整 URL。" -ForegroundColor Yellow
    $finalUrl = Read-Required "粘贴最终回调 URL"
    $query = Parse-Query ([Uri]$finalUrl).Query
    if ($query.state -ne $state) { throw "OAuth state 不匹配，请重新运行。" }
    if (-not $query.code) { throw "URL 中没有授权码。" }
    return [string]$query.code
}

function Get-BungieSession($Config) {
    $session = Load-OAuthToken
    $now = Get-UnixTime
    if ($session -and $session.accessExpiresAt -gt ($now + 60)) { return $session }
    if ($session -and $session.refreshToken -and $session.refreshExpiresAt -gt ($now + 60)) {
        try {
            return Invoke-BungieToken $Config @{ grant_type = "refresh_token"; refresh_token = $session.refreshToken } $session
        } catch {
            Remove-Item -LiteralPath $TokenPath -Force -ErrorAction SilentlyContinue
            Write-Host "旧授权无法刷新，需要重新登录。" -ForegroundColor Yellow
        }
    }
    $code = Get-AuthorizationCode $Config
    return Invoke-BungieToken $Config @{ grant_type = "authorization_code"; code = $code } $null
}

function Invoke-BungieApi($Config, $Session, [string]$Path) {
    $headers = @{
        Accept = "application/json"
        "Content-Type" = "application/json"
        "X-API-Key" = $Config.bungieApiKey
        Authorization = "Bearer $($Session.accessToken)"
    }
    $envelope = Invoke-RestMethod -Method Get -Uri "https://www.bungie.net/Platform$Path" -Headers $headers
    if ([int]$envelope.ErrorCode -ne 1) {
        throw "Bungie API：$($envelope.Message)"
    }
    return $envelope.Response
}

function Invoke-DimApi($Config, [string]$AccessToken, [string]$Method, [string]$Path, $Body = $null) {
    $headers = @{
        Accept = "application/json"
        "Content-Type" = "application/json"
        "X-API-Key" = $Config.dimApiKey
        Authorization = "Bearer $AccessToken"
        Origin = $Config.dimOrigin
    }
    $parameters = @{
        Method = $Method
        Uri = "https://api.destinyitemmanager.com$Path"
        Headers = $headers
    }
    if ($null -ne $Body) { $parameters.Body = ($Body | ConvertTo-Json -Depth 8 -Compress) }
    return Invoke-RestMethod @parameters
}

function Normalize-Name([string]$Value) {
    if (-not $Value) { return "" }
    $result = $Value.Normalize([Text.NormalizationForm]::FormKC).ToLowerInvariant()
    $result = $result -replace '\(增强\)|（增强）|增强版|增强|旧版', ''
    return $result -replace '[^\p{L}\p{Nd}]', ''
}

function Test-ColumnMatch($Owned, $Recommended) {
    $set = @{}
    foreach ($name in @($Owned)) { $set[(Normalize-Name ([string]$name))] = $true }
    foreach ($name in @($Recommended)) {
        if ($set.ContainsKey((Normalize-Name ([string]$name)))) { return $true }
    }
    return $false
}

function Get-ShoppingRating([string]$WeaponName, $OwnedColumns, $Rules) {
    $best = "0/4"
    $score = @{ "0/4" = 0; "2/4" = 1; "3/4" = 2; "4/4" = 3 }
    $weaponKey = Normalize-Name $WeaponName
    foreach ($rule in $Rules) {
        if ((Normalize-Name ([string]$rule.name)) -ne $weaponKey) { continue }
        $matched = @()
        for ($index = 0; $index -lt 4; $index++) {
            $matched += Test-ColumnMatch @($OwnedColumns[$index]) @($rule.columns[$index])
        }
        $traitsMatch = $matched[2] -and $matched[3]
        $rating = if ($matched[0] -and $matched[1] -and $matched[2] -and $matched[3]) {
            "4/4"
        } elseif ($traitsMatch -and ($matched[0] -or $matched[1])) {
            "3/4"
        } elseif ($traitsMatch) {
            "2/4"
        } else {
            "0/4"
        }
        if ($score[$rating] -gt $score[$best]) { $best = $rating }
    }
    return $best
}

function Get-DynamicEntry($Object, [string]$Name) {
    return Get-PropertyValue $Object $Name
}

function Get-InventoryItems($Profile) {
    $items = New-Object Collections.Generic.List[object]
    $profileInventory = Get-PropertyValue (Get-PropertyValue $Profile "profileInventory") "data"
    foreach ($item in @(Get-PropertyValue $profileInventory "items")) { if ($item) { $items.Add($item) } }
    foreach ($componentName in @("characterInventories", "characterEquipment")) {
        $data = Get-PropertyValue (Get-PropertyValue $Profile $componentName) "data"
        if ($data) {
            foreach ($property in $data.PSObject.Properties) {
                foreach ($item in @(Get-PropertyValue $property.Value "items")) { if ($item) { $items.Add($item) } }
            }
        }
    }
    $unique = @{}
    foreach ($item in $items) {
        $instanceId = [string](Get-PropertyValue $item "itemInstanceId")
        if ($instanceId) { $unique[$instanceId] = $item }
    }
    return @($unique.Values)
}

function Get-RollColumns($Profile, [string]$InstanceId, $PlugNames) {
    $components = Get-PropertyValue $Profile "itemComponents"
    $socketData = Get-PropertyValue (Get-PropertyValue (Get-PropertyValue $components "sockets") "data") $InstanceId
    $sockets = @(Get-PropertyValue $socketData "sockets")
    $reusableData = Get-PropertyValue (Get-PropertyValue (Get-PropertyValue $components "reusablePlugs") "data") $InstanceId
    $reusable = Get-PropertyValue $reusableData "plugs"
    $columns = @()
    foreach ($socketIndex in 1..4) {
        $names = @{}
        if ($sockets.Count -gt $socketIndex) {
            $hash = [string](Get-PropertyValue $sockets[$socketIndex] "plugHash")
            if ($hash -and $PlugNames.ContainsKey($hash)) { $names[$PlugNames[$hash]] = $true }
        }
        $alternatives = Get-DynamicEntry $reusable ([string]$socketIndex)
        foreach ($plug in @($alternatives)) {
            $hash = [string](Get-PropertyValue $plug "plugItemHash")
            if ($hash -and $PlugNames.ContainsKey($hash)) { $names[$PlugNames[$hash]] = $true }
        }
        $columns += ,@($names.Keys)
    }
    return $columns
}

try {
    if ($SelfTest) {
        foreach ($required in @($ShoppingPath, $ItemsPath, $PlugsPath)) {
            if (-not (Test-Path -LiteralPath $required)) { throw "缺少数据文件：$required" }
        }
        $shoppingTest = Get-Content -LiteralPath $ShoppingPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $rulesTest = @($shoppingTest.records)
        if ($rulesTest.Count -ne 748) { throw "购物清单记录数异常：$($rulesTest.Count)" }
        $firstRule = $rulesTest[0]
        if ((Get-ShoppingRating ([string]$firstRule.name) $firstRule.columns $rulesTest) -ne "4/4") {
            throw "4/4 分类自检失败。"
        }
        $twoColumns = New-Object object[] 4
        $twoColumns[0] = @()
        $twoColumns[1] = @()
        $twoColumns[2] = @($firstRule.columns[2])
        $twoColumns[3] = @($firstRule.columns[3])
        if ((Get-ShoppingRating ([string]$firstRule.name) $twoColumns $rulesTest) -ne "2/4") {
            throw "2/4 分类自检失败。"
        }
        $secretTest = ConvertTo-SecureString "starside-self-test" -AsPlainText -Force
        if ((Unprotect-Value (Protect-SecureValue $secretTest)) -ne "starside-self-test") {
            throw "Windows 凭据加密自检失败。"
        }
        Write-Host "自检通过：PowerShell、748 条规则、分类逻辑和 DPAPI 加密均正常。" -ForegroundColor Green
        exit 0
    }

    if ($TutorialOnly) {
        Show-ReadmeDialog
        exit 0
    }

    if ($ResetCredentials) {
        if (Test-Path -LiteralPath $StateDir) { Remove-Item -LiteralPath $StateDir -Recurse -Force }
        Write-Host "本机保存的配置和 OAuth 令牌已删除。下次运行会重新配置。" -ForegroundColor Green
        exit 0
    }

    if ($ShowReadme) {
        Write-Section "配置说明与密钥获取教程"
        Write-Host "请阅读弹出的教程，点击“我已了解，开始运行”后继续。"
        Show-ReadmeDialog
    }

    foreach ($required in @($ShoppingPath, $ItemsPath, $PlugsPath)) {
        if (-not (Test-Path -LiteralPath $required)) { throw "缺少数据文件：$required" }
    }

    Write-Section "检查 Starside 最新购物清单"
    if (Test-Path -LiteralPath $UpdaterPath) {
        try {
            $updateInfo = & $UpdaterPath -DestinationPath $ShoppingPath
            if ($updateInfo.changed) {
                Write-Host "已从 Starside 更新：$($updateInfo.records) 条。" -ForegroundColor Green
            } else {
                Write-Host "已是 Starside 最新版本：$($updateInfo.records) 条。" -ForegroundColor Green
            }
        } catch {
            Write-Host "无法确认最新版本，将使用最后一次有效清单。" -ForegroundColor Yellow
            Write-Host $_.Exception.Message -ForegroundColor Yellow
        }
    } else {
        Write-Host "缺少 StarsideUpdater.ps1，将使用随包清单。" -ForegroundColor Yellow
    }

    if ($EnsureDimOpen) { Confirm-DimWindow }

    $config = Decode-Credentials (Load-Credentials)
    Write-Section "连接 Bungie"
    $session = Get-BungieSession $config
    $user = Invoke-BungieApi $config $session "/User/GetMembershipsForCurrentUser/"
    $memberships = @(Get-PropertyValue $user "destinyMemberships")
    if (-not $memberships.Count) { throw "这个 Bungie 账号没有 Destiny 2 档案。" }
    $membership = $null
    foreach ($candidate in $memberships) {
        $crossSave = [int](Get-PropertyValue $candidate "crossSaveOverride")
        $membershipType = [int](Get-PropertyValue $candidate "membershipType")
        if ($crossSave -and $membershipType -eq $crossSave) { $membership = $candidate; break }
    }
    if (-not $membership) { $membership = $memberships[0] }
    $membershipId = [string]$membership.membershipId
    $membershipType = [int]$membership.membershipType
    Write-Host "Destiny 档案：$membershipId"

    Write-Section "读取库存与标签"
    $components = "100,102,200,201,205,300,304,305,309"
    $profile = Invoke-BungieApi $config $session "/Destiny2/$membershipType/Profile/$membershipId/?components=$components"
    $bungieMembershipId = if ($session.bungieMembershipId) { $session.bungieMembershipId } else { [string](Get-PropertyValue (Get-PropertyValue $user "bungieNetUser") "membershipId") }
    $dimToken = Invoke-RestMethod -Method Post -Uri "https://api.destinyitemmanager.com/auth/token" -Headers @{
        Accept = "application/json"
        "Content-Type" = "application/json"
        "X-API-Key" = $config.dimApiKey
        Origin = $config.dimOrigin
    } -Body (@{ bungieAccessToken = $session.accessToken; membershipId = $bungieMembershipId } | ConvertTo-Json -Compress)
    if (-not $dimToken.accessToken) { throw "DIM 没有返回访问令牌。" }
    $dimProfile = Invoke-DimApi $config $dimToken.accessToken "Get" "/profile?platformMembershipId=$membershipId&destinyVersion=2&components=tags"

    $existingById = @{}
    foreach ($annotation in @($dimProfile.tags)) { $existingById[[string]$annotation.id] = $annotation }
    $shopping = Get-Content -LiteralPath $ShoppingPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $rules = @($shopping.records)
    $manifest = Get-Content -LiteralPath $ItemsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $definitions = @{}
    foreach ($row in @($manifest.items)) { $definitions[[string]$row[0]] = $row }
    $plugObject = Get-Content -LiteralPath $PlugsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $plugNames = @{}
    foreach ($property in $plugObject.PSObject.Properties) { $plugNames[$property.Name] = [string]$property.Value }

    $tagByRating = @{ "4/4" = "archive"; "3/4" = "favorite"; "2/4" = "keep"; "0/4" = "junk" }
    $counts = @{ "4/4" = 0; "3/4" = 0; "2/4" = 0; "0/4" = 0; excluded = 0; weapons = 0; changes = 0 }
    $updates = New-Object Collections.Generic.List[object]
    $reportRows = New-Object Collections.Generic.List[object]

    foreach ($item in (Get-InventoryItems $profile)) {
        $instanceId = [string]$item.itemInstanceId
        $definition = $definitions[[string]$item.itemHash]
        if (-not $definition) { continue }
        $bucketHash = [int]$definition[6]
        if ($WeaponBuckets -notcontains $bucketHash) { continue }
        $counts.weapons++
        $name = [string]$definition[1]
        $typeName = [string]$definition[3]
        $isExotic = $typeName -match "异域|Exotic"
        $isCrafted = (([int](Get-PropertyValue $item "state")) -band 8) -ne 0
        $rating = Get-ShoppingRating $name (Get-RollColumns $profile $instanceId $plugNames) $rules
        $targetTag = if ($isExotic -or $isCrafted) { $null } else { $tagByRating[$rating] }
        $status = if ($isExotic) { "跳过异域并清除标签" } elseif ($isCrafted) { "跳过锻造并清除标签" } else { "$rating -> $targetTag" }
        if ($isExotic -or $isCrafted) { $counts.excluded++ } else { $counts[$rating]++ }
        $current = $existingById[$instanceId]
        $currentTag = if ($current) { [string](Get-PropertyValue $current "tag") } else { "" }
        $notes = if ($current) { Get-PropertyValue $current "notes" } else { $null }
        $targetText = if ($targetTag) { [string]$targetTag } else { "" }
        $needsChange = $currentTag -ne $targetText
        if ($needsChange) {
            $counts.changes++
            $updates.Add([pscustomobject]@{ id = $instanceId; tag = $targetTag; notes = $notes })
        }
        $reportRows.Add([pscustomobject]@{
            instanceId = $instanceId
            name = $name
            rating = if ($isExotic -or $isCrafted) { "excluded" } else { $rating }
            currentTag = $currentTag
            targetTag = $targetText
            needsChange = $needsChange
            result = $status
        })
    }

    New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $reportPath = Join-Path $LogDir "tag-preview-$timestamp.csv"
    $reportRows | Sort-Object name, instanceId | Export-Csv -LiteralPath $reportPath -NoTypeInformation -Encoding UTF8

    Write-Section "分类结果"
    Write-Host "武器总数：$($counts.weapons)"
    Write-Host "4/4 -> Archive：$($counts['4/4'])"
    Write-Host "3/4 -> Favorite：$($counts['3/4'])"
    Write-Host "2/4 -> Keep：$($counts['2/4'])"
    Write-Host "0/4 -> Junk：$($counts['0/4'])"
    Write-Host "异域/锻造（无标签）：$($counts.excluded)"
    Write-Host "实际需要修改：$($counts.changes)"
    Write-Host "明细报告：$reportPath"

    if (-not $Apply) {
        Write-Host ""
        Write-Host "当前是预览模式，没有修改 DIM。确认后运行 Apply-Tags.cmd。" -ForegroundColor Yellow
        exit 0
    }
    if (-not $updates.Count) {
        Write-Host "DIM 标签已经全部符合规则，无需更新。" -ForegroundColor Green
        exit 0
    }

    Write-Section "写入 DIM"
    $updated = 0
    for ($index = 0; $index -lt $updates.Count; $index += 100) {
        $last = [Math]::Min($index + 99, $updates.Count - 1)
        $batch = @($updates[$index..$last])
        $body = @{
            platformMembershipId = $membershipId
            destinyVersion = 2
            updates = @($batch | ForEach-Object { @{ action = "tag"; payload = $_ } })
        }
        $result = Invoke-DimApi $config $dimToken.accessToken "Post" "/profile" $body
        $results = @($result.results)
        if ($results.Count -ne $batch.Count) { throw "DIM 返回的结果数量不一致。" }
        foreach ($entry in $results) {
            if ([string]$entry.status -ne "Success") { throw "DIM 拒绝更新：$($entry.message)" }
        }
        $updated += $batch.Count
        Write-Host "已同步 $updated / $($updates.Count)"
    }
    Write-Host "标签同步完成：$updated 件。" -ForegroundColor Green
} catch {
    Write-Host ""
    Write-Host "失败：$($_.Exception.Message)" -ForegroundColor Red
    Write-Host "如需重新输入开发者配置，请运行 Reset-Login.cmd。" -ForegroundColor Yellow
    exit 1
}
