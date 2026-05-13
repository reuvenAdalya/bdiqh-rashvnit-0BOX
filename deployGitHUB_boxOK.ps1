# 1. טעינת רכיבים גרפיים
try { Add-Type -AssemblyName Microsoft.VisualBasic } catch {}

# --- פונקציית תעתיק חסינה ---
function Get-TransliteratedName {
    param([string]$InputString)
    $map = @{}
    $chars = @(
        @{c=0x05D0; v='a'}, @{c=0x05D1; v='b'}, @{c=0x05D2; v='g'}, @{c=0x05D3; v='d'},
        @{c=0x05D4; v='h'}, @{c=0x05D5; v='v'}, @{c=0x05D6; v='z'}, @{c=0x05D7; v='h'},
        @{c=0x05D8; v='t'}, @{c=0x05D9; v='i'}, @{c=0x05DA; v='k'}, @{c=0x05DB; v='k'},
        @{c=0x05DC; v='l'}, @{c=0x05DD; v='m'}, @{c=0x05DE; v='m'}, @{c=0x05DF; v='n'},
        @{c=0x05E0; v='n'}, @{c=0x05E1; v='s'}, @{c=0x05E2; v='a'}, @{c=0x05E3; v='p'},
        @{c=0x05E4; v='p'}, @{c=0x05E5; v='ts'}, @{c=0x05E6; v='ts'}, @{c=0x05E7; v='q'},
        @{c=0x05E8; v='r'}, @{c=0x05E9; v='sh'}, @{c=0x05EA; v='t'}
    )
    foreach ($item in $chars) {
        $charObj = [char]$item.c
        if (-not $map.ContainsKey($charObj)) { $map.Add($charObj, $item.v) }
    }
    $result = ""
    if ($InputString) {
        $InputString.ToLower().ToCharArray() | ForEach-Object {
            if ($map.ContainsKey($_)) { $result += $map[$_] }
            elseif ($_ -match '[a-z0-9]') { $result += $_ }
            elseif ($_ -eq ' ' -or $_ -eq '-' -or $_ -eq '_') { $result += '-' }
        }
    }
    return ($result -replace '-+', '-').Trim('-')
}

# --- 2. וידוא חיבור ---
$username = gh api user --jq .login 2>$null
if (!$username) { Write-Host "Please login: gh auth login" -ForegroundColor Red; exit }

# --- 3. זיהוי נתיבים ---
$currentFolder = Get-Item $PSScriptRoot
$parentFolder = $currentFolder.Parent
$fullFolderName = $parentFolder.Name
$parts = $fullFolderName -split ' ', 2 
$projectPart = if ($parts.Count -gt 1) { $parts[1] } else { $fullFolderName }
$suggestedName = Get-TransliteratedName -InputString $projectPart

# --- 4. אישור פרטים ---
$repoName = [Microsoft.VisualBasic.Interaction]::InputBox("Confirm Repo Name:", "GitHub Deploy", $suggestedName)
if (!$repoName) { exit }
$topicName = [Microsoft.VisualBasic.Interaction]::InputBox("Enter Topic:", "GitHub Topic", "havitot")
if (!$topicName) { $topicName = "havitot" }

# --- 5. עבודת Git + פתרון בעיית Box ---
Set-Location $currentFolder.FullName

# פתרון קריטי לבעיית ה-Dubious Ownership ב-Box
Write-Host "Registering directory as safe for Git..." -ForegroundColor Gray
git config --global --add safe.directory $currentFolder.FullName.Replace('\', '/')

if (!(Test-Path ".git")) {
    git init
    git checkout -b main 2>$null
}
git branch -M main

# יצירה וסנכרון
$remoteExists = git remote | Where-Object { $_ -eq "origin" }
if (!$remoteExists) {
    Write-Host "Creating Repository on GitHub..." -ForegroundColor Cyan
    gh repo create $repoName --public --source=. --remote=origin
}

gh repo edit $repoName --add-topic $topicName

Write-Host "Pushing files..." -ForegroundColor White
git add .
git commit -m "Initial deploy from Box" 2>$null
git push -u origin main --force

# --- 6. הפעלת Pages (API) ---
Write-Host "Enforcing GitHub Pages configuration..." -ForegroundColor Yellow
Start-Sleep -Seconds 5
$apiPath = "repos/$username/$repoName/pages"
gh api -X POST $apiPath -f "source[branch]=main" -f "source[path]=/" --silent 2>$null
gh repo edit $repoName --enable-pages --pages-branch main --pages-path / 2>$null

# --- 7. סיום ---
$siteUrl = "https://$username.github.io/$repoName/"
Write-Host "`n" + ("=" * 50) -ForegroundColor Green
Write-Host "  SUCCESS! Project is live at:" -ForegroundColor Green
Write-Host "  $siteUrl" -ForegroundColor White
Write-Host ("=" * 50) -ForegroundColor Green

# פתיחת האתר החי בדפדפן
Start-Process $siteUrl

Write-Host "`nPress any key to close..." -ForegroundColor Yellow
[void]($Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown"))