# AI Triage Reports - F-008

## Overview
- **Status:** Beta
- **Primary Users:** professional, lead_specialist
- **Dependencies:** F-006 (Screening / Triagem)
- **Related Endpoints:** `/api/screening/triage-ai-report/child/{id}`

## User Stories
- As a specialist, I want to generate an AI narrative report for a child's triage data so that I can quickly understand the clinical picture.
- As a user, I want the AI to detect cross-section patterns (e.g., mobility + autonomy) so that deeper clinical insights are surfaced automatically.
- As a user, I want report generation to happen asynchronously so that my UI is not blocked.

## UI/UX Flow
```mermaid
sequenceDiagram
    participant Prof as Professional
    participant API as Laravel API
    participant Queue as Queue Worker
    participant OpenAI as OpenAI API

    Prof->>API: Request Report Generation
    API->>Queue: Dispatch Job
    API-->>Prof: 202 Accepted (Pending)
    Queue->>OpenAI: Send WGSS Data + Prompt
    OpenAI-->>Queue: GPT Narrative Response
    Queue->>API: Save Report Data
    Prof->>API: Poll Status
    API-->>Prof: 200 Completed
```
