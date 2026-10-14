# Compiled libraries and subparts: rustc-style

Status: **owner direction: mirror rustc; detailed contracts below are proposed,
and compiled metadata/native reuse is not yet implemented**. Explicit source
inputs and test planning exist in the development
branch. The experimental parsed-AST `.sioxlib` implementation was removed before
publication: it repeated dependency resolution/type checking and was not a
replacement for rustc-style compiled libraries.

Implementation has started in the local, unpublished `feat/rustc-compiled-units`
branch. Compiler changes remain local until the required acceptance gate is green.
This document publishes the plan, not a released compiler interface. `CrateIdentity`,
`PersistentDefId` and `Resolved::persistent_id` now give module items, enum
variants, overloaded views and item generic parameters exact semantic keys.
`CompileRequest::with_crate_identity` supplies an explicit name/disambiguator;
normal compilation remains source-based. Keys do not contain source locations
or compilation-local definition indices, and import aliases preserve the
defining key. Trait methods use their trait owner; impl methods, state and
generic binders use an impl-specific owner. Anonymous impl keys have
module-local disambiguators: adding named items or unrelated modules does not
renumber them, but adding/reordering impl blocks in that module can.
Trait visibility, required/default method contracts and default inheritance
now use resolved declaration IDs. `Typed::trait_contracts` retains semantic
method IDs for downstream consumers without copying source declarations.
The array-family registry retains defining declaration IDs in `Typed`.
`Typed::persistent_type` projects concrete checked types to `PersistentTy`:
nominal elements/families retain crate/declaration identities, and nested
arrays/tuples retain lengths and format bounds. Unknown family keys and
unchecked/deferred generic types are rejected instead of guessed. This is
semantic type projection, not a byte format; existing parametric zero-length
shapes do not encode a generic parameter expression or replace typed bodies.
Owner-local body references, remaining identity-keyed typed registries,
generic/const type expressions and metadata encoding/loading are next. These
keys/contracts alone are not an external crate loader or native linking ABI.

### Compiler versus package tool

Wafer owns dies (packages), manifests, versions, fetching, build order, lockfiles,
artifact caching and execution. A compiler crate is a compilation unit, not a
package manifest. `sioxc` receives an entry, explicit source modules, a crate
name/disambiguator, compiled dependencies and output/target options. It reads
no project manifest, discovers no packages, contacts no registry, and runs no
test executable. `--test` generates a harness; Wafer runs it.

Use rustc's public vocabulary where the semantics agree:

- `--crate-name NAME` identifies the compilation unit.
- `--crate-type lib` requests the compiler-native library archive; native
  `staticlib` is a distinct ABI/output, not a metadata archive in disguise.
- `--extern NAME=PATH` provides a direct compiled dependency. An extern binding
  may rename a crate without changing its persisted declaration identities.
- `-L dependency=PATH` finds transitive compiled dependencies by identity/hash,
  not by the first file with a matching basename.
- `--emit metadata` writes importable compiler metadata; `obj`, `llvm-ir` and
  `dep-info` retain their separate meanings. Native code/library linking must
  not be advertised by merely changing the spelling of a source-cache flag.
- `-o`, `--out-dir`, `--test` and an eventual codegen disambiguator keep compiler
  artifact selection separate from package-tool execution.

These are **target interfaces, not implemented commands**. Migration must update
the embedding API, CLI, Wafer, LSP settings/adapters, CI, tests and documentation
together. The current `--emit metadata` performs analysis without emitting a
metadata file, and the default output is an object: neither currently mirrors
rustc's output contract. Preserve existing workflows until the replacement
semantics work; reject unsupported output kinds rather than emitting a dummy
archive. An ordinary runnable-design entry contract must be defined before
claiming general `bin` output; a generated test executable is already separate.

### Metadata and code are different products

