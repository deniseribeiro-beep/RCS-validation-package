@echo off
setlocal EnableExtensions

set "SCOPE=%RCS_RUN_SCOPE%"
if not defined SCOPE set "SCOPE=local"

if /I not "%SCOPE%"=="local" if /I not "%SCOPE%"=="smoke" if /I not "%SCOPE%"=="publication" (
  echo Error: RCS_RUN_SCOPE must be local, smoke, or publication.
  exit /b 1
)

if /I "%SCOPE%"=="publication" if /I not "%RCS_ALLOW_PUBLICATION_WRITE%"=="TRUE" (
  echo Error: publication output is protected. Set RCS_ALLOW_PUBLICATION_WRITE=TRUE only for the deliberate final publication run.
  exit /b 1
)

if defined RCS_OUTPUT_ROOT (
  set "ROOT=%RCS_OUTPUT_ROOT%"
) else if /I "%SCOPE%"=="local" (
  set "ROOT=outputs\local"
) else if /I "%SCOPE%"=="smoke" (
  set "ROOT=outputs\smoke"
) else (
  set "ROOT=results\publication"
)

for %%I in ("%ROOT%") do set "RESOLVED_ROOT=%%~fI"
for %%I in ("%CD%\results\publication") do set "PROTECTED_ROOT=%%~fI"

powershell -NoProfile -ExecutionPolicy Bypass -Command "$root=[IO.Path]::GetFullPath($env:RESOLVED_ROOT).TrimEnd([char[]]@(92,47)); $protected=[IO.Path]::GetFullPath($env:PROTECTED_ROOT).TrimEnd([char[]]@(92,47)); if ($root.Equals($protected,[StringComparison]::OrdinalIgnoreCase) -or $root.StartsWith($protected + '\',[StringComparison]::OrdinalIgnoreCase)) { exit 42 } else { exit 0 }"
set "GUARD_STATUS=%ERRORLEVEL%"
if "%GUARD_STATUS%"=="42" (
  if /I not "%RCS_ALLOW_PUBLICATION_WRITE%"=="TRUE" (
    echo Error: publication output is protected. RCS_OUTPUT_ROOT resolves inside results\publication; set RCS_ALLOW_PUBLICATION_WRITE=TRUE only for the deliberate final publication run.
    exit /b 1
  )
) else if not "%GUARD_STATUS%"=="0" (
  echo Error: unable to validate the resolved figure output path.
  exit /b 1
)

call scripts\check_figure_requirements.cmd
if errorlevel 1 exit /b 1

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
