# Technical Document: Atmos Renderers & Sonic Sphere Architecture

## Objective
Produce a deep technical document covering:
1. How Dolby Atmos renderers work (object-based + bed audio)
2. How a single master file adapts to 2.0, 5.1, 7.1, 9.2, and theatrical 64+ channel configurations
3. Full mathematical and architectural treatment of the rendering pipeline
4. A dedicated section on Sonic Sphere — a full-sphere renderer using the same architecture but extending above the horizon plane

## Stage 1 — Deep Research (Parallel)
Load: `deep-research-swarm`
- Agent 1: Atmos renderer internals — object-based audio, bed channels, OAMD metadata, RMU, DAPS, speaker virtualization
- Agent 2: Channel adaptation — how renderer maps objects to arbitrary speaker layouts, VBAP, binaural downmix, near/mid/far field rendering
- Agent 3: Existing sphere audio — Ambisonics (HOA), MPEG-H, DTS:X, Sony 360 Reality Audio — techniques for full-sphere rendering above the horizon

## Stage 2 — Report Writing
Load: `report-writing`
- Design detailed outline based on research findings
- Write full technical report with sections:
  - Executive Summary
  - Part I: Atmos Architecture ( beds, objects, metadata, OAMD)
  - Part II: The Rendering Pipeline ( object panning, speaker mapping, virtualization)
  - Part III: Multi-Configuration Playback (stereo, 5.1, 7.1.4, 9.2, theatrical arrays)
  - Part IV: Sonic Sphere — Full Sphere Rendering (mathematical extension)
  - Part V: Implementation Considerations
- Produce final .md then convert to .docx

## Stage 3 — Artifact Production
Load: `docx`
- Convert final markdown to professionally formatted Word document

## Deliverables
- `/mnt/agents/output/atmos-sonic-sphere-renderer.docx` — Final technical document
