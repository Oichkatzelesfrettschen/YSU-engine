YSU Engine

A low-level, CPU-based rendering and simulation engine designed as a reusable foundation.

Overview

YSU Engine is a custom-built, low-level rendering and simulation engine written primarily in C, with selective use of assembly for performance-critical paths.
The engine is not designed as a single-purpose renderer; instead, it serves as a base framework upon which multiple rendering, editing, and experimental systems can be built.

The repository contains both core engine modules and standalone executables that demonstrate different subsystems such as rendering, mesh editing, scene editing, and multithreaded execution.

Design Philosophy

The engine follows three explicit design principles:

Foundational First
Core systems (math, camera, BVH, ray traversal, mesh topology) are implemented independently of higher-level features.
This allows the engine to act as a base layer for future engines rather than a single finished product.

CPU-Centric and Explicit Control
The engine prioritizes explicit memory management, deterministic execution, and CPU-based algorithms.
This enables direct experimentation with rendering algorithms, data layouts, and traversal strategies without GPU abstraction overhead.

Modular but Non-Abstracted
Modules are separated by responsibility, but not hidden behind heavy abstraction layers.
This keeps the engine readable, debuggable, and suitable for research-style iteration.

Repository Structure
Core Rendering & Geometry

camera.c / camera.h
Camera model implementation responsible for view generation and ray emission.

bvh.c / bvh.h
Bounding Volume Hierarchy implementation for accelerating ray–geometry intersection.

aabb_hit_asm.S
Assembly-optimized AABB intersection routine, indicating targeted performance optimization at the lowest level.

baseline_bvh.csv
Benchmark or reference data used to evaluate BVH performance.

Math & Infrastructure

ysu_mt.c / ysu_mt.h
Multithreading utilities enabling parallel execution.

Custom math and data handling are implied through the absence of external math libraries, reinforcing full control over numerical behavior.

Mesh & Topology Systems

ysu_mesh_topology.c / ysu_mesh_topology.h
Core mesh topology representation and manipulation logic.

ysu_mesh_edit.c
Mesh editing operations built on top of the topology system.

ysu_obj_exporter.c / ysu_obj_exporter.h
OBJ export functionality, allowing external inspection and interoperability.

Editing & Interaction Layers

ysu_edit_mode.c
Edit-mode logic layered on top of the core engine.

ysu_viewport.c
Viewport handling, acting as the bridge between engine data and user-visible output.

ysu_scene_editor.html
A web-based or hybrid scene editor interface, suggesting experimentation with tooling and UI separation.

Engine Entry Points & Executables

ysu_main.c
Primary engine entry point.

Prebuilt executables:

ysuengine.exe

ysu_viewport.exe

ysu_mesh_edit.exe

ysu_edit_mode.exe

These binaries indicate that subsystems can be run independently, reinforcing the engine’s modular, system-oriented design.

Tooling & Development Support

.vscode/
Editor configuration for consistent development.

.github/

CHECKPOINTS.md – internal progress tracking

copilot-instructions.md – AI-assisted development guidance

build_shaders.ps1
Windows-based build tooling for shader-related components.

What This Engine Is (and Is Not)
This engine is:

A low-level experimental rendering framework

A reusable base for future engines and simulations

A platform for algorithmic and architectural exploration

This engine is not:

A feature-complete game engine

A production-ready graphics API

A GPU-first or shader-centric renderer

These constraints are intentional, not limitations.

Performance Considerations

BVH acceleration is central to ray traversal.

Assembly-level optimization is selectively applied where it matters most.

Multithreading support exists but remains explicit and controllable.

The engine favors clarity of data flow and algorithmic experimentation over opaque optimizations.

Limitations

Rendering pipeline is CPU-bound.

No physically complete material or lighting system is implied.

Tooling and UI layers are experimental and non-final.

Architecture prioritizes extensibility over immediate usability.

These limitations are deliberate, keeping the engine suitable as a research and foundation platform.

Future Direction

The current structure supports future work such as:

Alternative integrators and traversal strategies

Advanced material and lighting models

GPU backends while preserving CPU reference paths

Experimental imaging systems (e.g., non-classical or statistical imaging models)

Deeper editor integration on top of the existing mesh and scene systems

Summary

YSU Engine is not a single project, but a base system.
It exists to make future engines possible, not to replace them.

Its value lies in:

Architectural clarity

Low-level control

Explicit design decisions

Reusability as a foundation

Author : Umut Korkmaz 15 year old