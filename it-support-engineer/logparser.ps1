# Extract the gzip file
$file = "interview_data_set.gz"
$gzipStream = New-Object System.IO.Compression.GzipStream(
    (New-Object System.IO.FileStream($file, [System.IO.FileMode]::Open)),
    [System.IO.Compression.CompressionMode]::Decompress
)

# Read the extracted content
$reader = New-Object System.IO.StreamReader($gzipStream)
$lines = $reader.ReadToEnd().Split("`n")

# Close the reader and gzip stream
$reader.Close()
$gzipStream.Close()

# File entry and data governance
$lines = $lines | Where-Object { $_ -like "May*" } | ForEach-Object { $_.Trim() }

# Associated log consolidation
$formatted_lines = New-Object System.Collections.Generic.List[System.String]
for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($line.Split()[3] -eq "---" -and $i -gt 0) {
        $formatted_lines[-1] += " " + ($line.Split()[4..($line.Length-1)] -join " ")
    } else {
        $formatted_lines.Add($line)
    }
}

# Parse the number of logs and statistics
$out = @{}
$out2 = @{}

foreach ($line in $formatted_lines) {
    # Time hour
    $timeField = [int]$line.Split()[2].Substring(0, 2)
    $timeWindow = "{0:00}:00-{1:00}:00" -f $timeField, ($timeField + 1)
    # DeviceName
    $deviceName = $line.Split()[3]
    # Reset line
    $line = ($line.Split()[4..($line.Length-1)] -join " ")
    # idName and description
    $sep = $line.IndexOf(": ")
    $idName = $line.Substring(0, $sep)
    # processName
    $processName = $idName -replace '\s+\(.*\)' -replace '\[.*\]' -replace ':.*'
    # processId
    $processId = if ($idName -and $idName -match '\[([0-9]+)\]') { $Matches[1] }
    # Description and formatting
    $description = $line.Substring($sep+2).Replace('"', '#')
    # Count by key
    $k = "{0}@{1}@{2}" -f $timeWindow, $deviceName, $processName
    if (-not $out.ContainsKey($k)) {
        $out[$k] = 0
    }
    if (-not $out2.ContainsKey($k)) {
        $out2[$k] = @{}
    }
    if (-not $out2[$k].ContainsKey("p")) {
        $out2[$k]["p"] = @{}
    }
    if (-not $out2[$k].ContainsKey("d")) {
        $out2[$k]["d"] = @{}
    }
    $out[$k]++
    $out2[$k]["p"][$processId]++
    $out2[$k]["d"][$description]++
}

# Final result
$out_list = New-Object System.Collections.Generic.List[System.Object]
foreach ($k in $out.Keys) {
    $timeWindow, $deviceName, $processName = $k.Split("@")
    $ids = if ($out2[$k]["p"].Keys.Count -gt 0) { $($out2[$k]["p"].Keys -join " ") }
    $desc = if ($out2[$k]["d"].Keys.Count -gt 0) { $($out2[$k]["d"].Keys -join " --->>> ") }
    $out_list.Add(@{
        "timeWindow" = $timeWindow
        "numberOfOccurrence" = "$($out[$k])"
        "deviceName" = $deviceName
        "processName" = $processName
        "processId" = $ids
        "description" = $desc
    })
}

# Output json file
$out_file = "psout.json"
$out_list | ConvertTo-Json | Out-File -FilePath $out_file

# Post Json to API server
$uri = "https://foo.com/bar"
$headers = @{
    "Content-Type" = "application/json"
}
$json = Get-Content -Raw -Path $out_file
Invoke-RestMethod -Uri $uri -Headers $headers -Method Post -Body $json
