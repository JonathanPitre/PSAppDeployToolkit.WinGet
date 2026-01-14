# Install Build Dependencies
# Run this script in an interactive PowerShell session to install required build modules

Write-Host "Installing build dependencies..." -ForegroundColor Cyan

# Set TLS 1.2 for secure connections (required for package downloads)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

# Ensure PackageManagement module is available and imported
Write-Host "`n[Pre-check] Verifying required modules..." -ForegroundColor Yellow
try {
    # Check if PackageManagement is available
    if (-not (Get-Module -Name PackageManagement -ListAvailable)) {
        Write-Host "  PackageManagement module not found, attempting to install..." -ForegroundColor Yellow
        try {
            # Try to install PackageManagement if Install-Module is available
            if (Get-Command Install-Module -ErrorAction SilentlyContinue) {
                Install-Module -Name PackageManagement -Scope CurrentUser -AllowClobber -ErrorAction Stop
                Write-Host "  PackageManagement module installed successfully" -ForegroundColor Green
            } else {
                Write-Host "  Error: PackageManagement module is not available and Install-Module is not available." -ForegroundColor Red
                Write-Host "  This module is required for package provider and module installation." -ForegroundColor Red
                Write-Host "  Please ensure you're running PowerShell 5.1 or later, or install PackageManagement manually." -ForegroundColor Yellow
                exit 1
            }
        } catch {
            Write-Host "  Error: Could not install PackageManagement module: $_" -ForegroundColor Red
            Write-Host "  This module is required for package provider and module installation." -ForegroundColor Red
            Write-Host "  Please ensure you're running PowerShell 5.1 or later, or install PackageManagement manually." -ForegroundColor Yellow
            exit 1
        }
    }
    
    # Import PackageManagement only if not already loaded
    if (-not (Get-Module -Name PackageManagement)) {
        Import-Module PackageManagement -ErrorAction Stop
        Write-Host "  PackageManagement module loaded" -ForegroundColor Green
    } else {
        Write-Host "  PackageManagement module already loaded" -ForegroundColor Green
    }
    
    # Check if PowerShellGet is available
    if (-not (Get-Module -Name PowerShellGet -ListAvailable)) {
        Write-Host "  Error: PowerShellGet module is not available on this system." -ForegroundColor Red
        Write-Host "  This module is required for module installation from PSGallery." -ForegroundColor Red
        Write-Host "  Please ensure you're running PowerShell 5.1 or later, or install PowerShellGet manually." -ForegroundColor Yellow
        exit 1
    }
    
    # Import PowerShellGet only if not already loaded (without -Force to avoid assembly conflicts)
    if (-not (Get-Module -Name PowerShellGet)) {
        Import-Module PowerShellGet -ErrorAction Stop
        Write-Host "  PowerShellGet module loaded" -ForegroundColor Green
    } else {
        Write-Host "  PowerShellGet module already loaded" -ForegroundColor Green
    }
} catch {
    Write-Host "  Error: Could not import required modules: $_" -ForegroundColor Red
    Write-Host "  Note: If you see an assembly conflict, the modules may already be loaded." -ForegroundColor Yellow
    Write-Host "  Verifying cmdlets are available..." -ForegroundColor Yellow
    
    # Verify that required cmdlets are available even if import failed
    $requiredCmdlets = @('Get-PackageProvider', 'Install-PackageProvider', 'Get-PSRepository', 'Register-PSRepository', 'Set-PSRepository', 'Install-Module')
    $missingCmdlets = @()
    foreach ($cmdlet in $requiredCmdlets) {
        if (-not (Get-Command -Name $cmdlet -ErrorAction SilentlyContinue)) {
            $missingCmdlets += $cmdlet
        }
    }
    
    if ($missingCmdlets.Count -gt 0) {
        Write-Host "  Error: Required cmdlets are not available: $($missingCmdlets -join ', ')" -ForegroundColor Red
        exit 1
    } else {
        Write-Host "  All required cmdlets are available, continuing..." -ForegroundColor Green
    }
}

