$host.ui.RawUI.WindowTitle = "JCG FastAPI Backend"
Set-Location "C:\Users\john\projects\jcg\backend"
& "C:\Users\john\projects\jcg\backend\.venv\Scripts\python.exe" -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
