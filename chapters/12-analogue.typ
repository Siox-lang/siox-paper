#import "../style.typ": *

= Phase 2: analogue and mixed signal
#status("phase2")

The second phase adds continuous behaviour to the language without weakening
the digital one. A board's power supply, filters, sensors, amplifiers and
clocks are as much part of the circuit as its logic, and siox aims to
describe them in the same language and simulate them together.

== What it will do

- *Domains and quantities.* An analogue model works with continuous
  quantities in physical domains: voltage and current in the electrical
  domain, and later others (thermal, mechanical). A domain defines what is
  measured *across* a connection (a potential, such as voltage) and what flows
  *through* it (a flow, such as current).
- *Equations, not assignments.* Analogue behaviour is a set of relations that
  must hold at every instant: a resistor states that the voltage across it is
  its resistance times the current through it; a capacitor relates current to
  the rate of change of voltage. Time derivatives and integrals are first-class
  (`'ddt` is already reserved, and rejected by the digital compiler today).
- *Solvers.* The compiler collects the equations of a whole network into a
  system, and a solver integrates it over time. Solver choice, tolerances and
  step control are part of the model, and a solver that fails to converge
  points back at the source equations and domains, not at matrix indices.
- *Bridges.* Digital and analogue meet through explicit conversions with
  well-defined event rules: sampling an analogue quantity into a digital
  value, holding a digital value as an analogue level, detecting a threshold
  crossing as a digital event, and quantizing. There are no implicit
  conversions between the two worlds.
- *One timeline.* Digital events and analogue integration share simulation
  time deterministically: a crossing that produces a digital event lands at a
  well-defined point in the delta-cycle order, the same every run.

#sketch

```siox
entity Resistor<R: real> { p: Electrical inout, n: Electrical inout }

impl<R: real> Resistor<R> {
    let branch = p -> n;                       // the path from p to n
    branch.voltage == R * branch.current;      // holds at every instant
}

entity Capacitor<C: real> { p: Electrical inout, n: Electrical inout }

impl<C: real> Capacitor<C> {
    let branch = p -> n;
    branch.current == C * branch.voltage'ddt;
}
```

== What it will not do

- *Change the digital language.* Digital semantics never depend on an
  analogue solver. A purely digital design compiles and simulates exactly as
  it does in Phase 1.
- *Share an IR.* Analogue models get their own intermediate representation
  and solver boundary. The digital IR stays exact and event-driven.
- *Accept analogue syntax early.* Until the phase lands, analogue constructs
  are errors in the digital compiler, so no design silently depends on
  something that does not work yet.

== How it will be judged

Phase 2 is done when siox can solve small linear and nonlinear networks,
co-simulate a digital controller with an analogue plant (a PWM controller
driving a filter and a load, say), order bridge events deterministically, and
report solver failures in terms of the source.
