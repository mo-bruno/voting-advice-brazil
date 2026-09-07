# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Farol Político** — Voting advice application for Brazil (academic project, Mackenzie University, Prof. Dr. Rodrigo Juliani, 2026-1).

A "Reverse Wahl-O-Mat": instead of matching users to politicians based on *promises*, it matches based on *actual voting records* from the official Câmara dos Deputados API. Includes a physical IoT device ("Farol Político") that changes LED color in real time when a followed politician votes.

### Product Phases

- **Fase 1 (MVP):** Wahl-O-Mat clone using TSE 2022 candidate proposals. AI generates simple theses from legal text; user answers agree/disagree; app ranks candidates by compatibility score.
- **Fase 2:** Integrates Câmara API — cross-references proposals with actual votes, calculates a consistency index, real-time tracker + IoT device via MQTT.
- **Fase 3:** Anonymous Reddit-style community with AI-powered fake news moderation.

### Key Deadlines

- **2026-04-06:** Entrega do Plano de Projeto (Week 8)
- **2026-05-04:** MVP delivery and presentation (Week 10) — critical
- **2026-06-01:** Final project delivery (Week 16)

## Team

| GitHub | Role |
|---|---|
| brunomo-cw | Backend, AI/LLM, data pipeline, MQTT broker |
| RafaelBeniites | Flutter mobile (UI/UX + API integration) |
| Ckenz0 | IoT/ESP32 firmware (C/C++, MQTT subscriber, hardware) |

## Architecture Decisions

- **Clean Architecture:** `core/` has zero knowledge of FastAPI, Groq, or any external service. All I/O in `infrastructure/`. This allows testing business logic without mocking HTTP.
- **Batch AI pipeline:** LLM analysis runs as a scheduled job, not on request. Keeps API latency low and LLM costs predictable.
- **Anonymous by design:** No PII stored. Users identified only by device-generated UUID (`device_token`). Quiz responses not persisted server-side.
- **MQTT QoS 1:** At-least-once delivery for IoT events. Firmware handles idempotent LED updates.
- **MQTT topic schema:** `farol/{device_token}` — payload: `{color, deputy_name, vote_summary, timestamp_utc}`. Contrato entre backend e firmware: não é derivável lendo só um dos lados.
- **LED states:** Green (aligned) / Yellow (abstention) / Red (divergent) / Blue pulse (pending).

## Data Sources

- **TSE 2022 proposals:** `dadosabertos.tse.jus.br` — candidate government plans (PDF/text)
- **Câmara API (Fase 2):** `dadosabertos.camara.leg.br` — endpoints: `/deputados`, `/proposicoes`, `/votacoes/{id}/votos`

## User Stories

103 user stories organized in 17 epics across 3 product phases are tracked in **Vibe Kanban** (project: "Voting Advice Brazil", org: "mo-bruno's Org"). Stories follow the format: *"Eu, como [usuário/desenvolvedor], quero [ação] para [objetivo]"* with acceptance criteria per the INVEST criteria taught in the course.
