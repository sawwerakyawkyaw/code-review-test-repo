# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository contains PowerShell scripts for interacting with Azure DevOps API to fetch and analyze pull request data. The primary script retrieves PR changes, file diffs, and review comments for code review automation.

## Running Scripts

### Main PR Changes Script

```powershell
# Fetch PR data for a specific PR ID
.\getPrChanges.ps1 -prId <PR_NUMBER>
```

This script:

- Requires a mandatory `-prId` parameter
- Connects to Azure DevOps using PAT authentication (configured in the script)
- Fetches PR details, file diffs, and blob content (old/new versions)
- Exports results to `pr_review_data.json`

### Configuration

The script uses hardcoded Azure DevOps configuration (getPrChanges.ps1:2-5):

- Organization: `sawwerakyawkyaw`
- Project: `Internship`
- Repository ID: `code-review-test-repo`
- PAT token is embedded in the script

**Security Note**: The PAT token is currently hardcoded in getPrChanges.ps1:5. When modifying scripts, avoid committing credentials.

## Architecture

### Azure DevOps API Integration

The script follows this workflow:

1. **Authentication** (getPrChanges.ps1:8-12): Creates Basic auth header from PAT
2. **PR Retrieval** (getPrChanges.ps1:24-25): Fetches single PR using Pull Requests API
3. **Diff Analysis** (getPrChanges.ps1:46): Retrieves commit diffs between base and target
4. **Blob Content Fetching** (getPrChanges.ps1:79-120): Downloads old/new file versions using blob objectIds
5. **JSON Export** (getPrChanges.ps1:149-151): Outputs structured data for downstream processing

### Data Structures

**pr_review_data.json**: Contains file change details for a PR

- `pullRequestId`, `pullRequestTitle`
- `path`, `changeType` (add/edit/delete/rename)
- `oldContent`, `newContent` (full file contents as strings)

**pr_review_comments.json**: Azure DevOps comment thread format

- `comments[]` with `content` and `commentType`
- `threadContext` with file path and line position (`rightFileStart`, `rightFileEnd`)

## Key Implementation Details

- The script filters for blob changes only (excludes tree/commit objects) at getPrChanges.ps1:52-54
- Blob content handling (getPrChanges.ps1:83-91, 106-114) checks if response is string or object with content property
- Uses Azure DevOps API version 7.1 throughout
- Processes changes sequentially within each PR

## Your role

You are an experienced software engineer. Your task is to review code changes and provide constructive feedback in a structured JSON format compatible with Azure DevOps Pull Request comment threads.

Please review the code changes in `pr_review_data.json`. Each file data object represent a change in the pull request with the following keys:

```
{
  "pullRequestId": number,
  "path": string,
  "changeType": string,
  "newContent": string | null,
  "oldContent": string | null
}
```

Consider the following aspects:

1. Code quality and adherence to best practices
2. Potential bugs or edge cases
3. Performance optimizations
4. Readability and maintainability
5. Any security concerns

For each review comment you want to make, you must provide:

1. The specific file path being reviewed
2. The exact line number(s) where the comment applies
3. A clear, actionable comment with context and reasoning

OUTPUT FORMAT:
Return a JSON array in `pr_review_data.json` where each element represents one review comment thread. Each object must follow this exact structure:

````{
  "comments": [
    {
      "parentCommentId": 0,
      "content": "<Your detailed review comment here>",
      "commentType": 1
    }
  ],
  "threadContext": {
    "filePath": "<relative file path from repository root, e.g., /src/utils/helper.js>",
    "rightFileStart": {
      "line": <starting line number>,
      "offset": 1
    },
    "rightFileEnd": {
      "line": <ending line number>,
      "offset": 1
    }
  }
}```

RULES:
- Create one highlevel overview of the pull request comment without any thread context
- Always set "parentCommentId" to 0 (top-level comment)
- Always set "commentType" to 1 (standard comment)
- "filePath" must start with "/" and match the exact path from the repository
````
