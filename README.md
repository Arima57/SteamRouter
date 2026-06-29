# SteamRouter

> A proof-of-concept Windows DLL export router written in Zig, demonstrating compile-time generation of large export tables, runtime symbol resolution, and ABI-preserving assembly trampolines.

---

## Overview

SteamRouter is an educational systems programming project exploring how Windows DLL export forwarding can be implemented almost entirely through Zig's compile-time metaprogramming facilities.

The project automatically generates over one thousand exported forwarding stubs from a compile-time export list. Each stub consists of a minimal assembly trampoline that performs an unconditional jump to a runtime-resolved implementation while preserving the Windows x64 calling convention.

Although SteamRouter is demonstrated using the Steam API due to its large and stable export surface, the techniques employed are broadly applicable to any DLL interface exposing a large number of exported functions.

This repository is intended as a study of:

* Windows PE export tables
* Dynamic library loading
* Runtime symbol resolution
* Compile-time code generation in Zig
* x86-64 ABI preservation
* Inline assembly
* Systems programming techniques

---

## Architecture

SteamRouter consists of three major components.

### 1. Compile-Time Export Generation

At compile time, an embedded list of exported function names is parsed.

For every exported symbol, Zig generates an exported function automatically using `@export`, eliminating the need to manually maintain thousands of forwarding functions.

The resulting DLL therefore exports an interface matching the original library while keeping the implementation extremely small.

---

### 2. Runtime Symbol Resolution

Instead of resolving symbols during process startup, SteamRouter performs lazy initialization.

On the first invocation of a designated entry point, the backend DLL is loaded dynamically using the Win32 API.

All exported symbols are resolved using `GetProcAddress` and cached for subsequent calls.

This separates process startup from symbol resolution and keeps initialization deterministic.

---

### 3. ABI-Preserving Jump Trampolines

Every generated export is implemented as a naked function consisting of a minimal assembly trampoline.

Each trampoline simply performs an indirect jump to the previously resolved function pointer.

Because execution is transferred through a direct jump rather than a nested function call:

* no additional stack frame is created,
* the original return address is preserved,
* function arguments remain untouched,
* Windows x64 calling convention semantics are maintained.

---

## Staged Routing

SteamRouter demonstrates a staged routing strategy.

Instead of permanently forwarding every call to a single backend implementation, the router may transition between multiple backend DLLs during execution.

Conceptually, this models software systems whose runtime environment evolves through distinct initialization phases.

The current proof-of-concept uses two stages.

* **Stage 0** loads the initial backend.
* **Stage 1** replaces it with the primary backend after initialization completes.

Although simple, this demonstrates that export forwarding need not be static and may instead behave as a runtime state machine.

---

## Assumptions

For simplicity, this proof-of-concept assumes that the target application invokes `SteamAPI_RestartAppIfNecessary()` before any other exported Steam API function.

The specific application used during testing is intentionally not identified.

This assumption allows the initial routing stage to complete before any generic forwarding stubs are executed.

The project intentionally does **not** attempt to solve the general problem of arbitrary export ordering, as the purpose of SteamRouter is to demonstrate compile-time export generation and staged runtime routing rather than universal compatibility.

---

## Implementation Highlights

* Written entirely in Zig (except for the logger, which is written in C).
* Automatic generation of over one thousand exported functions.
* Compile-time parsing of export metadata.
* Runtime resolution through `LoadLibraryW()` and `GetProcAddress()`.
* Minimal assembly trampolines.
* Zero handwritten forwarding functions.
* Small generated binary despite a very large exported interface.

---

## Educational Goals

SteamRouter was developed as an exploration of several low-level software engineering topics:

* executable formats
* dynamic linking
* Windows loader behavior
* metaprogramming
* compiler-assisted code generation
* calling conventions
* ABI correctness
* systems programming with Zig

It is intended primarily as a learning exercise and a demonstration of systems programming techniques rather than a production-ready framework.

---

## License

MIT
