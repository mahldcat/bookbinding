param(
    $wfraw=".\whitefang.raw.txt"
)

$rawText = get-content $wfraw

$raw= ""
$nl=[System.Environment]::NewLine
foreach($line in $rawText){
    #Write-Host $line

    if($line -eq ""){
        if($raw -ne ""){
           Write-Output $raw
        }
        Write-Output ""#$nl
        $raw =""                
    }else{
        $raw = $raw + " " + $line
    }
}