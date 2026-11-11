param([string]$BaseUrl = $env:BASE_URL)
$ErrorActionPreference = 'Stop'
if (-not $BaseUrl -or -not $env:API_TOKEN) { throw 'BASE_URL and API_TOKEN are required.' }
if ($env:ALLOW_WRITE -ne '1') { throw 'ALLOW_WRITE=1 is required; record will be retained.' }
$headers = @{ 'x-api-token' = $env:API_TOKEN }
$url = $BaseUrl.TrimEnd('/') + '/api/v1/Customer'
$runId = 'isactive-' + [Guid]::NewGuid().ToString('N')
function Invoke-Customer($Method, $Uri, $Data) {
    if ($null -eq $Data) { return Invoke-RestMethod $Uri -Headers $headers -Method $Method }
    return Invoke-RestMethod $Uri -Headers $headers -Method $Method -ContentType 'application/json' -Body ($Data | ConvertTo-Json -Compress)
}
$created = Invoke-Customer 'POST' $url @{ customer_name = ('k6-' + $runId); notes = ('k6-owned:' + $runId); is_active = 1 }
if ($created.status -ne 201 -or -not $created.data[0].customer_id) { throw 'Create fixture failed.' }
$uri = $url + '/' + [Uri]::EscapeDataString($created.data[0].customer_id)
foreach ($value in @(0, 1)) {
    $updated = Invoke-Customer 'PUT' $uri @{ is_active = $value }
    if ($updated.status -ne 200 -or $updated.data[0].is_active -is [bool] -or $updated.data[0].is_active -ne $value) { throw 'PUT must return the existing numeric 0/1 contract.' }
    $read = Invoke-Customer 'GET' $uri $null
    if ($read.status -ne 200 -or [int]$read.data[0].is_active -ne $value) { throw 'Flag was not persisted.' }
    $updated = Invoke-Customer 'PUT' $uri @{ city = ('flag-' + $value) }
    if ($updated.status -ne 200 -or $updated.data[0].is_active -ne $value) { throw 'Omitted flag was changed or update failed.' }
    $read = Invoke-Customer 'GET' $uri $null
    if ([int]$read.data[0].is_active -ne $value -or $read.data[0].city -ne ('flag-' + $value)) { throw 'Partial update readback failed.' }
    Write-Output "PASS is_active=$value and partial update omitting flag; data retained."
}
Write-Output 'PASS native Customer flag regression; no DELETE, restore or cleanup.'
