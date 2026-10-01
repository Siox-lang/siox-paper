// siox: what the language is for and what it will do.
// Build: `typst compile siox.typ` (Typst 0.12 or later).

#import "style.typ": *
#show: paper

#title-page()

#outline(indent: auto, depth: 2)

#part[Part I · Purpose]
#include "chapters/01-why.typ"
#include "chapters/02-principles.typ"
#include "chapters/03-first-look.typ"

#part[Part II · The digital language]
#include "chapters/04-structure.typ"
#include "chapters/05-behaviour.typ"
#include "chapters/06-types.typ"
#include "chapters/07-abstraction.typ"
#include "chapters/08-metadata.typ"
#include "chapters/09-verification.typ"
#include "chapters/10-compiler.typ"

#part[Part III · Where siox is going]
#include "chapters/11-growth.typ"
#include "chapters/12-analogue.typ"
#include "chapters/13-design.typ"
#include "chapters/14-ecosystem.typ"

#part[Appendix]
#include "chapters/15-appendix.typ"
