@echo off
setlocal

where gnuplot >nul 2>&1
if errorlevel 1 (
  echo Error: gnuplot is required for figure generation.
  exit /b 1
)

for /f "usebackq delims=" %%V in (`gnuplot --version 2^>nul`) do set "GNUPLOT_VERSION=%%V"
if not defined GNUPLOT_VERSION (
  echo Error: gnuplot was found but its version could not be read.
  exit /b 1
)

echo Figure-generation requirements
echo gnuplot: %GNUPLOT_VERSION%
echo Figure-generation requirements passed.
endlocal
