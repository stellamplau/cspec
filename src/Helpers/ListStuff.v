Require Import Omega.
Require Import List.

Import ListNotations.

Global Set Implicit Arguments.
Global Generalizable All Variables.

Fixpoint pad `(l : list T) len val : list T :=
  match len with
  | O => l
  | S len' =>
    match l with
    | x :: l' =>
      x :: pad l' len' val
    | nil =>
      val :: pad nil len' val
    end
  end.

Fixpoint list_upd `(l : list T) (idx : nat) (v : T) :=
  match l with
  | nil => nil
  | x :: l' =>
    match idx with
    | O => v :: l'
    | S idx' => x :: list_upd l' idx' v
    end
  end.

Lemma pad_is_append : forall n `(l : list T) v,
  pad l n v = l ++ repeat v (n - length l).
Proof.
  induction n; simpl; intros.
  - rewrite app_nil_r; eauto.
  - destruct l; simpl.
    + rewrite IHn; simpl. replace (n - 0) with n by omega. reflexivity.
    + rewrite IHn. eauto.
Qed.

Lemma repeat_app : forall n m `(x : T),
  repeat x (n + m) = repeat x n ++ repeat x m.
Proof.
  induction n; simpl; eauto; intros.
  f_equal. eauto.
Qed.

Lemma repeat_tl : forall n `(x : T),
  repeat x (S n) = repeat x n ++ [x].
Proof.
  induction n; simpl; eauto; intros.
  f_equal. rewrite <- IHn. reflexivity.
Qed.

Lemma rev_repeat : forall n T (x : T),
  rev (repeat x n) = repeat x n.
Proof.
  induction n; simpl; eauto; intros.
  rewrite IHn.
  rewrite <- repeat_tl.
  reflexivity.
Qed.

Lemma length_list_upd: forall `(l: list T) i d,
  Datatypes.length (list_upd l i d) = Datatypes.length l.
Proof.
  induction l; intros; simpl.
  + auto.
  + destruct i.
    replace (d::l) with ([d]++l) by auto.
    apply app_length.
    replace (a :: (list_upd l i d)) with ([a] ++ (list_upd l i d)) by auto.
    rewrite app_length. simpl.
    rewrite IHl; auto.
Qed.

Lemma list_upd_commutes: forall `(l: list T) i0 i1 v0 v1,
    i0 <> i1 ->
    list_upd (list_upd l i0 v0) i1 v1 = list_upd (list_upd l i1 v1) i0 v0.
Proof.
  induction l; intros; auto.
  simpl.
  destruct i0; subst; simpl.
  destruct i1; try congruence.
  simpl; reflexivity.
  destruct i1; simpl.
  reflexivity.
  rewrite IHl; auto.
Qed.

Lemma list_upd_app : forall `(l1 : list T) l2 i v,
  length l1 <= i ->
  list_upd (l1 ++ l2) i v = l1 ++ list_upd l2 (i - length l1) v.
Proof.
  induction l1; simpl; intros.
  - replace (i - 0) with i by omega; auto.
  - destruct i; try omega.
    f_equal.
    simpl.
    eapply IHl1; omega.
Qed.

Theorem nth_error_list_upd_eq :
  forall `(l : list A) n v,
    n < length l ->
    nth_error (list_upd l n v) n = Some v.
Proof.
  induction l; simpl; intros; try omega.
  destruct n; simpl; eauto.
  eapply IHl; omega.
Qed.

Theorem nth_error_list_upd_ne :
  forall `(l : list A) n n' v,
    n <> n' ->
    nth_error (list_upd l n v) n' = nth_error l n'.
Proof.
  induction l; simpl; intros; eauto.
  destruct n; simpl; eauto.
  - destruct n'; eauto; omega.
  - destruct n'; eauto.
Qed.
