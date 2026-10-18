rm .\kjb.*

.\Convert-KJBRaw.ps1 > kjb.tex
xelatex .\kjb.tex > output.log
xelatex .\kjb.tex > output.log

