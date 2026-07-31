$host.ui.RawUI.WindowTitle = "Android Emulator"
Set-Location "C:\Users\john\projects\jcg"
& "C:\Users\john\AppData\Local\Android\sdk\emulator\emulator.exe" -avd jcg_fitness_pixel_api36 -no-snapshot-load -no-snapshot-save
