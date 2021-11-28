@echo off 
powershell -executionpolicy bypass -windowstyle minimized -command "& { . .\scripts.ps1; GenerateBIOS-Form }"
exit