[rustc metadata](https://rustc-dev-guide.rust-lang.org/backend/libs-and-metadata.html)
records compiler compatibility, stable crate identity, dependency hashes,
exported definitions, source information and bodies needed downstream. Its
metadata-only artifact contains no objects and cannot satisfy native linking;
the native compiler library archive contains metadata and codegen-unit objects.
Mirror those roles, not Rust's byte format or filename extension.

For Siox, persisted metadata needs:

1. Stable crate identity and crate-local declaration identities. Persisted
   references must not contain session-local `DefId`, `FileId`, `InstanceId` or
   signal/process-vector offsets as globally meaningful IDs.
2. Exported module/type/trait/function/entity/view signatures, visibility,
   trait implementations, nominal type identity and required lang hooks.
   Private definitions needed by exported bodies remain in metadata without
   becoming externally accessible.
3. Checked, resolved generic/const-evaluable bodies with their type information
   and stable references. Exported macro templates are a separate metadata
   payload; preserving them is not a reason to serialize every dependency AST
   and rerun its frontend.
4. Dependency identities and content/option hashes, compiler/format compatibility,
   target/ABI and simulation-versus-elaboration compatibility, source/debug
   mappings and compile-time file dependencies. An integrity hash is not package
   authentication; executable compiler artifacts require trusted provenance.

The existing resolved-tree work in section 4 is a prerequisite: registries keyed
only by leaf strings cannot distinguish two crate versions or renamed extern
bindings reliably. Do not replace these identities with another global width,
array-size bound or opaque AST/source bundle.

### One pipeline with imported semantic products

Local source follows parsing/expansion, resolution, checking, elaboration,
canonical Process IR and native codegen. Imported crates supply already-checked
semantic products through stage-owned input interfaces. The resolver consumes
external definitions, and the type checker consumes external type/trait facts;
neither imports `compiler`, `ir`, or another later stage to decode metadata.
The compiler orchestration layer loads/validates artifacts and supplies those
views. There is no alternate source frontend or independent simulation pipeline.

Dependencies are not re-parsed/re-checked merely to reconstruct these products.
Consumer-local checks still run, including visibility, generic constraints and
trait coherence across the compilation graph.

Following [rustc's monomorphization model](https://rustc-dev-guide.rust-lang.org/backend/monomorph.html),
concrete reusable items have code in their owning crate. Generic bodies are
specialized where concrete types/parameters are known, and inline bodies may
enter consumer codegen units. Entity specialization follows the same principle,
with hardware-specific elaboration before Process IR emission.

The current engine flattens the design and largely inlines source functions.
Calling that output a library does not make it independently linkable. A codegen
unit boundary must preserve semantic identities and define symbols/calls before
non-generic dependency code can actually be reused.

### Hardware-specific linking contract

Reusable behavior must be separate from per-instance storage. Two instances of
one compiled entity cannot share a baked-in signal array, driver context,
process ID or reset state. Define an instance binding/layout contract, scheduler
registration and net/port/view connections, plus source/debug/wave metadata.
Symbols incorporate crate identity and specialization; the final simulator
links one compatible runtime and registers each instance independently.

Generic entities retain elaboratable checked bodies until parameters/layouts are
known. Full-design validation must still check connections, directions, drivers
and resolution across compiled-unit boundaries. Vendor `top` metadata remains
vendor metadata; compilation root selection must not reinterpret it as a
compiler/test directive.

### Implementation order and acceptance

1. Stable semantic identities and declaration/type registries; test import aliases
   and equal leaf names without rewriting definitions by string substitution.
2. Metadata encoder/loader and per-stage external views. Remove dependency source
   files, then compile a consumer using the metadata; dependency frontend work
   must not repeat. Reject malformed, stale, wrong-target or mismatched transitive
   artifacts with structured failures and original source locations.
3. Checked generic/const bodies, exported macros, trait/view implementations and
   specialization/instantiation. Compare source and compiled-input results.
4. Native codegen units, symbol mangling and archive/linking. Prove concrete
   dependency objects are reused, not silently regenerated in the consumer.
   Metadata-only input must fail when required native code is unavailable.
5. Instance/scheduler relocation, debug/wave integration, dependency reporting
   and coordinated Wafer/LSP integration. Test two independently driven instances
   of the same compiled entity; native results and VCD/FST must match source
   compilation in default and bitpack modes.

LLVM/runtime changes need coordination with their current owner. No successful
source-cache or token-cache test counts as completion of these acceptance gates.
