param(
    [Parameter(Mandatory = $true)]
    [string] $InputPath,

    [Parameter(Mandatory = $true)]
    [string] $OutputPath,

    [switch] $SmallCaps
)

# --- Helpers ---------------------------------------------------------------

function Strip-GutenbergHeaderFooter {
    param([string] $Text)

    # Try to isolate content between START/END markers; fall back to whole text if not found
    $startPattern = '(?im)^\*\*\*\s*START OF (?:THIS|THE) PROJECT GUTENBERG.*?$'
    $endPattern   = '(?im)^\*\*\*\s*END OF (?:THIS|THE) PROJECT GUTENBERG.*?$'

    $startMatch = [regex]::Match($Text, $startPattern)
    $endMatch   = [regex]::Match($Text, $endPattern)

    if ($startMatch.Success -and $endMatch.Success -and $endMatch.Index -gt $startMatch.Index) {
        $contentStart = $startMatch.Index + $startMatch.Length
        $contentLen   = $endMatch.Index - $contentStart
        return $Text.Substring($contentStart, $contentLen).Trim()
    } else {
        return $Text
    }
}

function Extract-Metadata {
    param([string] $FullText)

    $meta = @{
        Title  = $null
        Author = $null
    }

    # Look in the header portion (before START marker) for Title/Author lines
    $headerEndPattern = '(?im)^\*\*\*\s*START OF (?:THIS|THE) PROJECT GUTENBERG.*?$'
    $headerEnd = [regex]::Match($FullText, $headerEndPattern)
    $header = if ($headerEnd.Success) { $FullText.Substring(0, $headerEnd.Index) } else { $FullText }

    $titleMatch  = [regex]::Match($header, '(?im)^\s*Title:\s*(.+?)\s*$')
    $authorMatch = [regex]::Match($header, '(?im)^\s*Author:\s*(.+?)\s*$')

    if ($titleMatch.Success)  { $meta.Title  = $titleMatch.Groups[1].Value.Trim() }
    if ($authorMatch.Success) { $meta.Author = $authorMatch.Groups[1].Value.Trim() }

    return $meta
}

function Escape-LaTeX {
    param([string] $S)
    # IMPORTANT: do not escape inside our placeholders; we’ll escape first, then restore tokens
    # Escape order matters for backslash
    $S = $S -replace '\\',  '\textbackslash{}'
    $S = $S -replace '\$',  '\$'
    $S = $S -replace '&',   '\&'
    $S = $S -replace '%',   '\%'
    $S = $S -replace '#',   '\#'
    $S = $S -replace '\^',  '\^{}'
    $S = $S -replace '_',   '\_'
    $S = $S -replace '{',   '\{'
    $S = $S -replace '}',   '\}'
    $S = $S -replace '~',   '\textasciitilde{}'
    return $S
}

function Normalize-LineEndings {
    param([string] $S)
    return $S -replace '\r\n?', "`n"
}

