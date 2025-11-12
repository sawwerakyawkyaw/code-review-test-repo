# Configuration
$organization = "sawwerakyawkyaw"
$project = "Internship"
$repositoryId = "code-review-test-repo"
$pat = "5v6Ea52fS2x1agLCz2n31Dv2uHygaHn8V4RAurd001qe7PO8ihhEJQQJ99BKACAAAAAAAAAAAAASAZDO30Q8"

# Create auth header
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat"))
$headers = @{
  Authorization  = "Basic $base64AuthInfo"
  "Content-Type" = "application/json"
}

# Base URL
$baseUrl = "https://dev.azure.com/$organization/$project/_apis"

# Step 1: Retrieve all active PRs
Write-Host "Step 1: Fetching all active PRs..." -ForegroundColor Cyan
param(
  [Parameter(Mandatory=$true)]
  [int]$prId
)

$pullRequestsUrl = "$baseUrl/git/repositories/$repositoryId/pullrequests/$prId`?api-version=7.1"
$pullRequestsResponse = Invoke-RestMethod -Uri $pullRequestsUrl -Headers $headers -Method Get

$activePRs = $pullRequestsResponse.value
Write-Host "Found $($activePRs.Count) active PR(s)" -ForegroundColor Green

# Array to hold all review data
$allReviewData = @()

# Step 2: Process each PR
foreach ($pr in $activePRs) {
  $prId = $pr.pullRequestId
  $prTitle = $pr.title
  $baseCommit = $pr.lastMergeSourceCommit.commitId
  $targetCommit = $pr.lastMergeTargetCommit.commitId

  Write-Host "`n=== Processing PR #${prId}: $prTitle ===" -ForegroundColor Magenta
  Write-Host "Base Commit: $baseCommit" -ForegroundColor Gray
  Write-Host "Target Commit: $targetCommit" -ForegroundColor Gray

  # Step 2a: Get diffs for this PR
  Write-Host "Step 2: Fetching diffs for PR #${prId}..." -ForegroundColor Cyan
  $diffsUrl = "$baseUrl/git/repositories/$repositoryId/diffs/commits?baseVersionType=commit&baseVersion=$targetCommit&targetVersionType=commit&targetVersion=$baseCommit&api-version=7.1"

  try {
    $diffsResponse = Invoke-RestMethod -Uri $diffsUrl -Headers $headers -Method Get

    # Filter for blob changes only
    $blobChanges = $diffsResponse.changes | Where-Object {
      $_.item.gitObjectType -eq "blob"
    }

    Write-Host "Found $($blobChanges.Count) file change(s) in PR #${prId}" -ForegroundColor Green

    # Step 3: Process each change
    foreach ($change in $blobChanges) {
      $path = $change.item.path
      $changeType = $change.changeType
      $objectId = $change.item.objectId
      $originalObjectId = $change.item.originalObjectId

      Write-Host "`n  Processing: $path ($changeType)" -ForegroundColor Yellow

      $fileData = @{
        pullRequestId    = $prId
        pullRequestTitle = $prTitle
        path             = $path
        changeType       = $changeType
        oldContent       = $null
        newContent       = $null
      }

      # Get old content (for edit/delete/rename)
      if ($originalObjectId) {
        Write-Host "    Fetching old version (objectId: $originalObjectId)..." -ForegroundColor Gray
        $blobUrl = "$baseUrl/git/repositories/$repositoryId/blobs/$originalObjectId`?api-version=7.1"
        try {
          $blobResponse = Invoke-RestMethod -Uri $blobUrl -Headers $headers -Method Get
          # The response is typically a plain string, not base64-encoded
          if ($blobResponse -is [string]) {
            Write-Host "response is string" -ForegroundColor DarkGray
            $fileData.oldContent = $blobResponse
          }
          else {
            # If it's an object with a content property, try to decode it
            Write-Host "response is an object" -ForegroundColor DarkGray
            $fileData.oldContent = $blobResponse.content
          }
          Write-Host "    Successfully fetched old content: $($fileData.oldContent.Length) chars" -ForegroundColor DarkGray
        }
        catch {
          Write-Host "    Error fetching old content: $_" -ForegroundColor Red
        }
      }

      # Get new content (for add/edit/rename)
      if ($objectId) {
        Write-Host "    Fetching new version (objectId: $objectId)..." -ForegroundColor Gray
        $blobUrl = "$baseUrl/git/repositories/$repositoryId/blobs/$objectId`?api-version=7.1"
        try {
          $blobResponse = Invoke-RestMethod -Uri $blobUrl -Headers $headers -Method Get
          # The response is typically a plain string, not base64-encoded
          if ($blobResponse -is [string]) {
            Write-Host "response is string" -ForegroundColor DarkGray
            $fileData.newContent = $blobResponse
          }
          else {
            # If it's an object with a content property, try to decode it
            Write-Host "    response is an object" -ForegroundColor DarkGray
            $fileData.newContent = $blobResponse.content
          }
          Write-Host "    Successfully fetched new content: $($fileData.newContent.Length) chars" -ForegroundColor DarkGray
        }
        catch {
          Write-Host "    Error fetching new content: $_" -ForegroundColor Red
        }
      }

      $allReviewData += $fileData
    }
  }
  catch {
    Write-Host "Error fetching diffs for PR #${prId} : $_" -ForegroundColor Red
  }
}

# Step 4: Display summary
Write-Host "`n`n=== REVIEW SUMMARY ===" -ForegroundColor Cyan
Write-Host "Total PRs processed: $($activePRs.Count)" -ForegroundColor Green
Write-Host "Total file changes: $($allReviewData.Count)" -ForegroundColor Green

foreach ($file in $allReviewData) {
  Write-Host "`nPR #$($file.pullRequestId): $($file.pullRequestTitle)" -ForegroundColor Magenta
  Write-Host "  File: $($file.path)" -ForegroundColor Green
  Write-Host "  Change Type: $($file.changeType)" -ForegroundColor Yellow

  if ($file.newContent) {
    Write-Host "  New Content Length: $($file.newContent.Length) characters"
  }
  if ($file.oldContent) {
    Write-Host "  Old Content Length: $($file.oldContent.Length) characters"
  }
}

# Step 5: Export to JSON for LLM processing
$outputPath = "pr_review_data.json"
$allReviewData | ConvertTo-Json -Depth 10 | Out-File $outputPath
Write-Host "`n`nReview data exported to: $outputPath" -ForegroundColor Green
