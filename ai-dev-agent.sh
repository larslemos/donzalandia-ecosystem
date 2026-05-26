#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🤖 AI Development Agent for Donzalandia${NC}"
echo "================================================"

# Function to query Ollama with specific model
query_ollama() {
    local model=$1
    local prompt=$2
    local context=$3
    
    echo -e "${YELLOW}Using model: $model${NC}"
    
    if [ -n "$context" ]; then
        ollama run $model --context "$context" "$prompt"
    else
        ollama run $model "$prompt"
    fi
}

# Task 1: Code Analysis & Audit
audit_code() {
    echo -e "\n${GREEN}📊 Starting Code Audit...${NC}"
    
    # Audit Laravel code
    echo "Auditing Laravel backend..."
    find dondza/app -name "*.php" -type f | head -20 | while read file; do
        echo -e "\n${BLUE}Analyzing: $file${NC}"
        content=$(cat "$file")
        query_ollama "$CODE_AUDIT_MODEL" \
            "Analyze this Laravel/PHP code for security vulnerabilities, performance issues, and code quality. Focus on SQL injection, XSS, mass assignment, and proper validation. Provide specific line numbers and fix suggestions.\n\nFile: $file\n\nCode:\n$content"
    done
    
    # Audit Flutter code
    echo -e "\n${GREEN}Auditing Flutter mobile app...${NC}"
    find Uno/lib -name "*.dart" -type f | head -15 | while read file; do
        echo -e "\n${BLUE}Analyzing: $file${NC}"
        content=$(cat "$file")
        query_ollama "$CODE_AUDIT_MODEL" \
            "Analyze this Flutter/Dart code for performance issues, memory leaks, widget rebuild optimization, and state management problems. Suggest specific fixes.\n\nFile: $file\n\nCode:\n$content"
    done
    
    # Audit Next.js/React code
    echo -e "\n${GREEN}Auditing Next.js frontend...${NC}"
    find dondza_cadastro/src -name "*.jsx" -o -name "*.js" | head -15 | while read file; do
        echo -e "\n${BLUE}Analyzing: $file${NC}"
        content=$(cat "$file")
        query_ollama "$CODE_AUDIT_MODEL" \
            "Analyze this React/Next.js code for performance issues, unnecessary re-renders, hook dependencies, and accessibility problems. Suggest fixes.\n\nFile: $file\n\nCode:\n$content"
    done
}

# Task 2: Generate Documentation
generate_docs() {
    echo -e "\n${GREEN}📚 Generating Documentation...${NC}"
    
    mkdir -p documentation/ai-generated
    
    # Generate API documentation from Laravel
    echo "Generating API documentation..."
    routes_content=$(php dondza/artisan route:list --json)
    query_ollama "$DOC_MODEL" \
        "Based on these Laravel routes, generate comprehensive API documentation including endpoints, expected request/response formats, authentication requirements, and example usage.\n\nRoutes:\n$routes_content" \
        > documentation/ai-generated/api-docs.md
    
    # Generate component documentation from React
    echo "Generating React component documentation..."
    find dondza_cadastro/src/components -name "*.jsx" | head -10 | while read component; do
        component_name=$(basename "$component" .jsx)
        content=$(cat "$component")
        query_ollama "$DOC_MODEL" \
            "Generate comprehensive documentation for this React component including props, state, usage examples, and dependencies.\n\nComponent: $component_name\n\nCode:\n$content" \
            > "documentation/ai-generated/${component_name}.md"
    done
    
    # Generate Flutter widget documentation
    echo "Generating Flutter widget documentation..."
    find Uno/lib/widgets -name "*.dart" | while read widget; do
        widget_name=$(basename "$widget" .dart)
        content=$(cat "$widget")
        query_ollama "$DOC_MODEL" \
            "Generate documentation for this Flutter widget including parameters, build method explanation, and usage example.\n\nWidget: $widget_name\n\nCode:\n$content" \
            > "documentation/ai-generated/flutter_${widget_name}.md"
    done
    
    # Generate architecture overview
    echo "Generating architecture overview..."
    query_ollama "$DOC_MODEL" \
        "Based on the project structure (Laravel backend, Next.js frontend, Flutter mobile app), generate a comprehensive architecture documentation including:
        1. System architecture diagram (ASCII)
        2. Data flow between components
        3. Authentication flow
        4. Deployment strategy
        5. Key integrations
        
        Project structure:
        $(tree -L 3 -d -I 'node_modules|vendor|.git')" \
        > documentation/ai-generated/architecture.md
}

