@echo off
setlocal

set "ROOT=%~dp0.."
set "FIRMWARE=%~dp0"
set "BUILD=%FIRMWARE%build\panel_code_scan"
set "SDCC=%ROOT%\compilers\sdcc\bin\sdcc.exe"
set "PACKIHX=%ROOT%\compilers\sdcc\bin\packihx.exe"
set "SOURCE=%FIRMWARE%tests\panel_code_scan.c"
set "IHX=%BUILD%\panel_code_scan.ihx"
set "OUT=%FIRMWARE%build\PANEL_CODE_SCAN_00_7F.HEX"

if not exist "%SDCC%" (
  echo SDCC not found: %SDCC%
  exit /b 1
)
if not exist "%PACKIHX%" (
  echo packihx not found: %PACKIHX%
  exit /b 1
)
if not exist "%SOURCE%" (
  echo Source not found: %SOURCE%
  exit /b 1
)

if not exist "%BUILD%" mkdir "%BUILD%"
if exist "%IHX%" del "%IHX%"

pushd "%ROOT%"
"%SDCC%" ^
  -mmcs51 ^
  --model-small ^
  --code-loc 0x0000 ^
  --xram-loc 0x0000 ^
  --iram-size 128 ^
  --out-fmt-ihx ^
  --std-sdcc11 ^
  --opt-code-size ^
  -I. ^
  -o "%IHX%" ^
  "%SOURCE%"

if errorlevel 1 (
  set "ERR=%errorlevel%"
  popd
  exit /b %ERR%
)
if not exist "%IHX%" (
  echo SDCC did not create: %IHX%
  popd
  exit /b 1
)

"%PACKIHX%" "%IHX%" > "%OUT%"
if errorlevel 1 (
  set "ERR=%errorlevel%"
  popd
  exit /b %ERR%
)
popd

echo Built: %OUT%
endlocal
