@echo off
REM ========================================
REM RISC-V 汇编编译脚本
REM 使用 RARS 编译器将汇编代码转换为机器码
REM ========================================

echo ========================================
echo RISC-V Assembly Compiler
echo ========================================
echo.

REM 检查 Java 环境
echo [1/4] Checking Java environment...
java -version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Java not found! Activating conda java environment...
    call conda activate java
    if errorlevel 1 (
        echo ERROR: Failed to activate conda java environment!
        echo Please install Java or fix conda environment.
        pause
        exit /b 1
    )
)
echo Java environment OK.
echo.

REM 检查 RARS
echo [2/4] Checking RARS assembler...
if not exist "rars1_6.jar" (
    echo ERROR: rars1_6.jar not found in current directory!
    echo Please download RARS from https://github.com/TheThirdOne/rars
    pause
    exit /b 1
)
echo RARS assembler found.
echo.

REM 编译汇编代码
echo [3/4] Compiling assembly code...
echo Source: 交互式冒泡排序_interactive.asm
echo Output: insData_new.txt
echo.

java -jar rars1_6.jar a dump .text HexText insData_new.txt 交互式冒泡排序_interactive.asm

if errorlevel 1 (
    echo.
    echo ========================================
    echo ERROR: Assembly compilation failed!
    echo ========================================
    pause
    exit /b 1
)

echo.
echo ========================================
echo [SUCCESS] Compilation completed!
echo ========================================
echo.

REM 显示输出文件信息
echo [4/4] Output file information:
if exist "insData_new.txt" (
    for %%I in (insData_new.txt) do echo   File: %%~nxI
    for %%I in (insData_new.txt) do echo   Size: %%~zI bytes
    for %%I in (insData_new.txt) do echo   Date: %%~tI
    echo.
    echo Next steps:
    echo   1. Copy insData_new.txt to Vivado project:
    echo      copy insData_new.txt boardtest.srcs\sources_1\new\insData.txt
    echo   2. Restart simulation in Vivado
) else (
    echo ERROR: Output file not generated!
)

echo.
echo ========================================
pause
