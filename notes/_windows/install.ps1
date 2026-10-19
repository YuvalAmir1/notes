# Emacs with the notes setup (notes/ in @repository@), installed or
# updated for you alone, in your user folder. Run it again to update:
#
#   irm https://github.com/@repository@/releases/download/notes/install.ps1 | iex
#
# Emacs comes from GNU; Typst, tinymist, ripgrep and fd from their releases
# on GitHub; the setup and its fonts from this repository's release.

# A block of its own, so that run through iex it leaves the session as it was.
& {
  $ErrorActionPreference = 'Stop'
  $ProgressPreference = 'SilentlyContinue'
  [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
  Add-Type -AssemblyName System.IO.Compression.FileSystem

  $Root = Join-Path $env:LOCALAPPDATA 'Notes'

  # A running Emacs holds files open that an update replaces.
  $running = Get-Process -Name emacs -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -and $_.Path.StartsWith($Root, [StringComparison]::OrdinalIgnoreCase) }
  if ($running) { throw 'Emacs is open: close it, then run this again.' }

  # Downloads go beside what they replace, so putting them in place is a rename.
  $Work = Join-Path $Root ('.download-' + [Guid]::NewGuid())
  New-Item -ItemType Directory -Force -Path $Work | Out-Null

  function Save-Url([string]$Url, [string]$Name) {
    $file = Join-Path $Work $Name
    Write-Host "Downloading $Name"
    Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $file
    return $file
  }

  function Expand-Zip([string]$Zip) {
    $dir = Join-Path $Work ([Guid]::NewGuid())
    [IO.Compression.ZipFile]::ExtractToDirectory($Zip, $dir)
    return $dir
  }

  function Get-Stamp([string]$File) {
    if (Test-Path $File) { return (Get-Content -Raw $File).Trim() }
    return ''
  }

  try {
    # Emacs, from GNU.
    $Emacs = Join-Path $Root 'emacs'
    $stamp = Join-Path $Root 'emacs.version'
    if ((Get-Stamp $stamp) -ne '@emacsVersion@') {
      $zip = Save-Url '@emacsUrl@' 'emacs.zip'
      if ((Get-FileHash -Algorithm SHA256 $zip).Hash -ne '@emacsSha256@') {
        throw 'The Emacs download is damaged: run this again.'
      }
      $new = Expand-Zip $zip
      if (Test-Path $Emacs) { Remove-Item -Recurse -Force $Emacs }
      Move-Item $new $Emacs
      Set-Content -Path $stamp -Value '@emacsVersion@'
    }

    # The programs Emacs runs, the versions the other systems have.
    $Bin = Join-Path $Root 'bin'
    New-Item -ItemType Directory -Force -Path $Bin | Out-Null
    $api = @{}
    if ($env:GITHUB_TOKEN) { $api['Authorization'] = "Bearer $env:GITHUB_TOKEN" }
    $tools = @(
      @{ Exe = 'typst.exe'; Repo = 'typst/typst'; Tag = 'v@typstVersion@' },
      @{ Exe = 'tinymist.exe'; Repo = 'Myriad-Dreamin/tinymist'; Tag = 'v@tinymistVersion@' },
      @{ Exe = 'rg.exe'; Repo = 'BurntSushi/ripgrep'; Tag = '@ripgrepVersion@' },
      @{ Exe = 'fd.exe'; Repo = 'sharkdp/fd'; Tag = 'v@fdVersion@' }
    )
    foreach ($tool in $tools) {
      $stamp = Join-Path $Bin ($tool.Exe + '.version')
      if ((Get-Stamp $stamp) -eq $tool.Tag) { continue }
      $release = Invoke-RestMethod -UseBasicParsing -Headers $api "https://api.github.com/repos/$($tool.Repo)/releases/tags/$($tool.Tag)"
      $asset = $release.assets | Where-Object { $_.name -match 'x86_64-pc-windows-msvc\.zip$' } | Select-Object -First 1
      if (-not $asset) {
        $asset = $release.assets | Where-Object { $_.name -match 'win32-x64\.exe$' } | Select-Object -First 1
      }
      if (-not $asset) { throw "$($tool.Repo) $($tool.Tag) has no download for Windows." }
      $file = Save-Url $asset.browser_download_url $asset.name
      if ($file.EndsWith('.zip')) {
        $file = (Get-ChildItem -Recurse -Filter $tool.Exe -Path (Expand-Zip $file) | Select-Object -First 1).FullName
      }
      Copy-Item -Force $file (Join-Path $Bin $tool.Exe)
      Set-Content -Path $stamp -Value $tool.Tag
    }

    # The setup, and the fonts it uses, for you alone (as Settings installs them).
    $zip = $env:NOTES_ZIP
    if (-not $zip) {
      $zip = Save-Url 'https://github.com/@repository@/releases/download/notes/notes-windows.zip' 'notes-windows.zip'
    }
    $new = Join-Path (Expand-Zip $zip) 'config'
    $Config = Join-Path $Root 'config'
    if (Test-Path $Config) { Remove-Item -Recurse -Force $Config }
    Move-Item $new $Config

    $Fonts = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    $key = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    New-Item -ItemType Directory -Force -Path $Fonts | Out-Null
    if (-not (Test-Path $key)) { New-Item -Force -Path $key | Out-Null }
    Add-Type -Namespace Notes -Name Gdi -MemberDefinition '[DllImport("gdi32.dll", CharSet = CharSet.Unicode)] public static extern int AddFontResource(string file);'
    foreach ($font in Get-ChildItem (Join-Path $Config 'fonts')) {
      $to = Join-Path $Fonts $font.Name
      if (-not (Test-Path $to)) {
        Copy-Item $font.FullName $to
        [Notes.Gdi]::AddFontResource($to) | Out-Null
      }
      New-ItemProperty -Force -Path $key -Name ($font.BaseName + ' (TrueType)') -Value $to | Out-Null
    }

    # Emacs in the Start menu and on the desktop, where it was called Notes once.
    $shell = New-Object -ComObject WScript.Shell
    foreach ($dir in [Environment]::GetFolderPath('Programs'), [Environment]::GetFolderPath('Desktop')) {
      $old = Join-Path $dir 'Notes.lnk'
      if ((Test-Path $old) -and $shell.CreateShortcut($old).TargetPath.StartsWith($Root, [StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -Force $old
      }
      $link = $shell.CreateShortcut((Join-Path $dir 'Emacs.lnk'))
      $link.TargetPath = Join-Path $Emacs 'bin\runemacs.exe'
      $link.Arguments = '--init-directory="' + $Config + '"'
      $link.WorkingDirectory = $env:USERPROFILE
      $link.IconLocation = (Join-Path $Emacs 'bin\runemacs.exe') + ',0'
      $link.Save()
    }
  } finally {
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $Work
  }

  Write-Host 'Emacs is ready: open it from the Start menu or the desktop.'
}
