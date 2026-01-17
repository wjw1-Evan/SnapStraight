@if "%DEBUG%"=="" @echo off
@rem Gradle startup script for Windows

setlocal

set DEFAULT_JVM_OPTS=-Xmx512m -Xms256m

set DIR=%~dp0
set APP_HOME=%DIR%

if not "%JAVA_HOME%"=="" goto findJavaFromJavaHome

set JAVACMD=java.exe
if exist "%SystemRoot%\System32\java.exe" set JAVACMD=%SystemRoot%\System32\java.exe
if exist "%SystemRoot%\java.exe" set JAVACMD=%SystemRoot%\java.exe

:findJavaFromJavaHome
if exist "%JAVA_HOME%\bin\java.exe" set JAVACMD="%JAVA_HOME%\bin\java.exe"

if not exist "%APP_HOME%\gradle\wrapper\gradle-wrapper.jar" (
    echo ERROR: gradle-wrapper.jar not found. Please run 'gradle wrapper' to generate wrapper files.
    exit /b 1
)

"%JAVACMD%" %DEFAULT_JVM_OPTS% -classpath "%APP_HOME%\gradle\wrapper\gradle-wrapper.jar" org.gradle.wrapper.GradleWrapperMain %*
