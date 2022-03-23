/- A toy dialect with basic tensor computations. -/

import MLIRSemantics.Types


/-
### Tensor reshaping operation

This operation can reshape (retype) tensors with fully-known dimensions,
provided that the number of elements doesn't change.
-/

def reshape {α} {D: DimList} (D': DimList)
    (H: D.known) (H': D'.known) (Hprod: D'.prod = D.prod):
    RankedTensor α D → RankedTensor α D' :=
  fun t =>
    { shape := D'.project,
      size := t.size,
      data := t.data,
      Hdim := dim_known_project_refines H',
      Hsize := by rw [t.Hsize, dim_known_prod D' H', Hprod]
                  rw [dim_known_prod_refines H];
                  apply t.Hdim }

theorem reshape_reshape {α} {D: DimList} (D₁ D₂: DimList)
    (H: D.known) (H₁: D₁.known) (H₂: D₂.known)
    (Hprod₁: D₁.prod = D.prod) (Hprod₂: D₂.prod = D₁.prod)
    (t: RankedTensor α D):
      reshape D₂ H₁ H₂ Hprod₂ (reshape D₁ H H₁ Hprod₁ t) =
      reshape D₂ H H₂ (Eq.trans Hprod₂ Hprod₁) t :=
  rfl

theorem reshape_self {α} D H₁ H₂ Hprod (t: RankedTensor α D):
    reshape D H₁ H₂ Hprod t = t := by
  simp [reshape, dim_known_project_eq H₁ t.Hdim]


/-
### Tensor transposition operation

This operation shuffles the elements of the underlying data without changing
its size. To keep this clean it's beneficial to separate the dimension logic
from the index manipulation of the transposition itself.
-/

def transpose_remap (size n m: Nat) (H: size=n*m): Fin size → Fin size :=
  λ i =>
    let r := i.val / n;
    let j := i.val % n;
    ⟨m*j+r, by sorry /- m*(≤ n-1)+(< m) -/⟩

theorem transpose_remap_involutive (size n m H):
      transpose_remap size m n (by rw [H, Nat.mul_comm])
    ∘ transpose_remap size n m H
    = id := by
  simp [transpose_remap]
  funext i; apply Fin.eq_of_val_eq; simp
  sorry /- fairly straightforward -/

@[inline]
def Matrix α n m :=
  RankedTensor α [MLIR.AST.Dimension.Known n, MLIR.AST.Dimension.Known m]

def transpose {α n m} (t: Matrix α n m): Matrix α m n :=
  { shape := [m, n],
    size := t.size,
    data := t.data ∘ transpose_remap t.size n m
            (by rw [t.Hsize, dim_known_prod_refines _ t.Hdim] <;> simp),
    Hdim := by simp,
    Hsize := by simp [List.foldr];
                rw [t.Hsize, dim_known_prod_refines _ t.Hdim] <;>
                simp [Nat.mul_comm] }

theorem Function.comp_assoc {α β γ δ} (f: α → β) (g: β → γ) (h: γ → δ):
    (h ∘ g) ∘ f = h ∘ (g ∘ f) :=
  by funext x; simp

theorem transpose_involutive {α n m}:
    ∀ (t: Matrix α n m), transpose (transpose t) = t := by
  intro t;
  simp [transpose, Function.comp_assoc, transpose_remap_involutive]
  apply RankedTensor.eq_of_fields_eq <;> simp
  . rw [←dim_known_project_eq _ t.Hdim] <;> simp
  . simp [transpose]
  . funext i; simp