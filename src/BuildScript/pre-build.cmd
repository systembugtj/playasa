@echo off

chdir /D %~dp0

IF NOT EXIST "..\Source\svplib\shooterclient.key" copy ".\shooterclient_dummy.key" "..\Source\svplib\shooterclient.key"


IF NOT EXIST "..\include\shooterclient.key" copy ".\shooterclient_dummy.key" "..\include\shooterclient.key"


IF NOT EXIST "..\include\shooterapi.key" copy ".\shooterapi_dummy.key" "..\include\shooterapi.key"