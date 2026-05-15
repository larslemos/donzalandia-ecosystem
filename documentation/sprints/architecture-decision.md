# Phase 4: Architectural Alternatives & Migration Strategy

**Goal**: Analyze alternative architectures for the next stage of hyper-growth (1,500+ concurrent users) and document why we chose our current path, plus how to pivot if necessary.

## Current Architecture Summary
- **Frontend**: React 18 SPA built with Vite, using MUI v5 and TanStack Query for state.
- **Backend**: Laravel 12 Modular Monolith (PHP 8.2+), using Eloquent ORM and Sanctum for Auth.
- **Database**: MySQL 8.0 (Primary) with Redis for caching/sessions.
- **Communication**: Synchronous REST/JSON over HTTPS.
- **Hosting**: Vercel (Frontend CDN), VPS/Docker (Backend API).

---

## Alternative 1: Event-Driven Architecture (EDA)
**Description**: Decouple services via a message broker (Kafka/RabbitMQ).

**When to choose this**:
- Complex workflows with multiple steps (e.g., Triage -> Waitlist -> AI Report -> Notification).
- We need strict audit trails of state changes (tracking a child's entire clinical journey).
- Async processing is acceptable across domains.

**Pros**:
1. **Scalability**: Each consumer scales independently.
2. **Resilience**: The broker buffers during downstream outages.
3. **Flexibility**: Add new consumers (e.g., a "Data Warehouse sync" service) without touching the core API.

**Cons**:
1. **Complexity**: Debugging distributed async flows is notoriously difficult.
2. **Exactly-once semantics**: Hard to guarantee without complex idempotency keys.

**Migration Plan (If triggered)**:
1. **Sprint 1**: Stand up a managed RabbitMQ cluster.
2. **Sprint 2**: Implement Laravel Horizon and the `laravel-queue-rabbitmq` driver.
3. **Sprint 3**: Refactor the `Triagem` module to dispatch `TriageCompleted` events instead of calling the Waiting List service directly.

---

## Alternative 2: Microservices Architecture
**Description**: Break the Laravel modular monolith into physical microservices (e.g., Auth Service, Patient Service, AI Service).

**When to choose this**:
- The backend team grows to 15+ engineers requiring independent deployment pipelines.
- We need to rewrite the AI processing module in Python for better ML library support.

**Pros**:
1. **Independent Scaling**: Scale the Triage module separately from the Auth module.
2. **Polyglot Stack**: Mix PHP, Python, and Node.js.

**Cons**:
1. **Operational Overhead**: Requires Kubernetes, service meshes, and complex CI/CD.
2. **Data Consistency**: Distributed transactions and foreign keys disappear.

**Migration Plan (If triggered)**:
1. **Phase 1**: Extract the Database into bounded contexts (no cross-domain joins).
2. **Phase 2**: Stand up an API Gateway (e.g., Kong).
3. **Phase 3**: Extract the `Auth` module to an independent service and use JWTs for inter-service communication.

---

## Alternative 3: Serverless Backend (BFF Pattern)
**Description**: Shift away from a heavy Laravel API to Serverless functions acting as a Backend-For-Frontend, talking directly to a managed database like Supabase.

**When to choose this**:
- Highly variable traffic (e.g., massive spikes during school hours, zero traffic at night).
- Desire to eliminate server management entirely.

**Pros**:
1. **Zero Ops**: No servers or PHP-FPM to manage.
2. **Pay-for-What-You-Use**: Costs scale to zero during off-hours.

**Cons**:
1. **Cold Starts**: Initial latency penalties for functions.
2. **Framework Rewrite**: Laravel cannot easily be lifted-and-shifted to pure serverless functions without limitations.

**Migration Plan**: NOT RECOMMENDED. This would require a full rewrite.

---

## Strategic Recommendation

**Decision: Stick with the Modular Monolith (Current Architecture).**

For a 3-person team building an internal/specialized healthcare application with a $500/mo budget, moving to Microservices or an Event-Driven Architecture right now is a **premature optimization trap**.

The current architecture (Laravel 12 Modular Monolith + React SPA) is capable of handling millions of requests a day if the database and caching bottlenecks are fixed (as outlined in the 90-day roadmap). It provides the best balance of developer velocity, data consistency, and operational simplicity.

**Future Trigger**: If the AI processing becomes too heavy or complex, extract *only* the AI report generation into an event-driven Python microservice via Redis queues, while keeping the rest of the application as a monolith.
