$titles=get-content .\cheechraw.txt

$template = @"
\poemchapter{%%TITLE%%}

\begin{poemblock}
VERSE\\
VERSE\\
VERSE
\end{poemblock}
"@

write-output "\input{poems/BalladsOfACheechako/to_the_man_of_the_high_north}" >.\cheechako.tex
write-output "\newpage" >>.\cheechako.tex

foreach($t in $titles){
    $tName = "$($t.Replace(" ","_"))"
    $starter = $template.Replace("%%TITLE%%",$t)

    Write-Output "\input{poems/BalladsOfACheechako/$tName}" >>.\cheechako.tex
    write-output "\newpage" >>.\cheechako.tex

    Write-Output $starter >"./BalladsOfACheechako/$tname.tex"
}

