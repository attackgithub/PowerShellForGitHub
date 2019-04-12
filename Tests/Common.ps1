# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

# Caches if the tests are actively configured with an access token.
$script:accessTokenConfigured = $false

# The path to a file storing the contents of the user's config file before tests got underway
$script:originalConfigFile = $null

function Initialize-CommonTestSetup
{
<#
    .SYNOPSIS
        Configures the tests to run with the authentication information stored in the project's
        Azure DevOps pipeline (if that information exists in the environment).

    .DESCRIPTION
        Configures the tests to run with the authentication information stored in the project's
        Azure DevOps pipeline (if that information exists in the environment).

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .NOTES
        Internal-only helper method.

        The only reason this exists is so that we can leverage CodeAnalysis.SuppressMessageAttribute,
        which can only be applied to functions.

        We call this immediately after the declaration so that Continuous Integration initialization
        can heppen (if applicable).
#>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "", Justification="Needed to configure with the stored, encrypted string value in AppVeyor.")]
    param()

    $moduleRootPath = Split-Path -Parent (Split-Path -Parent $Script:MyInvocation.MyCommand.Path)
    . (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Config\Settings.ps1')
    Import-Module -Name (Join-Path -Path $moduleRootPath -ChildPath 'PowerShellForGitHub.psd1') -Force

    if (-not [string]::IsNullOrEmpty($env:ciAccessToken))
    {
        $secureString = $env:ciAccessToken | ConvertTo-SecureString -AsPlainText -Force
        $cred = New-Object System.Management.Automation.PSCredential "<username is ignored>", $secureString
        Set-GitHubAuthentication -Credential $cred

        $script:ownerName = $env:ciOwnerName
        $script:organizationName = $env:ciOrganizationName

        $message = @(
            'This run is being executed in the Azure DevOps environment.',
            'The GitHub Api Token won''t be decrypted in PR runs causing some tests to fail.',
            '403 errors possible due to GitHub hourly limit for unauthenticated queries.',
            'Use Set-GitHubAuthentication manually. modify the values in Tests\Config\Settings.ps1,',
            'and run tests on your machine first.')
        Write-Warning -Message ($message -join [Environment]::NewLine)
    }

    $script:accessTokenConfigured = Test-GitHubAuthenticationConfigured
    if (-not $script:accessTokenConfigured)
    {
        $message = @(
            'GitHub API Token not defined, some of the tests will be skipped.',
            '403 errors possible due to GitHub hourly limit for unauthenticated queries.')
        Write-Warning -Message ($message -join [Environment]::NewLine)
    }

    # Backup the user's configuration before we begin, and ensure we're at a pure state before running
    # the tests.  We'll restore it at the end.
    $script:originalConfigFile = New-TemporaryFile

    Backup-GitHubConfiguration -Path $script:originalConfigFile
    Set-GitHubConfiguration -DisableTelemetry # Avoid the telemetry event from calling Reset-GitHubConfiguration
    Reset-GitHubConfiguration
    Set-GitHubConfiguration -DisableTelemetry # We don't want UT's to impact telemetry
    Set-GitHubConfiguration -LogRequestBody # Make it easier to debug UT failures
}

Initialize-CommonTestSetup
