@echo off
setlocal EnableExtensions

where gnuplot >nul 2>&1
if errorlevel 1 (
  echo Error: gnuplot is required and must be available in PATH.
  exit /b 1
)

set "SCOPE=%RCS_RUN_SCOPE%"
if not defined SCOPE set "SCOPE=local"

if defined RCS_OUTPUT_ROOT (
  set "ROOT=%RCS_OUTPUT_ROOT%"
) else if /I "%SCOPE%"=="local" (
  set "ROOT=outputs\local"
) else if /I "%SCOPE%"=="smoke" (
  set "ROOT=outputs\smoke"
) else if /I "%SCOPE%"=="publication" (
  if /I not "%RCS_ALLOW_PUBLICATION_WRITE%"=="TRUE" (
    echo Error: publication output is protected. Set RCS_ALLOW_PUBLICATION_WRITE=TRUE only for the deliberate final publication run.
    exit /b 1
  )
  set "ROOT=results\publication"
) else (
  echo Error: RCS_RUN_SCOPE must be local, smoke, or publication.
  exit /b 1
)

set "TABLES_DIR=%ROOT%\tables"
set "FIGURES_DIR=%ROOT%\figures"

for %%T in (
  "%TABLES_DIR%\Table_Synthetic_Validation_Grade_Distribution.csv"
  "%TABLES_DIR%\Table_Combinatorial_Grade_Distribution.csv"
  "%TABLES_DIR%\Table_Threshold_Transition_Detail.csv"
  "%TABLES_DIR%\Table_Benchmark_Runtime_Summary.csv"
  "%TABLES_DIR%\Table_Benchmark_Within_Language_Speedup_Summary.csv"
  "%TABLES_DIR%\Table_Benchmark_CUDA_Speedup_Summary.csv"
) do (
  if not exist "%%~T" (
    echo Error: missing figure input: %%~T
    exit /b 1
  )
)

if not exist "%FIGURES_DIR%" mkdir "%FIGURES_DIR%"
if exist "%FIGURES_DIR%\Figure_1.pdf" del /q "%FIGURES_DIR%\Figure_1.pdf"
if exist "%FIGURES_DIR%\Figure_1.png" del /q "%FIGURES_DIR%\Figure_1.png"

set "GP_TABLES=%TABLES_DIR:\=/%"
set "GP_FIGURES=%FIGURES_DIR:\=/%"

for %%M in (pdf png) do (
  for %%F in (2 3 4 5 6 7) do (
    echo Generating Figure_%%F.%%M
    gnuplot -e "OUTPUT_MODE='%%M';TABLES_DIR='%GP_TABLES%';OUTPUT_DIR='%GP_FIGURES%'" "scripts/gnuplot/Figure_%%F.gp"
    if errorlevel 1 exit /b 1
  )
)

echo Figures 2 through 7 generated from %TABLES_DIR%.
endlocal
