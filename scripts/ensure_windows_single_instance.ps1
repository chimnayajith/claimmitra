$mainCpp = 'windows/runner/main.cpp'
if (!(Test-Path $mainCpp)) {
  throw "Windows runner entry point not found: $mainCpp"
}

$content = Get-Content $mainCpp -Raw
if ($content.Contains('ClaimMitra.SingleInstance')) {
  Write-Host 'Windows single-instance guard is already present.'
  exit 0
}

if (!$content.Contains('#include <windows.h>')) {
  $content = "#include <windows.h>`r`n$content"
}

$signature = [regex]::Match($content, 'int APIENTRY wWinMain[\s\S]*?\)\s*\{')
if (!$signature.Success) {
  throw 'Could not locate wWinMain in the generated Windows runner.'
}

$guard = @'

  HANDLE singleInstanceMutex = CreateMutexW(nullptr, TRUE, L"Local\\ClaimMitra.SingleInstance");
  if (singleInstanceMutex == nullptr) {
    return EXIT_FAILURE;
  }
  if (GetLastError() == ERROR_ALREADY_EXISTS) {
    HWND existingWindow = FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", nullptr);
    if (existingWindow != nullptr) {
      ShowWindow(existingWindow, SW_RESTORE);
      SetForegroundWindow(existingWindow);
    }
    CloseHandle(singleInstanceMutex);
    return EXIT_SUCCESS;
  }
'@

$insertAt = $signature.Index + $signature.Length
$content = $content.Insert($insertAt, $guard)
Set-Content $mainCpp $content
Write-Host 'Added Windows single-instance guard.'
