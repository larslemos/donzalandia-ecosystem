#!/bin/bash

# Deep code audit using DeepSeek R1
echo "🔍 Deep Code Audit with DeepSeek R1"

# Audit Triagem module (your core domain)
ollama run deepseek-r1:14b << 'PROMPT'
Perform a comprehensive security and performance audit of the Triagem (screening) module in Donzalandia.

Focus on:
1. SQL injection vulnerabilities in Laravel queries
2. XSS risks in React forms
3. State management issues in Flutter
4. API authentication gaps
5. Data validation inconsistencies

Examine these key files:
- dondza/app/Modules/Triagem/Controllers/
- dondza_cadastro/src/sections/triagem/
- Uno/lib/screens/triagem/

Provide specific line numbers and fix recommendations.
PROMPT
