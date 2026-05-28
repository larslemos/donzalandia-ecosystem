# Consultations - F-015

## Overview
- **Status:** GA
- **Primary Users:** professional, lead_specialist
- **Dependencies:** F-004 (Student Registration)
- **Related Endpoints:** `/api/consultations/*`

## User Stories
- As a professional, I want to log clinical consultations per child so that every interaction is recorded.
- As a professional, I want to link consultations to my professional account so that there is an audit trail.
- As a specialist, I want to view a full student history including triage, anamnesis, and past consultations so that I have complete context during my sessions.

## UI/UX Flow
```mermaid
graph LR
    A[Start: Child Profile] --> B[Navigate to Consultations]
    B --> C[Click 'New Consultation']
    C --> D[Add Date & Clinical Notes]
    D --> E[Save Consultation]
    E --> F[Consultation Added to History Timeline]
```
