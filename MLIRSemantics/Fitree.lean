/-
## Finite interaction trees

The semantics framework for this project is extremely inspired by the Vellvm
project [1] and is essentially centered around interaction trees and monadic
transformers.

Interactions trees are a particular instance of the freer monad; essentially,
an ITree is a program that can have side effets through *interactions*, and
these interactions can either be interpreted into the program or kept as
observable side-effects.

When giving semantics to a program, one usually starts with a rather simple
ITree where most of the complex features of the language (memory, I/O,
exceptions, randomness, non-determinism, etc) are hidden behind interactions.
The interactions are then interpreted, which consists of (1) enriching the
program's environment by a monadic transformation, and (2) replacing the
interaction with an actual implementation.

This approach allows monadic domains to be used while keeping each family of
interactions separate. This is relevant for Vellvm as LLVM IR as many complex
features, and even more relevant for MLIR since each dialect can bring more
interactions and environment transforms and all of them have to be studied and
defined independently.

The datatype of interaction trees normally has built-in non-termination by
being defined coinductively. Support for coinduction is still limited in Lean4,
so we currently use a finite version of ITrees (hence called Fitree) which can
only model programs that always terminate.

[1]: https://github.com/vellvm/vellvm
-/

/- Extendable effect families -/

section events
universe u v

def pto (E: Type → Type u) (F: Type → Type v) :=
  ∀ T, E T → F T
def psum (E: Type → Type u) (F: Type → Type v) :=
  fun T => E T ⊕ F T
inductive PVoid: Type -> Type u

infixr:40 " ~> " => pto
infixl:40 " +' " => psum

class Member (E: Type → Type u) (F: Type → Type v) where
  inject : E ~> F

instance {E}: Member E E where
  inject := (fun _ => id)

instance {E F G} [Member E F]: Member E (F +' G) where
  inject T := Sum.inl ∘ Member.inject T

instance {E F G} [Member E G]: Member E (F +' G) where
  inject T := Sum.inr ∘ Member.inject T

-- Effects can now be put in context automatically by typeclass resolution
example (E: Type → Type u):
  Member E E := inferInstance
example (E: Type → Type u) (F: Type → Type v):
  Member E (E +' F) := inferInstance
example (E: Type → Type u) (F: Type → Type v):
  Member E (F +' (F +' E)) := inferInstance

end events


/- Examples of interactions -/

inductive StateE {S: Type}: Type → Type where
  | Read: Unit → StateE S
  | Write: S → StateE Unit

inductive WriteE {W: Type}: Type → Type where
  | Tell: W → WriteE Unit


/- The monadic domain; essentially finite Interaction Trees -/

section fitree
universe u v

inductive Fitree (E: Type → Type u) (R: Type) where
  | Ret (r: R): Fitree E R
  | Vis {T: Type} (e: E T) (k: T → Fitree E R): Fitree E R

def Fitree.ret {E R}: R → Fitree E R :=
  Fitree.Ret

def Fitree.trigger {E: Type → Type u} {F: Type → Type v} {T} [Member E F]
    (e: E T): Fitree F T :=
  Fitree.Vis (Member.inject _ e) Fitree.ret

def Fitree.bind {E R T} (t: Fitree E T) (k: T → Fitree E R) :=
  match t with
  | Ret r => k r
  | Vis e k' => Vis e (λ r => bind (k' r) k)

instance {E}: Monad (Fitree E) where
  pure := Fitree.ret
  bind := Fitree.bind


-- Interpretation into the monad of finite ITrees
def interp {M} [Monad M] {E} (h: forall ⦃T⦄, E T → M T):
    forall ⦃R⦄, Fitree E R → M R :=
  λ _ t =>
    match t with
    | Fitree.Ret r => pure r
    | Fitree.Vis e k => bind (h e) (λ t => interp h (k t))

-- Interpretation into the state monad
def interp_state {M S} [Monad M] {E} (h: forall ⦃T⦄, E T → StateT S M T):
    forall ⦃R⦄, Fitree E R → StateT S M R :=
  interp h

-- Since we only use finite ITrees, we can actually run them when they're
-- fully interpreted (which leaves only the Ret constructor)
def Fitree.run {R}: Fitree PVoid R → R
  | Ret r => r
  | Vis e k => nomatch e

end fitree