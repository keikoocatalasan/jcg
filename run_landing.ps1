$host.ui.RawUI.WindowTitle = "JCG Landing Page Server (Port 8080)"
Set-Location "C:\Users\john\projects\jcg\landing_page"
python -m http.server 8080
