# Internationalisation (i18n) - F-021

## Overview
- **Status:** GA
- **Primary Users:** all roles
- **Dependencies:** None
- **Related Endpoints:** N/A (Client-side / API responses)

## User Stories
- As a user, I want the system to be available in Portuguese (PT) primarily, so that local users can understand the interface.
- As a user, I want the system to be available in English (EN) secondarily, so that international stakeholders can use it.
- As a user, I want the system to automatically detect my language via the browser so that my experience is seamless.

## UI/UX Flow
```mermaid
graph LR
    A[Start: User accesses Web/App] --> B[Detect Browser/Device Language]
    B --> C{Is Language Supported?}
    C -->|Yes| D[Load Requested Language Pack]
    C -->|No| E[Load Default Language: PT]
    D --> F[Render Interface]
    E --> F
    F --> G[User can manually switch language in Settings]
```
