@echo off
setlocal

if NOT exist "%~dp0dynflare.conf" echo dynflare.conf not found! & call :message "ERROR: dynflare.conf wasn't found." & goto :stop
for /F "tokens=* eol=#" %%g in (%~dp0dynflare.conf) do (call set %%g)

:startloop
echo:
echo:
setlocal
call :obtainip _currentipv4 4
call :obtainip _currentipv6 6
(for /L %%g in (1,1,2) do set /P "_cacheipv4=") < "%~dp0dynflare.cache"
(for /L %%g in (1,1,3) do set /P "_cacheipv6=") < "%~dp0dynflare.cache"
set _changed4=1
set _changed6=1
if "%_cacheipv4%"=="%_currentipv4%" set "_same4= (same)" & set "_changed4=0"
if "%_cacheipv6%"=="%_currentipv6%" set "_same6= (same)" & set "_changed6=0"
echo IPv4: %_currentipv4%%_same4%
echo IPv6: %_currentipv6%%_same6%
echo %time% %date% -- Dynflare> "%~dp0dynflare.cache"
echo %_currentipv4%>> "%~dp0dynflare.cache"
echo %_currentipv6%>> "%~dp0dynflare.cache"

if %_changed4%==1 (
if %_ipv4valid%==True (
echo Updating IPv4...
call :updaterecord %_token% "%_zonename%" A "%_recordname4%" "%_currentipv4%"
) else (
echo IPv4 skipped)
) else (
echo IPv4 skipped)

if %_changed6%==1 (
if %_ipv6valid%==True (
echo Updating IPv6...
call :updaterecord %_token% "%_zonename%" AAAA "%_recordname6%" "%_currentipv6%"
) else (
echo IPv6 skipped)
) else (
echo IPv6 skipped)

:endloop
endlocal
echo Done
ping -n 601 127.0.0.1>nul
goto :startloop
:stop
endlocal
goto :eof

::-----------------
::    FUNCTIONS
::-----------------

:obtainip
setlocal
set _var=%1
set _ipversion=%2
for /F "tokens=*" %%g in ('curl -%_ipversion% -sS %_ipsource%') do (set _currentip=%%g)
call :checkip _ipvalid "%_currentip%"
if False==%_ipvalid% call :message "ERROR: IPv%_ipversion% was not retrieved." & set _currentip=error
endlocal & set %_var%=%_currentip%
goto :eof

:updaterecord
setlocal
set _token=%1
set _zone_name=%~2
set _record_type=%3
set _record_name=%~4
set _value=%~5
for /F "tokens=*" %%g in ('curl -sS -X GET "https://api.cloudflare.com/client/v4/zones?name=%_zone_name%" -H "Authorization: Bearer %_token%" -H "Content-Type: application/json" ^| jq -r .result[0].id') do (set _zone_id=%%g)
for /F "tokens=*" %%g in ('curl -sS -X GET "https://api.cloudflare.com/client/v4/zones/%_zone_id%/dns_records?type=%_record_type%&name=%_record_name%" -H "Authorization: Bearer %_token%" -H "Content-Type: application/json" ^| jq -r .result[0].id') do (set _record_id=%%g)
curl -sS -X PATCH "https://api.cloudflare.com/client/v4/zones/%_zone_id%/dns_records/%_record_id%" -H "Authorization: Bearer %_token%" -H "Content-Type: application/json" --data {\"content\":\"%_value%\"} > nul
endlocal
goto :eof

:checkip
setlocal
set _var=%1
set _ip=%~2
set _prefixlenght=%_ip:*/=%
call set _ip=%%_ip:/%_prefixlenght%=%%
for /F "usebackq tokens=*" %%g in (`powershell -c "$ipaddrobj = [ipaddress]::Any ; if (!([ipaddress]::TryParse('%_ip%', [ref]$ipaddrobj))){if (!([ipaddress]::TryParse('%_ip%'.split(':')[0], [ref]$ipaddrobj))){return $false}} ; return $true"`) do (set _ipvalid=%%g)
endlocal & set %_var%=%_ipvalid%
goto :eof

:newline
set %1=^


goto :eof

:message
setlocal
set "_message=%~1"
call :newline _NL
setlocal EnableDelayedExpansion
msg * /time:2147483647 "			DYNFLARE			!_NL!!_NL!!_NL!!_message!"
endlocal
endlocal
goto :eof