@echo off
REM Windows batch script to test REST API connection
REM Usage: test_client.bat [host] [port]

set HOST=localhost
set PORT=8080

if not "%1"=="" set HOST=%1
if not "%2"=="" set PORT=%2

echo Testing Trade Signal API Connection...
echo Server: %HOST%:%PORT%
echo.

curl -X POST http://%HOST%:%PORT%/ ^
  -H "Content-Type: application/json" ^
  -d "{\"symbol\":\"EURUSD\",\"direction\":\"BUY\",\"entryTime\":\"2025-11-15 10:00:00\",\"tp\":30,\"sl\":10,\"lot\":0.10,\"isDaily\":false,\"accountName\":\"Test EA\",\"brand\":\"TEST BRAND\"}"

echo.
echo Test complete!