# Wrap regex replace into a helper that runs Singleline + Multiline
function Replace-Regex {
    param(
        [string] $Text,
        [string] $Pattern,
        [scriptblock] $Evaluator
    )
    $options = [System.Text.RegularExpressions.RegexOptions]::Singleline -bor `
               [System.Text.RegularExpressions.RegexOptions]::Multiline
    return [System.Text.RegularExpressions.Regex]::Replace($Text, $Pattern, { param($m) & $Evaluator $m }, $options)
}

# --- Read input ------------------------------------------------------------

if (-not (Test-Path -LiteralPath $InputPath)) {
    throw "Input file not found: $InputPath"
}

$textRaw = Get-Content -LiteralPath $InputPath -Raw
$textRaw = Normalize-LineEndings $textRaw

$meta = Extract-Metadata -FullText $textRaw

# --- Remove Gutenberg header/footer ---------------------------------------

$content = Strip-GutenbergHeaderFooter -Text $textRaw

# --- Tokenize formatting BEFORE escaping ----------------------------------
# Use unique tokens unlikely to appear in text. We’ll escape later, then detokenize to LaTeX.

# Italics: _..._  (avoid matching _ in snake_case: require non-space after leading _ and before trailing _)
# Pattern: (?s)(?<!\w)_(?!\s)(.+?)(?<!\s)_(?!\w)
$content = Replace-Regex -Text $content -Pattern '(?s)(?<!\w)_(?!\s)(.+?)(?<!\s)_(?!\w)' -Evaluator {
    param($m)
    $inner = $m.Groups[1].Value
    "«EMPH[$inner]»"
}

# Bold (rare): *...*
$content = Replace-Regex -Text $content -Pattern '(?s)(?<!\w)\*(?!\s)(.+?)(?<!\s)\*(?!\w)' -Evaluator {
    param($m)
    $inner = $m.Groups[1].Value
    "«BOLD[$inner]»"
}

# Scene breaks: lines of *** or * * * or ---/— — —
$content = Replace-Regex -Text $content -Pattern '^[ \t]*(?:\*{3,}|\*\s*\*\s*\*|—\s*—\s*—|-{3,}|_ {3,})[ \t]*$' -Evaluator {
    param($m)
    "«ASTERISM»"
}

# Chapter headings (simple heuristic): lines starting with CHAPTER/Chapter ...
$content = Replace-Regex -Text $content -Pattern '^(?:\s*)(CHAPTER|Chapter)\s+([IVXLCDM\d][^\r\n]*)$' -Evaluator {
    param($m)
    $full = ($m.Groups[1].Value + " " + $m.Groups[2].Value).Trim()
    "«CHAPTER[$full]»"
}

# Optional: ALL-CAPS to small caps (three or more letters). On only if -SmallCaps.
if ($SmallCaps.IsPresent) {
    $content = Replace-Regex -Text $content -Pattern '\b([A-Z]{3,})\b' -Evaluator {
        param($m)
        "«SCAPS[" + $m.Groups[1].Value + "]»"
    }
}

# --- Escape LaTeX special chars globally ----------------------------------

$content = Escape-LaTeX $content

# --- De-tokenize to LaTeX --------------------------------------------------

# De-tokenize small caps first (their content is already escaped)
$content = $content -replace '«SCAPS\[(.+?)\]»', '\textsc{$1}'

# Chapters
$content = $content -replace '«CHAPTER\[(.+?)\]»', '\chapter{$1}'

# Asterism (centered ***)
$content = $content -replace '«ASTERISM»', "\`n\`\n\\begin{center}***\\end{center}\n\`\n"

# Bold and italics
$content = $content -replace '«BOLD\[(.+?)\]»', '\textbf{$1}'
$content = $content -replace '«EMPH\[(.+?)\]»', '\emph{$1}'

# Cleanup extra blank lines around asterisms (tidy, optional)
$content = $content -replace "(\n){3,}", "`n`n"

# --- Build LaTeX document --------------------------------------------------

# Title block (fallbacks if not found)
$latexTitle  = if ($meta.Title)  { $meta.Title }  else { "Untitled" }
$latexAuthor = if ($meta.Author) { $meta.Author } else { "Project Gutenberg" }

$header = @"
\documentclass[12pt]{book}
\usepackage[T1]{fontenc}
\usepackage[utf8]{inputenc}
\usepackage{microtype}
\usepackage{geometry}
\geometry{margin=1in}
\usepackage{csquotes}
\title{$latexTitle}
\author{$latexAuthor}
\date{}
\begin{document}
\maketitle
\frontmatter
% (Optional) add a TOC by uncommenting:
% \tableofcontents
\mainmatter

"@

$footer = @"

\end{document}
"@

# If the text still contains long line-wrapped paragraphs, you probably want to
# leave blank lines as-is (LaTeX treats blank line as paragraph break).
# Gutenberg often uses a blank line between paragraphs already.

# Write output
$full = $header + $content + $footer
Set-Content -LiteralPath $OutputPath -Value $full -Encoding UTF8

Write-Host "Wrote LaTeX to $OutputPath"
