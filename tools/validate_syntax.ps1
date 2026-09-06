<#
    Arma 3 Systematic Syntax & Structure Validator
    Author: Arma-AI Automated Quality Assurance
    File: tools/validate_syntax.ps1
#>

param(
    [string]$TargetDir = (Get-Location).Path
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Arma 3 Systematic Syntax & Delimiter Auditor" -ForegroundColor Cyan
Write-Host "  Target: $TargetDir" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$allFiles = Get-ChildItem -Path $TargetDir -Recurse -Include *.sqf, *.sqm, *.ext, *.cpp, *.hpp | Where-Object {
    $_.FullName -notmatch "\\\.git\\" -and $_.FullName -notmatch "\\\.hemttout\\"
}

$errorCount = 0
$checkedCount = 0

function Test-FileDelimiters {
    param(
        [System.IO.FileInfo]$File
    )

    # Check if file is native binarized RAP config (Eden binary mission.sqm)
    $bytes = [System.IO.File]::ReadAllBytes($File.FullName)
    if ($bytes.Length -ge 4 -and ($bytes[0] -eq 0 -or ($bytes[1] -eq 0x72 -and $bytes[2] -eq 0x61 -and $bytes[3] -eq 0x50))) {
        return @()
    }

    $content = [System.IO.File]::ReadAllText($File.FullName)
    $lines = [System.IO.File]::ReadAllLines($File.FullName)
    $len = $content.Length

    $stack = New-Object System.Collections.Generic.Stack[PSObject]
    $inSingleQuote = $false
    $inDoubleQuote = $false
    $inLineComment = $false
    $inBlockComment = $false

    $lineNum = 1
    $colNum = 0

    $fileErrors = @()

    # Special SQM / Config checks for illegal characters in class names
    for ($i = 0; $i -ge 0 -and $i -lt $lines.Count; $i++) {
        $curLine = $lines[$i]
        $curLineNum = $i + 1

        # Check for illegal '#' in class names
        if ($curLine -match 'class\s+[^\s{;]*#[^\s{;]*') {
            $fileErrors += "Line $curLineNum : Illegal '#' character found in class declaration: '$curLine'"
        }
    }

    for ($i = 0; $i -lt $len; $i++) {
        $ch = $content[$i]
        $nextCh = if ($i + 1 -lt $len) { $content[$i + 1] } else { [char]0 }

        if ($ch -eq "`n") {
            $lineNum++
            $colNum = 0
            $inLineComment = $false
            continue
        }
        $colNum++

        # Handle line comments
        if ($inLineComment) {
            continue
        }

        # Handle block comments
        if ($inBlockComment) {
            if ($ch -eq '*' -and $nextCh -eq '/') {
                $inBlockComment = $false
                $i++
                $colNum++
            }
            continue
        }

        # Handle strings
        if ($inSingleQuote) {
            if ($ch -eq "'") {
                if ($nextCh -eq "'") {
                    $i++ # Escaped quote in SQF ''
                    $colNum++
                } else {
                    $inSingleQuote = $false
                }
            }
            continue
        }

        if ($inDoubleQuote) {
            if ($ch -eq '"') {
                if ($nextCh -eq '"') {
                    $i++ # Escaped quote in SQF ""
                    $colNum++
                } else {
                    $inDoubleQuote = $false
                }
            }
            continue
        }

        # Check start of comments
        if ($ch -eq '/' -and $nextCh -eq '/') {
            $inLineComment = $true
            $i++
            $colNum++
            continue
        }

        if ($ch -eq '/' -and $nextCh -eq '*') {
            $inBlockComment = $true
            $i++
            $colNum++
            continue
        }

        # Check start of strings
        if ($ch -eq "'") {
            $inSingleQuote = $true
            continue
        }

        if ($ch -eq '"') {
            $inDoubleQuote = $true
            continue
        }

        # Delimiter stacking
        if ($ch -eq '{' -or $ch -eq '[' -or $ch -eq '(') {
            $item = [PSCustomObject]@{
                Char = $ch
                Line = $lineNum
                Col = $colNum
            }
            $stack.Push($item)
        }
        elseif ($ch -eq '}' -or $ch -eq ']' -or $ch -eq ')') {
            if ($stack.Count -eq 0) {
                $fileErrors += "Line $lineNum, Col $colNum : Unmatched closing '$ch'"
            } else {
                $top = $stack.Pop()
                $expected = switch ($top.Char) {
                    '{' { '}' }
                    '[' { ']' }
                    '(' { ')' }
                }
                if ($ch -ne $expected) {
                    $fileErrors += "Line $lineNum, Col $colNum : Mismatched delimiter: expected '$expected' (opened at line $($top.Line), col $($top.Col)), but found '$ch'"
                }
            }
        }
    }

    # Check unclosed strings or comments
    if ($inSingleQuote) {
        $fileErrors += "End of File : Unclosed single-quoted string"
    }
    if ($inDoubleQuote) {
        $fileErrors += "End of File : Unclosed double-quoted string"
    }
    if ($inBlockComment) {
        $fileErrors += "End of File : Unclosed block comment /* ... */"
    }

    # Check unclosed delimiters
    while ($stack.Count -gt 0) {
        $unclosed = $stack.Pop()
        $fileErrors += "Line $($unclosed.Line), Col $($unclosed.Col) : Unclosed delimiter '$($unclosed.Char)'"
    }

    return $fileErrors
}

foreach ($f in $allFiles) {
    $checkedCount++
    $relPath = $f.FullName.Substring($TargetDir.Length).TrimStart("\/")
    $errors = Test-FileDelimiters -File $f

    if ($errors.Count -gt 0) {
        Write-Host "[FAIL] $relPath" -ForegroundColor Red
        foreach ($err in $errors) {
            Write-Host "       -> $err" -ForegroundColor Red
            $errorCount++
        }
    } else {
        Write-Host "[PASS] $relPath" -ForegroundColor Green
    }
}

Write-Host "----------------------------------------------------------" -ForegroundColor Cyan
Write-Host "Summary: $checkedCount files audited, $errorCount errors detected." -ForegroundColor $(if ($errorCount -eq 0) { "Green" } else { "Red" })
Write-Host "==========================================================" -ForegroundColor Cyan

if ($errorCount -gt 0) {
    exit 1
} else {
    exit 0
}
