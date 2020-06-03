@echo off
set WSID=2118049526
set /p GPath=<path.txt
%GPath%\gmad.exe create -out .\gma.gma -warninvalid -folder "%~dp0
%GPath%\gmpublish.exe update -id %WSID% -addon .\gma.gma
%GPath%\gmpublish.exe update -id %WSID% -icon "%~dp0/icon.jpg"
del .\gma.gma
pause
