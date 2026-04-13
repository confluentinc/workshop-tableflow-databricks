@echo off
setlocal

set IMAGE_NAME=workshop-datagen:latest
set DATA_DIR=%~dp0..\data

:: Check for Docker
where docker >nul 2>&1
if %errorlevel%==0 (
    set RUNTIME=docker
    goto :found
)

:: Check for Podman
where podman >nul 2>&1
if %errorlevel%==0 (
    set RUNTIME=podman
    goto :found
)

echo Error: Neither docker nor podman found. Install one and retry.
exit /b 1

:found
echo Using runtime: %RUNTIME%
echo Data directory: %DATA_DIR%

:: Build image if it doesn't exist
%RUNTIME% image inspect %IMAGE_NAME% >nul 2>&1
if %errorlevel% neq 0 (
    echo Building image %IMAGE_NAME%...
    %RUNTIME% build -t %IMAGE_NAME% %~dp0
)

set CONFIG_FILE=%1
if "%CONFIG_FILE%"=="" set CONFIG_FILE=/home/data/java-datagen-configuration.json

set ENV_FILE_FLAG=
if exist "%DATA_DIR%\.datagen.env" set ENV_FILE_FLAG=--env-file %DATA_DIR%\.datagen.env

%RUNTIME% run --rm ^
    -v "%DATA_DIR%:/home/data" ^
    -p 9400:9400 ^
    %ENV_FILE_FLAG% ^
    %IMAGE_NAME% ^
    --config %CONFIG_FILE%
