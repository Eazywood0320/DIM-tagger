[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$DestinationPath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Sources = [ordered]@{
    primary = "https://starside.work/shopping-primary/index.html"
    special = "https://starside.work/shopping-special/index.html"
    heavy = "https://starside.work/shopping-heavy/index.html"
    other = "https://starside.work/shopping-other/index.html"
}
$MinimumCounts = @{ primary = 280; special = 180; heavy = 120; other = 6 }

function Clean-Html([string]$Value) {
    if (-not $Value) { return "" }
    $text = [regex]::Replace($Value, "(?is)<[^>]+>", "")
    $text = [Net.WebUtility]::HtmlDecode($text)
    return ([regex]::Replace($text, "\s+", " ")).Trim()
}

function Get-RecordsFromFragment(
    [string]$Source,
    [string]$SourceUrl,
    [string]$Category,
    [string]$Fragment
) {
    $records = @()
    $articles = [regex]::Matches(
        $Fragment,
        '(?is)<article\b[^>]*class="[^"]*\brec\b[^"]*\br-weapon\b[^"]*"[^>]*>(.*?)</article>'
    )
    foreach ($articleMatch in $articles) {
        $article = $articleMatch.Value
        $rankMatch = [regex]::Match(
            $article,
            '(?is)<div\b[^>]*class="[^"]*\br-rank\b[^"]*"[^>]*>(.*?)</div>'
        )
        $nameMatch = [regex]::Match(
            $article,
            '(?is)<div\b[^>]*class="[^"]*\br-nm\b[^"]*"[^>]*>(.*?)</div>'
        )
        $rankText = Clean-Html $rankMatch.Groups[1].Value
        $name = Clean-Html $nameMatch.Groups[1].Value
        $rankNumber = 0
        $rankDigits = [regex]::Match($rankText, '\d+')
        if ($rankDigits.Success) { $rankNumber = [int]$rankDigits.Value }
        if (-not $name -or -not $rankNumber) { continue }

        $cellSegments = [regex]::Split(
            $article,
            '(?is)<div\b[^>]*class="[^"]*\br-cell\b[^"]*"[^>]*>'
        )
        $columns = @()
        foreach ($cellIndex in 3..6) {
            $perks = @()
            $segmentIndex = $cellIndex + 1
            if ($cellSegments.Count -gt $segmentIndex) {
                $perkMatches = [regex]::Matches(
                    $cellSegments[$segmentIndex],
                    '(?is)<div\b[^>]*class="[^"]*(?<![\w-])r-plug(?![\w-])[^"]*"[^>]*>(.*?)</div>'
                )
                foreach ($perkMatch in $perkMatches) {
                    $perk = Clean-Html $perkMatch.Groups[1].Value
                    foreach ($part in ([regex]::Split($perk, '\s*[/／]\s*'))) {
                        if ($part) { $perks += $part }
                    }
                }
            }
            $columns += ,@($perks)
        }
        $records += [pscustomobject]@{
            source = $Source
            sourceUrl = $SourceUrl
            category = $Category
            rank = $rankNumber
            name = $name
            columns = $columns
        }
    }
    return $records
}

function Get-Page([string]$Url) {
    $request = [Net.HttpWebRequest]::Create($Url)
    $request.Method = "GET"
    $request.UserAgent = "StarsideDimTagger/1.1"
    $request.Accept = "text/html,application/xhtml+xml"
    $request.Timeout = 45000
    $response = $request.GetResponse()
    try {
        $reader = New-Object IO.StreamReader(
            $response.GetResponseStream(),
            (New-Object Text.UTF8Encoding($false)),
            $true
        )
        try {
            $content = $reader.ReadToEnd()
        } finally {
            $reader.Dispose()
        }
        return [pscustomobject]@{
            StatusCode = [int]$response.StatusCode
            Content = $content
            Headers = $response.Headers
        }
    } finally {
        $response.Dispose()
    }
}

function Get-Sha256([string]$Text) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-", "").ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}

$allRecords = @()
$sourceMetadata = [ordered]@{}
$fingerprintParts = @()

foreach ($entry in $Sources.GetEnumerator()) {
    $source = [string]$entry.Key
    $indexUrl = [string]$entry.Value
    $restUrl = $indexUrl.Substring(0, $indexUrl.LastIndexOf("/") + 1) + "rest.html"
    $indexResponse = Get-Page $indexUrl
    $restResponse = Get-Page $restUrl
    $indexHtml = [string]$indexResponse.Content
    $restHtml = [string]$restResponse.Content
    if ($indexResponse.StatusCode -ne 200 -or $restResponse.StatusCode -ne 200) {
        throw "Starside $source 返回了非 200 状态。"
    }
    if ($indexHtml.Length -lt 5000 -or $restHtml.Length -lt 1000) {
        throw "Starside $source 页面内容异常短，拒绝替换本地清单。"
    }

    $sectionCategories = @{}
    $sectionMatches = [regex]::Matches(
        $indexHtml,
        '(?is)<section\b[^>]*id="([^"]+)"[^>]*>(.*?)</section>'
    )
    foreach ($sectionMatch in $sectionMatches) {
        $sectionId = $sectionMatch.Groups[1].Value
        $sectionBody = $sectionMatch.Groups[2].Value
        $headingMatch = [regex]::Match(
            $sectionBody,
            '(?is)<h2\b[^>]*class="[^"]*\bsect-label\b[^"]*"[^>]*>(.*?)</h2>'
        )
        $category = Clean-Html $headingMatch.Groups[1].Value
        if ($category) { $sectionCategories[$sectionId] = $category }
        if ($category -and $category -ne "说明") {
            foreach ($record in (Get-RecordsFromFragment $source $indexUrl $category $sectionBody)) {
                $allRecords += $record
            }
        }
    }

    $templateMatches = [regex]::Matches(
        $restHtml,
        '(?is)<template\b[^>]*data-rest="([^"]+)"[^>]*>(.*?)</template>'
    )
    foreach ($templateMatch in $templateMatches) {
        $sectionId = $templateMatch.Groups[1].Value
        $category = [string]$sectionCategories[$sectionId]
        if (-not $category -or $category -eq "说明") { continue }
        foreach ($record in (Get-RecordsFromFragment $source $indexUrl $category $templateMatch.Groups[2].Value)) {
            $allRecords += $record
        }
    }

    $sourceCount = @($allRecords | Where-Object source -eq $source).Count
    if ($sourceCount -lt $MinimumCounts[$source]) {
        throw "Starside $source 只解析到 $sourceCount 条，低于安全阈值 $($MinimumCounts[$source])。"
    }
    $indexEtag = [string]$indexResponse.Headers["ETag"]
    $restEtag = [string]$restResponse.Headers["ETag"]
    $lastModified = [string]$indexResponse.Headers["Last-Modified"]
    $sourceMetadata[$source] = [ordered]@{
        count = $sourceCount
        indexEtag = $indexEtag
        restEtag = $restEtag
        lastModified = $lastModified
    }
    $fingerprintParts += "$source|$indexEtag|$restEtag|$(Get-Sha256 ($indexHtml + $restHtml))"
}

if ($allRecords.Count -lt 650) {
    throw "Starside 总记录数只有 $($allRecords.Count)，拒绝替换本地清单。"
}
foreach ($record in $allRecords) {
    if (-not $record.name -or @($record.columns).Count -ne 4) {
        throw "Starside 记录结构不完整，拒绝替换本地清单。"
    }
    foreach ($column in $record.columns) {
        if (@($column).Count -lt 1) { throw "$($record.name) 存在空 Perk 列，拒绝替换本地清单。" }
    }
}

$sourceFingerprint = Get-Sha256 ($fingerprintParts -join "`n")
$existing = $null
if (Test-Path -LiteralPath $DestinationPath) {
    try {
        $existing = Get-Content -LiteralPath $DestinationPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $existingCount = @($existing.records).Count
        if ($existingCount -and $allRecords.Count -lt [Math]::Floor($existingCount * 0.85)) {
            throw "新清单比现有清单少超过 15%，拒绝自动替换。"
        }
        if ([string]$existing.sourceFingerprint -eq $sourceFingerprint) {
            [pscustomobject]@{
                changed = $false
                records = $allRecords.Count
                fetchedAt = [DateTime]::UtcNow.ToString("o")
                fingerprint = $sourceFingerprint
            }
            return
        }
    } catch {
        if ($_.Exception.Message -like "*拒绝自动替换*") { throw }
        $existing = $null
    }
}

$payload = [ordered]@{
    updated = (Get-Date -Format "yyyy-MM-dd")
    fetchedAt = [DateTime]::UtcNow.ToString("o")
    sourceFingerprint = $sourceFingerprint
    sources = $Sources
    sourceMetadata = $sourceMetadata
    records = @($allRecords)
}
$destinationDirectory = Split-Path -Parent $DestinationPath
New-Item -ItemType Directory -Force -Path $destinationDirectory | Out-Null
$tempPath = Join-Path $destinationDirectory ("starside-shopping.{0}.tmp" -f [Guid]::NewGuid().ToString("N"))
$json = $payload | ConvertTo-Json -Depth 8 -Compress
[IO.File]::WriteAllText($tempPath, $json, (New-Object Text.UTF8Encoding($false)))
try {
    Get-Content -LiteralPath $tempPath -Raw -Encoding UTF8 | ConvertFrom-Json | Out-Null
    if (Test-Path -LiteralPath $DestinationPath) {
        Copy-Item -LiteralPath $DestinationPath -Destination "$DestinationPath.last-good.json" -Force
    }
    Move-Item -LiteralPath $tempPath -Destination $DestinationPath -Force
} finally {
    if (Test-Path -LiteralPath $tempPath) { Remove-Item -LiteralPath $tempPath -Force }
}

[pscustomobject]@{
    changed = $true
    records = $allRecords.Count
    fetchedAt = $payload.fetchedAt
    fingerprint = $sourceFingerprint
}