# Task 3: Generate Code
generate_code() {
    local prompt=$1
    local target_file=$2
    
    echo -e "\n${GREEN}💻 Generating Code...${NC}"
    echo "Prompt: $prompt"
    echo "Target: $target_file"
    
    # Get existing code context if file exists
    context=""
    if [ -f "$target_file" ]; then
        context=$(cat "$target_file")
        echo "Found existing file, using as context..."
    fi
    
    # Generate with specialized coder model
    query_ollama "$CODE_GEN_MODEL" "$prompt" "$context" > "$target_file.tmp"
    
    # Show diff if file exists
    if [ -f "$target_file" ]; then
        echo -e "\n${YELLOW}Changes to be made:${NC}"
        diff -u "$target_file" "$target_file.tmp" | head -50
        read -p "Apply changes? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            mv "$target_file.tmp" "$target_file"
            echo "✅ Code generated and saved to $target_file"
        else
            rm "$target_file.tmp"
            echo "❌ Generation cancelled"
        fi
    else
        mv "$target_file.tmp" "$target_file"
        echo "✅ New file created: $target_file"
    fi
}

# Task 4: Generate and Run Tests
run_tests() {
    echo -e "\n${GREEN}🧪 Generating and Running Tests...${NC}"
    
    mkdir -p "$TEST_REPORT_DIR"
    
    # Generate Laravel tests
    echo "Generating Laravel feature tests..."
    php dondza/artisan make:test AIGeneratedTest --unit
    
    # Use Codestral to generate test cases
    controller_files=$(find dondza/app/Http/Controllers -name "*.php" | head -5)
    for controller in $controller_files; do
        controller_name=$(basename "$controller" .php)
        content=$(cat "$controller")
        
        query_ollama "$TEST_MODEL" \
            "Generate PHPUnit test cases for this Laravel controller. Include:
            - HTTP request tests for each method
            - Authentication tests
            - Validation tests
            - Database assertion tests
            - Edge cases and error responses
            
            Controller: $controller_name
            Code:\n$content" \
            > "dondza/tests/Feature/${controller_name}Test.php"
    done
    
    # Generate Flutter widget tests
    echo "Generating Flutter widget tests..."
    find Uno/lib/screens -name "*.dart" | while read screen; do
        screen_name=$(basename "$screen" .dart)
        content=$(cat "$screen")
        
        query_ollama "$TEST_MODEL" \
            "Generate Flutter widget tests for this screen including:
            - Widget existence tests
            - User interaction tests  
            - State change verification
            - Navigation tests
            - Mock dependencies using Mockito
            
            Screen: $screen_name
            Code:\n$content" \
            > "Uno/test/${screen_name}_test.dart"
    done
    
    # Generate React component tests
    echo "Generating React component tests..."
    find dondza_cadastro/src/components -name "*.jsx" | while read component; do
        component_name=$(basename "$component" .jsx)
        content=$(cat "$component")
        
        query_ollama "$TEST_MODEL" \
            "Generate Jest + React Testing Library tests for this component including:
            - Rendering tests
            - Props validation
            - Event handlers testing  
            - Async behavior testing
            - Snapshot tests
            
            Component: $component_name
            Code:\n$content" \
            > "dondza_cadastro/src/__tests__/${component_name}.test.jsx"
    done
    
    # Run the tests
    echo -e "\n${GREEN}Running all tests...${NC}"
    
    # Run Laravel tests
    echo "Running Laravel tests..."
    cd dondza && php artisan test --log-junit "$TEST_REPORT_DIR/laravel-tests.xml" && cd ..
    
    # Run Flutter tests
    echo "Running Flutter tests..."
    cd Uno && flutter test --machine > "$TEST_REPORT_DIR/flutter-tests.json" && cd ..
    
    # Run React tests
    echo "Running React tests..."
    cd dondza_cadastro && npm test -- --coverage --watchAll=false --json --outputFile="$TEST_REPORT_DIR/react-tests.json" && cd ..
    
    # Generate test summary
    echo -e "\n${GREEN}Test Summary:${NC}"
    query_ollama "$DOC_MODEL" \
        "Analyze these test results and provide a summary including:
        - Total tests passed/failed
        - Code coverage percentages
        - Most common failure patterns
        - Recommendations for fixing failures
        
        Laravel tests: $(cat "$TEST_REPORT_DIR/laravel-tests.xml" 2>/dev/null | head -20)
        Flutter tests: $(cat "$TEST_REPORT_DIR/flutter-tests.json" 2>/dev/null | head -20)
        React tests: $(cat "$TEST_REPORT_DIR/react-tests.json" 2>/dev/null | head -20)" \
        > "$TEST_REPORT_DIR/test-summary.md"
    
    cat "$TEST_REPORT_DIR/test-summary.md"
}

