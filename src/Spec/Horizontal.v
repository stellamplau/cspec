Require Import Helpers.Helpers.
Require Import Helpers.ListStuff.
Require Import Helpers.Maps.
Require Import ConcurProc.
Require Import Equiv.
Require Import Omega.
Require Import List.
Require Import Modules.
Require Import Ordering.
Require Import Abstraction.

Import ListNotations.

Global Set Implicit Arguments.
Global Generalizable All Variables.


Section HorizontalComposition.

  Variable indexT : Type.
  Context {cmp : Ordering indexT}.
  Variable indexValid : indexT -> Prop.

  Variable sliceOpT : Type -> Type.
  Variable sliceState : Type.
  Variable sliceStep : OpSemantics sliceOpT sliceState.
  Variable initP : sliceState -> Prop.

  Inductive horizOpT : Type -> Type :=
  | Slice : forall (i : indexT) T (op : sliceOpT T), horizOpT T
  .

  Definition horizState := FMap.t indexT sliceState.

  Inductive horizStep :
      forall T, horizOpT T -> nat -> horizState -> T -> horizState -> list event -> Prop :=
  | StepSlice :
    forall tid idx (S : horizState) (s : sliceState) `(op : sliceOpT T) r s' evs,
      FMap.MapsTo idx s S ->
      sliceStep op tid s r s' evs ->
      horizStep (Slice idx op) tid S r (FMap.add idx s' S) evs
  .

  Definition horizInitP (S : horizState) :=
    forall i,
      indexValid i ->
      exists s,
        FMap.MapsTo i s S /\
        initP s.

End HorizontalComposition.


Section HorizontalCompositionAbs.

  Variable indexT : Type.
  Context {cmp : Ordering indexT}.
  Variable indexValid : indexT -> Prop.

  Variable sliceOpT : Type -> Type.

  Variable sliceState1 : Type.
  Variable sliceStep1 : OpSemantics sliceOpT sliceState1.
  Variable initP1 : sliceState1 -> Prop.

  Variable sliceState2 : Type.
  Variable sliceStep2 : OpSemantics sliceOpT sliceState2.
  Variable initP2 : sliceState2 -> Prop.


  Variable absR : sliceState1 -> sliceState2 -> Prop.

  Definition horizAbsR (S1 : horizState sliceState1) (S2 : horizState sliceState2) : Prop :=
    forall (i : indexT),
      ( forall s1,
          FMap.MapsTo i s1 S1 ->
            exists s2, FMap.MapsTo i s2 S2 /\ absR s1 s2 ) /\
      ( forall s2,
          FMap.MapsTo i s2 S2 ->
            exists s1, FMap.MapsTo i s1 S1 /\ absR s1 s2 ).

  Hint Resolve FMap.add_mapsto.
  Hint Resolve FMap.mapsto_add_ne'.

  Theorem horizAbsR_ok :
    op_abs absR sliceStep1 sliceStep2 ->
    op_abs horizAbsR (horizStep sliceStep1) (horizStep sliceStep2).
  Proof.
    unfold op_abs, horizAbsR; intros.
    inversion H1; clear H1; subst; repeat sigT_eq.
    eapply H0 in H5; deex.
    eapply H in H8; eauto; deex.
    eexists; split; [ | econstructor; eauto ].
    intros.
    destruct (i == idx); subst.
    - split; intros.
      + eapply FMap.mapsto_add_eq in H5; subst; eauto.
      + eapply FMap.mapsto_add_eq in H5; subst; eauto.
    - specialize (H0 i); intuition idtac.
      + eapply FMap.mapsto_add_ne in H0; eauto.
        specialize (H5 _ H0); deex; eauto.
      + eapply FMap.mapsto_add_ne in H0; eauto.
        specialize (H6 _ H0); deex; eauto.
  Qed.

End HorizontalCompositionAbs.
