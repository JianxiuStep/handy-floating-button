' Launches handy_button.ps1 with no console window.
' The script path is resolved relative to this .vbs file, so the folder can be moved anywhere.
Set Ws = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
ps1 = fso.BuildPath(fso.GetParentFolderName(WScript.ScriptFullName), "handy_button.ps1")
Ws.Run """C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"" -NoProfile -ExecutionPolicy Bypass -File """ & ps1 & """", 7, False