# Task 5: Cross-Project Analysis
analyze_integration() {
    echo -e "\n${GREEN}🔄 Analyzing Cross-Project Integration...${NC}"
    
    # Extract API endpoints from Laravel
    echo "Extracting API endpoints from Laravel..."
    php dondza/artisan route:list --json > /tmp/laravel-routes.json
    
    # Extract API calls from React
    echo "Extracting API calls from React frontend..."
    grep -r "axios\|fetch\|api\." dondza_cadastro/src --include="*.js" --include="*.jsx" > /tmp/react-api-calls.txt
    
    # Extract API calls from Flutter
    echo "Extracting API calls from Flutter mobile..."
    grep -r "http\|dio\|api\." Uno/lib --include="*.dart" > /tmp/flutter-api-calls.txt
    
    # Analyze integration consistency
    query_ollama "$CODE_AUDIT_MODEL" \
        "Analyze the integration between these three projects:
        1. Laravel API (routes.json)
        2. React frontend (api-calls.txt)
        3. Flutter mobile (api-calls.txt)
        
        Check for:
        - Missing API endpoints
        - Inconsistent data structures
        - Authentication flow issues
        - Error handling patterns
        - Performance bottlenecks
        
        Laravel Routes: $(cat /tmp/laravel-routes.json | head -50)
        React API Calls: $(cat /tmp/react-api-calls.txt | head -30)
        Flutter API Calls: $(cat /tmp/flutter-api-calls.txt | head -30)" \
        > documentation/ai-generated/integration-analysis.md
    
    cat documentation/ai-generated/integration-analysis.md
}

# Main menu
show_menu() {
    echo -e "\n${BLUE}Select task:${NC}"
    echo "1) 🔍 Audit all code (Laravel + Flutter + React)"
    echo "2) 📚 Generate complete documentation"
    echo "3) 💻 Generate new code (with context)"
    echo "4) 🧪 Generate and run all tests"
    echo "5) 🔄 Analyze cross-project integration"
    echo "6) 🎯 Run complete workflow (1-5 in order)"
    echo "7) ❌ Exit"
    echo -n "Choice: "
}

# Main loop
while true; do
    show_menu
    read choice
    case $choice in
        1) audit_code ;;
        2) generate_docs ;;
        3) 
            echo "Enter code generation prompt:"
            read prompt
            echo "Enter target file path:"
            read target
            generate_code "$prompt" "$target"
            ;;
        4) run_tests ;;
        5) analyze_integration ;;
        6)
            echo -e "${GREEN}Running complete workflow...${NC}"
            audit_code
            generate_docs
            run_tests
            analyze_integration
            echo -e "\n${GREEN}✅ Complete workflow finished!${NC}"
            echo "Reports saved in: documentation/ai-generated/"
            echo "Test results saved in: $TEST_REPORT_DIR/"
            ;;
        7) 
            echo -e "${GREEN}Goodbye! 👋${NC}"
            exit 0
            ;;
        *) echo -e "${RED}Invalid option${NC}" ;;
    esac
done

