param(
    #$kjbRaw="./KJB_NTest_Short.json"
    $kjbRaw="./KJB_NTest.json"
)

$kjb = Get-Content $kjbRaw| ConvertFrom-Json 
$byLine=$kjb.BookUnFormatted.Split([System.Environment]::NewLine)
$chapters= $kjb.Chapters

$chapter=""
$verse=""
$passage=""

$regexSplit = '(?=\b\d{1,3}:\d{1,3}\b)'
$regexLine = '^(?<chapter>\d+):(?<verse>\d+)\s+(?<text>.+)'


Write-Output "\documentclass[twoside]{memoir}"
Write-Output "\input{imports/kjb_layout}"
Write-Output "\begin{document}"

Write-Output "\input{imports/kjb_title}"

for($line= 0; $line -lt $byLine.Count; $line++){
    $textLine = $byLine[$line].Trim()

    if($chapters -contains $textLine){
        if (-not [string]::IsNullOrWhiteSpace($chapter) -and 
            -not [string]::IsNullOrWhiteSpace($verse) -and 
            -not [string]::IsNullOrWhiteSpace($passage)) {
                write-output "\noindent\verseref{$chapter}{$verse} $passage\par"
                #write-output "\verseref{$chapter}{$verse}$passage\\"
        }
                
        $chapter=""
        $verse=""
        $passage=""

        write-output "\chapter*{\adjustbox{max width=\textwidth}{$textLine}}"
        write-output "\addcontentsline{toc}{chapter}{$textLine}"
        write-output "\markboth{$textLine}{$textLine}"
        Write-Output ""

    }
    else{
        if(-NOT [System.String]::IsNullOrEmpty($textLine)){
            $split = [regex]::Split($textLine,$regexSplit)
            
            foreach($splitLine in $split){
                $matchLine= [regex]::Match($splitLine, $regexLine)
                if($matchLine.Success){
                    if (-not [string]::IsNullOrWhiteSpace($chapter) -and 
                        -not [string]::IsNullOrWhiteSpace($verse) -and 
                        -not [string]::IsNullOrWhiteSpace($passage)) {
                            write-output "\noindent\verseref{$chapter}{$verse} $passage\par"
                    }
                        
                    $chapterVal= $matchLine.Groups["chapter"].Value

                    if($chapter -ne $chapterVal){
                        $chapter= $chapterVal
                        Write-Output ""
                        write-output "\section*{Chapter $chapter}"
                        write-output "\addcontentsline{toc}{section}{Chapter $chapter}"
                        #write-output "\noindent"
                        Write-Output ""
                    }

                    $verse= $matchLine.Groups["verse"].Value
                    $passage= $matchLine.Groups["text"].Value
                }else{
                    $passage= "$passage $($splitLine.Trim())"
                }
            }
            
        }

    }
}

Write-Output ""
Write-Output "\end{document}"