# Ensure PSGallery is registered and trusted (required for package provider installation)
Write-Host "`n[0/3] Ensuring PSGallery repository is configured..." -ForegroundColor Yellow
try {
    $repo = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
    if (-not $repo) {
        Write-Host "  Registering PSGallery repository..." -ForegroundColor Gray
        Register-PSRepository -Default -ErrorAction Stop | Out-Null
        Write-Host "  PSGallery repository registered" -ForegroundColor Green
    } else {
        Write-Host "  PSGallery repository already registered" -ForegroundColor Green
    }
    
    # Set as trusted if not already
    if ($repo.InstallationPolicy -ne 'Trusted') {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop | Out-Null
        Write-Host "  PSGallery repository set to Trusted" -ForegroundColor Green
    } else {
        Write-Host "  PSGallery repository already trusted" -ForegroundColor Green
    }
} catch {
    Write-Host "  Warning: Could not configure PSGallery: $_" -ForegroundColor Yellow
}

# Ensure NuGet provider is available
Write-Host "`n[1/3] Installing NuGet package provider..." -ForegroundColor Yellow
try {
    $nuget = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
    if (-not $nuget) {
        Write-Host "  Installing NuGet provider (this may take a moment)..." -ForegroundColor Gray
        # Verify PSGallery is available before installing
        $repo = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
        if (-not $repo) {
            Write-Host "  PSGallery not found, registering it first..." -ForegroundColor Gray
            Register-PSRepository -Default -ErrorAction Stop | Out-Null
        }
        $null = Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser -Confirm:$false -ErrorAction Stop
        Write-Host "  NuGet provider installed successfully" -ForegroundColor Green
    } else {
        Write-Host "  NuGet provider already installed (Version: $($nuget.Version))" -ForegroundColor Green
    }
} catch {
    Write-Host "  Error: Could not install NuGet provider: $_" -ForegroundColor Red
    Write-Host "  Troubleshooting:" -ForegroundColor Yellow
    Write-Host "    - Ensure PSGallery is registered: Register-PSRepository -Default" -ForegroundColor White
    Write-Host "    - Try running PowerShell as Administrator" -ForegroundColor White
    Write-Host "    - Check your internet connection" -ForegroundColor White
}

# Set PSGallery as trusted (redundant check, but ensures it's set)
Write-Host "`n[2/3] Verifying PSGallery repository configuration..." -ForegroundColor Yellow
try {
    $repo = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
    if ($repo -and $repo.InstallationPolicy -ne 'Trusted') {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop | Out-Null
        Write-Host "  PSGallery repository set to Trusted" -ForegroundColor Green
    } else {
        Write-Host "  PSGallery repository is properly configured" -ForegroundColor Green
    }
} catch {
    Write-Host "  Warning: Could not verify PSGallery configuration: $_" -ForegroundColor Yellow
    Write-Host "  Continuing anyway..." -ForegroundColor Gray
}

