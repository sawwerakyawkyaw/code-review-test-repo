# Configuration
$organization = "sawwerakyawkyaw"
$project = "Internship"
$repositoryId = "code-review-test-repo"
$pat = "5v6Ea52fS2x1agLCz2n31Dv2uHygaHn8V4RAurd001qe7PO8ihhEJQQJ99BKACAAAAAAAAAAAAASAZDO30Q8"

param(
  [Parameter(Mandatory=$true)]
  [int]$prId
)

# Create auth header
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat"))
$headers = @{
  Authorization  = "Basic $base64AuthInfo"
  "Content-Type" = "application/json"
}

# API endpoint
$threadsUrl = "https://dev.azure.com/$organization/$project/_apis/git/repositories/$repositoryId/pullRequests/$prId/threads?api-version=7.1"

# Read the review comments JSON file
$reviewCommentsFile = "pr_review_comments.json"

if (-not (Test-Path $reviewCommentsFile)) {
  Write-Host "Error: $reviewCommentsFile not found!" -ForegroundColor Red
  exit 1
}

Write-Host "Reading review comments from: $reviewCommentsFile" -ForegroundColor Cyan
$reviewComments = Get-Content $reviewCommentsFile -Raw | ConvertFrom-Json

Write-Host "Found $($reviewComments.Count) comment thread(s) to post" -ForegroundColor Green

# Counter for tracking
$successCount = 0
$failCount = 0

# Post each comment thread
foreach ($thread in $reviewComments) {
  Write-Host "`nPosting comment thread..." -ForegroundColor Yellow

  # Display thread details
  if ($thread.threadContext) {
    Write-Host "  File: $($thread.threadContext.filePath)" -ForegroundColor Gray
    Write-Host "  Lines: $($thread.threadContext.rightFileStart.line)-$($thread.threadContext.rightFileEnd.line)" -ForegroundColor Gray
  }
  else {
    Write-Host "  Type: General PR comment (no specific file context)" -ForegroundColor Gray
  }

  # Convert thread object to JSON
  $threadJson = $thread | ConvertTo-Json -Depth 10 -Compress

  try {
    # Post the comment thread
    $response = Invoke-RestMethod -Uri $threadsUrl -Headers $headers -Method Post -Body $threadJson

    Write-Host "  Success! Thread ID: $($response.id)" -ForegroundColor Green
    $successCount++
  }
  catch {
    Write-Host "  Error posting comment: $_" -ForegroundColor Red
    Write-Host "  Response: $($_.Exception.Response.StatusCode.value__) - $($_.Exception.Response.StatusDescription)" -ForegroundColor Red
    $failCount++
  }
}

# Summary
Write-Host "`n=== POSTING SUMMARY ===" -ForegroundColor Cyan
Write-Host "Total threads: $($reviewComments.Count)" -ForegroundColor White
Write-Host "Successfully posted: $successCount" -ForegroundColor Green
Write-Host "Failed: $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Green" })

if ($successCount -gt 0) {
  Write-Host "`nView comments at: https://dev.azure.com/$organization/$project/_git/$repositoryId/pullrequest/$prId" -ForegroundColor Cyan
}
