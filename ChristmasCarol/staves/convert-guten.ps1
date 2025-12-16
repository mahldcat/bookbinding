param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath
)

if (-not (Test-Path -LiteralPath $InputPath)) {
    Write-Error "Input file '$InputPath' does not exist."
    exit 1
}

# Default output: same folder, '.tex' appended
if (-not $OutputPath) {
    $OutputPath = "$InputPath.tex"
}

# Read full file as a single string (UTF-8)
$content = Get-Content -LiteralPath $InputPath -Encoding UTF8 -Raw

# Replacement rules:
# _word_  -> \emph{word}
# =word=  -> \textbf{word}
# *word*  -> \textsc{word}
# #word#  -> \textbf{word}
$replacements = @(
    @{
        Pattern     = '_([^_]+)_'
        Replacement = '\emph{$1}'
    },
    @{
        Pattern     = '=([^=]+)='
        Replacement = '\textbf{$1}'
    },
    @{
        Pattern     = '\*([^*]+)\*'
        Replacement = '\textsc{$1}'
    },
    @{
        Pattern     = '#([^#]+)#'
        Replacement = '\textbf{$1}'
    }
)

foreach ($rule in $replacements) {
    $pattern = $rule.Pattern
    $replacement = $rule.Replacement
    $content = [regex]::Replace($content, $pattern, $replacement)
}

# Write the converted text
Set-Content -LiteralPath $OutputPath -Encoding UTF8 -Value $content

Write-Host "Converted file written to: $OutputPath"
