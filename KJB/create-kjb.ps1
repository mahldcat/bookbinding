rm .\kjb.*

.\Convert-KJBRaw.ps1 > kjb.tex
xelatex .\kjb.tex
xelatex .\kjb.tex