# Install InvokeBuild module
Write-Host "`n[3/3] Installing InvokeBuild module..." -ForegroundColor Yellow
try {
    # Check if already installed
    $existing = Get-Module -ListAvailable -Name InvokeBuild | Where-Object { $_.Version -eq [version]'5.11.3' }
    if ($existing) {
        Write-Host "  InvokeBuild 5.11.3 is already installed" -ForegroundColor Green
    } else {
        Write-Host "  Downloading and installing InvokeBuild 5.11.3 (this may take a moment)..." -ForegroundColor Gray
        Install-Module -Name InvokeBuild -RequiredVersion 5.11.3 -Repository PSGallery -Force -SkipPublisherCheck -Scope CurrentUser -AllowClobber -ErrorAction Stop
        Write-Host "  InvokeBuild module installed successfully" -ForegroundColor Green
        
        # Refresh module cache to ensure PowerShell can find the newly installed module
        Write-Host "  Refreshing module cache..." -ForegroundColor Gray
        $null = Get-Module -ListAvailable -Name InvokeBuild -Refresh -ErrorAction SilentlyContinue
    }

    # Verify installation by checking if module is available
    Write-Host "`nVerifying installation..." -ForegroundColor Gray
    $installedModule = Get-Module -ListAvailable -Name InvokeBuild | Where-Object { $_.Version -eq [version]'5.11.3' }
    if (-not $installedModule) {
        # Try to find any version
        $installedModule = Get-Module -ListAvailable -Name InvokeBuild | Select-Object -First 1
        if ($installedModule) {
            Write-Host "  Warning: Found InvokeBuild version $($installedModule.Version) instead of 5.11.3" -ForegroundColor Yellow
        } else {
            # Provide diagnostic information
            Write-Host "  Diagnostic information:" -ForegroundColor Yellow
            $modulePaths = $env:PSModulePath -split ';'
            Write-Host "  Module search paths:" -ForegroundColor Gray
            foreach ($path in $modulePaths) {
                if (Test-Path $path) {
                    Write-Host "    - $path" -ForegroundColor Gray
                }
            }
            
            # Check if module exists in CurrentUser scope path
            $currentUserModulePath = Join-Path $env:USERPROFILE "Documents\PowerShell\Modules"
            $invokeBuildPath = Join-Path $currentUserModulePath "InvokeBuild"
            if (Test-Path $invokeBuildPath) {
                Write-Host "  Found InvokeBuild directory at: $invokeBuildPath" -ForegroundColor Yellow
                # Try to import directly from path
                $versionDirs = Get-ChildItem -Path $invokeBuildPath -Directory -ErrorAction SilentlyContinue
                if ($versionDirs) {
                    $latestVersion = $versionDirs | Sort-Object Name -Descending | Select-Object -First 1
                    $moduleManifest = Join-Path $latestVersion.FullName "InvokeBuild.psd1"
                    if (Test-Path $moduleManifest) {
                        Write-Host "  Attempting to import from: $moduleManifest" -ForegroundColor Gray
                        Import-Module $moduleManifest -ErrorAction Stop
                        $installedModule = Get-Module -Name InvokeBuild
                    }
                }
            }
            
            if (-not $installedModule) {
                throw "InvokeBuild module was not found in any module directory after installation."
            }
        }
    }
    
    # Import the module (with version if we found a specific one)
    if ($installedModule -and -not (Get-Module -Name InvokeBuild)) {
        if ($installedModule.Version) {
            Import-Module InvokeBuild -RequiredVersion $installedModule.Version -ErrorAction Stop
        } else {
            Import-Module InvokeBuild -ErrorAction Stop
        }
    }
    $cmd = Get-Command Invoke-Build -ErrorAction Stop
    Write-Host "`n✓ InvokeBuild is now available!" -ForegroundColor Green
    Write-Host "  Command: $($cmd.Name)" -ForegroundColor Cyan
    Write-Host "  Source: $($cmd.Source)" -ForegroundColor Cyan
    Write-Host "  Version: $($installedModule.Version)" -ForegroundColor Cyan
    Write-Host "`n  You can now run:" -ForegroundColor Yellow
    Write-Host "    Invoke-Build -File .\src\PSAppDeployToolkit.WinGet.build.ps1" -ForegroundColor Cyan
} catch {
    Write-Host "  Error installing InvokeBuild: $_" -ForegroundColor Red
    Write-Host "`nTroubleshooting steps:" -ForegroundColor Yellow
    Write-Host "  1. Check if module was installed: Get-Module -ListAvailable -Name InvokeBuild" -ForegroundColor White
    Write-Host "  2. Check module paths: `$env:PSModulePath" -ForegroundColor White
    Write-Host "  3. Try running PowerShell as Administrator" -ForegroundColor White
    Write-Host "  4. Check your internet connection" -ForegroundColor White
    Write-Host "  5. Try running the full bootstrap script: .\actions_bootstrap.ps1" -ForegroundColor White
    exit 1
}

Write-Host "`nDone!" -ForegroundColor Green
