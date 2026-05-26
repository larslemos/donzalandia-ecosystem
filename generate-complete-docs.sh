#!/bin/bash

# Generate complete project documentation
echo "📚 Generating Complete Documentation"

# Use minimax for natural language documentation
ollama run minimax-m2.5:cloud << 'PROMPT' > documentation/FULL_DOCUMENTATION.md
Generate a complete technical documentation for Donzalandia project including:

1. PROJECT OVERVIEW
   - Purpose of each subproject (Laravel, Next.js, Flutter)
   - Core features (Triagem, Assessment, Cadastro, etc.)
   - Target users and use cases

2. ARCHITECTURE
   - System architecture diagram in ASCII
   - Database schema overview
   - API endpoints by module
   - Authentication flow (JWT/Sanctum)
   - Mobile ↔ API ↔ Web communication

3. SETUP GUIDE
   - Prerequisites (PHP, Flutter, Node)
   - Installation steps for each subproject
   - Environment configuration
   - Database seeding
   - Running development servers

4. CODE STRUCTURE
   - Laravel modules breakdown
   - React component hierarchy
   - Flutter widget tree
   - Key services and providers

5. API REFERENCE
   - All endpoints by module (Triagem, Assessment, Cadastro, DiagnosticoNEE, Plasir)
   - Request/response examples
   - Authentication requirements
   - Error codes

6. TESTING STRATEGY
   - Unit tests structure
   - Feature tests approach
   - Widget tests for Flutter
   - E2E testing plan

7. DEPLOYMENT
   - Production build commands
   - Environment variables
   - CI/CD pipeline suggestions
   - Monitoring and logging

8. CONTRIBUTING GUIDELINES
   - Code style standards
   - Git workflow
   - PR review process
   - Documentation updates

Base this on the actual project structure and code.
PROMPT

echo "✅ Documentation generated at documentation/FULL_DOCUMENTATION.md"
