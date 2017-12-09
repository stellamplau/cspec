Require Import Helpers.Helpers.
Require Import Helpers.ListStuff.
Require Import ConcurProc.
Require Import Equiv.
Require Import Omega.
Require Import FunctionalExtensionality.
Require Import Relations.Relation_Operators.
Require Import RelationClasses.
Require Import Morphisms.
Require Import List.
Require Import Compile.

Import ListNotations.

Global Set Implicit Arguments.
Global Generalizable All Variables.


(** Opcodes *)

Inductive opT : Type -> Type :=
| Inc : opT nat
| Dec : opT nat
| Noop : opT unit.

Inductive opHiT : Type -> Type :=
| IncTwice : opHiT nat
| DecThrice : opHiT nat
| Noop2 : opHiT unit.

Inductive opHi2T : Type -> Type :=
.


(** State *)

Definition State := forall (tid : nat), nat.

Definition init_state : State := fun tid' => 4.

Definition inc s tid :=
  state_upd s tid (s tid + 1).

Definition inc2 s tid :=
  state_upd s tid (s tid + 2).

Definition dec s tid :=
  state_upd s tid (s tid - 1).

Definition dec3 s tid :=
  state_upd s tid (s tid - 3).


(** Semantics *)

Inductive op_step : forall T, opT T -> nat -> State -> T -> State -> Prop :=
| StepInc : forall tid s,
  op_step Inc tid s (s tid + 1) (inc s tid)
| StepDec : forall tid s,
  op_step Dec tid s (s tid - 1) (dec s tid)
| StepNoop : forall tid s,
  op_step Noop tid s tt s.

Inductive opHi_step : forall T, opHiT T -> nat -> State -> T -> State -> Prop :=
| StepIncTwice : forall tid s,
  opHi_step IncTwice tid s (s tid + 2) (inc2 s tid)
| StepDecThrice : forall tid s,
  opHi_step DecThrice tid s (s tid - 3) (dec3 s tid)
| StepNoop2 : forall tid s,
  opHi_step Noop2 tid s tt s.


(** Implementations *)

Definition inc_twice_core : proc opT opHiT _ :=
  _ <- Op Inc;
  Op Inc.

Definition dec_thrice_core : proc opT opHiT _ :=
  _ <- Op Dec;
  _ <- Op Dec;
  Op Dec.

Definition compile_op T (op : opHiT T) : proc opT opHiT T :=
  match op with
  | IncTwice => inc_twice_core
  | DecThrice => dec_thrice_core
  | Noop2 => Ret tt
  end.

Definition inc_twice_impl :=
  hicall compile_op IncTwice.

Definition dec_thrice_impl :=
  hicall compile_op DecThrice.

Definition p1 :=
  _ <- inc_twice_impl;
  Ret tt.

Definition ts := threads_empty [[ 1 := Proc p1 ]].


Definition p2 : proc opHiT opHi2T _ :=
  _ <- Op IncTwice;
  Ret tt.

Definition ts2 := threads_empty [[ 1 := Proc p2 ]].



(** Example traces *)

Ltac exec_one tid' :=
  eapply ExecOne with (tid := tid');
    [ rewrite thread_upd_eq; reflexivity | | autorewrite with t ].

Hint Constructors op_step.
Hint Constructors opHi_step.

Definition ex_trace :
  { t : trace opT opHiT | exec op_step init_state ts t }.
Proof.
  eexists.
  unfold ts.
  unfold init_state.
  exec_one 1; eauto 20; simpl; autorewrite with t.
  exec_one 1; eauto 20; simpl; autorewrite with t.
  exec_one 1; eauto 20; simpl; autorewrite with t.
  exec_one 1; eauto 20; simpl; autorewrite with t.
  exec_one 1; eauto 20; simpl; autorewrite with t.
  exec_one 1; eauto 20; simpl; autorewrite with t.
  exec_one 1; eauto 20; simpl; autorewrite with t.
  exec_one 1; eauto 20; simpl; autorewrite with t.
  exec_one 1; eauto 20; simpl; autorewrite with t.
  eapply ExecEmpty; eauto.
Defined.

Eval compute in (proj1_sig ex_trace).


Definition ex_trace2 :
  { t : trace opHiT opHi2T | exec opHi_step init_state ts2 t }.
Proof.
  eexists.
  unfold ts2.
  unfold init_state.
  exec_one 1; eauto; simpl; autorewrite with t.
  exec_one 1; eauto; simpl; autorewrite with t.
  exec_one 1; eauto; simpl; autorewrite with t.
  exec_one 1; eauto; simpl; autorewrite with t.
  eapply ExecEmpty; eauto.
Defined.

Eval compute in (proj1_sig ex_trace2).


Theorem ex_trace_ex_trace2 :
  traces_match (proj1_sig ex_trace) (proj1_sig ex_trace2).
Proof.
  simpl.
  eauto 20.
Qed.


(** Compilation *)

Definition inc2_compile_ok :=
  @compile_ok opT opHiT opHi2T compile_op.

Theorem ex_compile_ok : inc2_compile_ok p1 p2.
Proof.
  unfold p1, p2.
  unfold inc2_compile_ok.
  unfold inc_twice_impl.
  econstructor.
  econstructor.
  econstructor.
Qed.

Hint Resolve ex_compile_ok.


Definition threads_compile_ok (ts1 : @threads_state opT opHiT) (ts2 : @threads_state opHiT opHi2T) :=
  proc_match inc2_compile_ok ts1 ts2.


Opaque hicall Op.

Theorem ex_ts_compile_ok : threads_compile_ok ts ts2.
Proof.
  unfold threads_compile_ok, ts, ts2, thread_upd, threads_empty; intros.
  unfold proc_match. split. cbn. eauto.
  intros.
  destruct tid; subst; compute; eauto 20.
  destruct tid; subst; compute; eauto 20.
  destruct tid; subst; compute; eauto 20.
Qed.

Transparent hicall Op.


Ltac thread_inv :=
  match goal with
  | H : thread_get (thread_upd _ _ _) _ = Proc _ |- _ =>
    eapply thread_upd_inv in H; destruct H; (intuition idtac); subst
  | H : thread_get threads_empty _ = Proc _ |- _ =>
    eapply thread_empty_inv in H; exfalso; apply H
  | H : (_, _) = (_, _) |- _ =>
    inversion H; clear H; subst; repeat sigT_eq
  | H : _ = Bind _ _ |- _ =>
    solve [ inversion H ]
  | H : _ = Ret _ |- _ =>
    solve [ inversion H ]
  | H : no_runnable_threads (thread_upd _ _ _) |- _ =>
    solve [ eapply thread_upd_not_empty in H; exfalso; eauto ]
  | H : _ _ = Proc _ |- _ =>
    solve [ exfalso; eapply no_runnable_threads_some; eauto ]
  | H : _ = _ |- _ =>
    congruence
  | H : _ = _ \/ _ = _ |- _ =>
    solve [ intuition congruence ]
  | H : ?a = ?a |- _ =>
    clear H
  end || maybe_proc_inv.

Ltac bind_inv :=
  match goal with
  | H : _ = Bind _ _ |- _ =>
    inversion H; clear H; subst; repeat sigT_eq
  end.

Ltac exec_inv :=
  match goal with
  | H : exec _ _ _ _ |- _ =>
    inversion H; clear H; subst
  end;
  autorewrite with t in *.

Ltac empty_inv :=
  try solve [ exfalso; eapply thread_empty_inv; eauto ].

Ltac step_inv :=
  match goal with
  | H : op_step _ _ _ _ _ |- _ =>
    inversion H; clear H; subst; repeat sigT_eq
  | H : opHi_step _ _ _ _ _ |- _ =>
    inversion H; clear H; subst; repeat sigT_eq
  end.


Theorem ex_all_traces_match :
  forall s tr1 tr2,
  exec op_step s ts tr1 ->
  exec opHi_step s ts2 tr2 ->
  traces_match tr1 tr2.
Proof.
  intros.
  unfold ts, ts2 in *.

  repeat ( exec_inv; repeat thread_inv;
    try ( repeat exec_tid_inv; repeat thread_inv ) ).
  repeat step_inv.

  unfold inc, state_upd; simpl.
  replace (s' 1 + 1 + 1) with (s' 1 + 2) by omega.
  eauto 20.
Qed.


(** Commutativity *)

Lemma op_step_disjoint_writes :
  disjoint_writes op_step.
Proof.
  unfold disjoint_writes; intros; step_inv.
  + unfold inc, state_upd.
      destruct_ifs; omega.
  + unfold dec, state_upd.
      destruct_ifs; omega.
  + congruence.
Qed.

Lemma op_step_disjoint_reads :
  disjoint_reads op_step.
Proof.
  unfold disjoint_reads; intros; step_inv.
  + unfold inc.
    rewrite state_upd_upd_ne by auto.
    erewrite <- state_upd_ne with (s := s) by eassumption.
    constructor.
  + unfold dec.
    rewrite state_upd_upd_ne by auto.
    erewrite <- state_upd_ne with (s := s) by eassumption.
    constructor.
  + constructor.
Qed.

Hint Resolve op_step_disjoint_writes.
Hint Resolve op_step_disjoint_reads.

Theorem inc_commutes_0 :
  forall T (p1 p2 : _ -> proc opT opHiT T),
  (forall r s tid,
    hitrace_incl_s s s tid op_step (p1 r) (p2 r)) ->
  forall s tid,
  hitrace_incl_s s (inc s tid) tid
    op_step
    (r <- OpExec Inc; p1 r) (p2 (s tid + 1)).
Proof.
  unfold hitrace_incl_s, hitrace_incl_ts_s; intros.

  match goal with
  | H : exec _ _ (thread_upd ?ts ?tid ?p) _ |- _ =>
    remember (thread_upd ts tid p);
    generalize dependent ts;
    induction H0; intros; subst
  end.

  - destruct (tid0 == tid); subst.
    + autorewrite with t in *.
      repeat maybe_proc_inv.
      repeat exec_tid_inv.
      step_inv.
      edestruct H; eauto.

    + edestruct IHexec.
      rewrite thread_upd_upd_ne; eauto.
      intuition idtac.

      eexists; split.
      eapply ExecOne with (tid := tid0).
        autorewrite with t in *; eauto.
        eapply exec_tid_disjoint_reads; eauto.
        rewrite thread_upd_upd_ne; eauto.
        erewrite exec_tid_disjoint_writes with (s := s) (tid1 := tid);
          eauto.
      eauto.

  - exfalso; eauto.
Qed.

Theorem inc_commutes_1 :
  forall `(ap : proc opT opHiT TA)
         `(p1 : proc opT opHiT T')
         (p2 : _ -> proc opT opHiT T'),
  (forall s tid,
    hitrace_incl_s s (inc s tid) tid op_step
      p1 (p2 (s tid + 1))) ->
  hitrace_incl op_step
    (_ <- Atomic ap; p1)
    (r <- Atomic (_ <- ap; Op Inc); p2 r).
Proof.
  unfold hitrace_incl, hitrace_incl_opt,
         hitrace_incl_ts, hitrace_incl_ts_s; intros.

  match goal with
  | H : exec _ _ (thread_upd ?ts ?tid ?p) _ |- _ =>
    remember (thread_upd ts tid p);
    generalize dependent ts;
    induction H0; intros; subst
  end.

  - destruct (tid0 == tid); subst.
    + autorewrite with t in *.
      repeat maybe_proc_inv.
      repeat exec_tid_inv.

      eapply H in H2. deex.

      eexists; split.

      eapply ExecOne with (tid := tid).
        autorewrite with t; eauto.
        eauto 20.
        autorewrite with t; eauto.

      rewrite prepend_app. simpl. eauto.

    + edestruct IHexec.
      rewrite thread_upd_upd_ne; eauto.
      intuition idtac.

      eexists; split.
      eapply ExecOne with (tid := tid0).
        autorewrite with t in *; eauto.
        eauto.
        rewrite thread_upd_upd_ne; auto.
      eauto.
      eauto.

  - exfalso; eauto.
Qed.

Theorem inc_commutes_final :
  forall `(ap : proc _ _ TA) `(p : _ -> proc opT opHiT T'),
  hitrace_incl op_step
    (_ <- Atomic ap; r <- Op Inc; p r)
    (r <- Atomic (_ <- ap; Op Inc); p r).
Proof.
  intros.
  eapply inc_commutes_1.

  intros; unfold Op.
  rewrite exec_equiv_bind_bind.
  setoid_rewrite exec_equiv_bind_bind.
  rewrite hitrace_incl_opcall.
  eapply inc_commutes_0.

  intros.
  rewrite hitrace_incl_opret.
  reflexivity.
Qed.


(** Atomicity *)

Definition p1_a :=
  _ <- Atomic inc_twice_impl;
  Ret tt.

Definition ts_a := threads_empty [[ 1 := Proc p1_a ]].


Theorem ts_equiv_ts_a :
  hitrace_incl_ts op_step ts ts_a.
Proof.
  unfold hitrace_incl_ts, hitrace_incl_ts_s.
  intros.
  unfold ts, ts_a in *.

  repeat ( exec_inv; repeat thread_inv;
    try ( repeat exec_tid_inv; repeat thread_inv ) ).

  repeat step_inv.
  unfold p1_a.

  eexists; split.

  exec_one 1; eauto 20; simpl; autorewrite with t.
  exec_one 1; eauto 20; simpl; autorewrite with t.
  eapply ExecEmpty; eauto.

  reflexivity.
Qed.


Definition inc_twice_impl_atomic :=
  _ <- OpCallHi IncTwice;
  r <- Atomic (_ <- Op Inc; Op Inc);
  OpRetHi r.

Theorem inc_twice_atomic : forall `(rx : _ -> proc _ _ T),
  hitrace_incl op_step
    (Bind inc_twice_impl rx) (Bind inc_twice_impl_atomic rx).
Proof.
  unfold inc_twice_impl, inc_twice_impl_atomic; intros.

  rewrite exec_equiv_bind_bind.
  rewrite exec_equiv_bind_bind with (p1 := OpCallHi _).
  eapply hitrace_incl_bind_a; intros.

  rewrite exec_equiv_bind_bind.
  rewrite exec_equiv_bind_bind with (p1 := Atomic _).
  rewrite hitrace_incl_op.

  setoid_rewrite exec_equiv_bind_bind with (p1 := Op _).
  rewrite inc_commutes_final.
  reflexivity.
Qed.


(** Correctness for 1 thread *)

Definition trace_match_one_thread {opLoT opMidT opHiT State T} lo_step hi_step
                                            (p1 : proc opLoT opMidT T)
                                            (p2 : proc opMidT opHiT T) :=
  forall (s : State) tr1,
    exec lo_step s (threads_empty [[ 1 := Proc p1 ]]) tr1 ->
    exists tr2,
      exec hi_step s (threads_empty [[ 1 := Proc p2 ]]) tr2 /\
      traces_match tr1 tr2.

Instance trace_match_one_thread_proper {opLoT opMidT opHiT State T lo_step hi_step} :
  Proper (exec_equiv ==> exec_equiv ==> Basics.flip Basics.impl)
         (@trace_match_one_thread opLoT opMidT opHiT State T lo_step hi_step).
Proof.
  intros p1 p1'; intros.
  intros p2 p2'; intros.
  unfold Basics.flip, Basics.impl; intros.
  unfold trace_match_one_thread in *; intros.
  apply H in H2.
  apply H1 in H2.
  destruct H2.
  eexists; intuition eauto.
  apply H0. eauto.
Qed.

Instance trace_match_one_thread_proper2 {opLoT opMidT opHiT State T lo_step hi_step} :
  Proper (hitrace_incl lo_step ==> exec_equiv ==> Basics.flip Basics.impl)
         (@trace_match_one_thread opLoT opMidT opHiT State T lo_step hi_step).
Proof.
  intros p1 p1'; intros.
  intros p2 p2'; intros.
  unfold Basics.flip, Basics.impl; intros.
  unfold trace_match_one_thread in *; intros.
  eapply H in H2. deex.
  apply H1 in H2. deex.
  eexists; intuition eauto.
  apply H0. eauto.
  rewrite H3. eauto.
Qed.

Theorem all_single_thread_traces_match' :
  forall T T' (p1 : proc opT opHiT T) (p2 : proc opHiT opHi2T T) (p1rest : T -> proc opT opHiT T') (p2rest : T -> proc opHiT opHi2T T'),
  (forall x, trace_match_one_thread op_step opHi_step (p1rest x) (p2rest x)) ->
  compile_ok p1 p2 ->
  trace_match_one_thread op_step opHi_step (Bind p1 p1rest) (Bind p2 p2rest).
Proof.
  intros.
  generalize dependent p2rest.
  generalize dependent p1rest.
  induction H0; intros.

  - rewrite inc_twice_atomic.

    unfold trace_match_one_thread; intros.

    exec_inv; repeat thread_inv.
    autorewrite with t in *.
    repeat ( exec_tid_inv; intuition try congruence ).

    exec_inv; repeat thread_inv.
    autorewrite with t in *.
    repeat ( exec_tid_inv; intuition try congruence ).

    repeat match goal with
    | H : atomic_exec _ _ _ _ _ _ _ |- _ =>
      inversion H; clear H; subst; repeat sigT_eq
    end.
    repeat step_inv.

    exec_inv; repeat thread_inv.
    autorewrite with t in *.
    repeat ( exec_tid_inv; intuition try congruence ).

    apply H in H3. deex.

    eexists; split.
    eapply ExecOne with (tid := 1).
      rewrite thread_upd_eq; auto.
      eauto.
    eapply ExecOne with (tid := 1).
      rewrite thread_upd_eq; auto.
      eauto.
    eapply ExecOne with (tid := 1).
      rewrite thread_upd_eq; auto.
      eauto.
    autorewrite with t.

    match goal with
    | H : exec _ ?s1 (thread_upd _ _ (Proc ?p1)) _ |-
          exec _ ?s2 (thread_upd _ _ (Proc ?p2)) _ =>
      replace p2 with p1; [ replace s2 with s1; [ eauto | ] | ]
    end.

    unfold inc, inc2, state_upd; apply functional_extensionality; intros.
      destruct_ifs; omega.
    f_equal.
    unfold inc, inc2, state_upd;
      destruct_ifs; omega.

    simpl.
    replace (inc s1 1 1 + 1) with (s1 1 + 2).
    eauto 20.
    unfold inc, state_upd. destruct_ifs; omega.

  - unfold trace_match_one_thread in *; intros.

    exec_inv; repeat thread_inv; autorewrite with t in *.
    repeat exec_tid_inv; try intuition congruence.

    edestruct H; eauto. intuition try congruence.
    eexists. split.

    exec_one 1.
      eapply ExecTidBind. eauto. eauto.
      autorewrite with t; simpl.

    eauto.

  - rewrite exec_equiv_bind_bind.
    rewrite exec_equiv_bind_bind.
    eapply IHcompile_ok.
    intros.
    eapply H1.
    eapply H2.
Qed.

Theorem all_single_thread_traces_match :
  forall T' (p1 : proc opT opHiT T') (p2 : proc opHiT opHi2T T'),
  compile_ok p1 p2 ->
  trace_match_one_thread op_step opHi_step p1 p2.
Proof.
  intros.
  unfold trace_match_one_thread; intros.
  eapply exec_equiv_bind_ret in H0.
  eapply all_single_thread_traces_match' in H0; eauto.
  deex.
  eexists; split; eauto.
  eapply exec_equiv_bind_ret.
  eauto.

  clear H0.
  unfold trace_match_one_thread; intros.
  eapply exec_equiv_ret_None in H0.
  exec_inv; repeat thread_inv.

  eexists; split.
  eapply exec_equiv_ret_None.
  eapply ExecEmpty; eauto.

  eauto.
Qed.


(** Many-thread correctness *)

Inductive compile_ok_atomic : forall T (p1 : proc opT opHiT T) (p2 : proc opHiT opHi2T T), Prop :=
| CompileAIncTwiceCall :
  compile_ok_atomic (OpCallHi IncTwice) (OpCall IncTwice)
| CompileAIncTwiceExec :
  compile_ok_atomic (Atomic (_ <- Op Inc; Op Inc)) (OpExec IncTwice)
| CompileAIncTwiceRet : forall `(r : T),
  compile_ok_atomic (OpRetHi r) (OpRet r)
| CompileARet : forall `(x : T),
  compile_ok_atomic (Ret x) (Ret x)
| CompileABind : forall `(p1a : proc opT opHiT T1) (p2a : proc opHiT opHi2T T1)
                        `(p1b : T1 -> proc opT opHiT T2) (p2b : T1 -> proc opHiT opHi2T T2),
  compile_ok_atomic p1a p2a ->
  (forall x, compile_ok_atomic (p1b x) (p2b x)) ->
  compile_ok_atomic (Bind p1a p1b) (Bind p2a p2b).

Definition compile_ok_all_atomic (ts1 ts2 : threads_state) :=
  proc_match compile_ok_atomic ts1 ts2.

Lemma compile_ok_atomic_exec_tid : forall T (p1 : proc _ _ T) p2,
  compile_ok_atomic p1 p2 ->
  forall tid s s' result evs,
  exec_tid op_step tid s p1 s' result evs ->
  exists result' evs',
  exec_tid opHi_step tid s p2 s' result' evs' /\
  traces_match (prepend tid evs TraceEmpty) (prepend tid evs' TraceEmpty) /\
  match result with
  | inl v => match result' with
    | inl v' => v = v'
    | inr _ => False
    end
  | inr p' => match result' with
    | inl _ => False
    | inr p'' => compile_ok_atomic p' p''
    end
  end.
Proof.
  induction 1; intros.

  - exec_tid_inv.
    do 2 eexists; split.
    constructor.
    split.
    simpl; eauto.
    eauto.

  - exec_tid_inv.
    repeat match goal with
    | H : atomic_exec _ _ _ _ _ _ _ |- _ =>
      inversion H; clear H; subst; repeat sigT_eq
    end.
    repeat step_inv.
    do 2 eexists; split.
    constructor.

    replace (inc (inc s1 tid) tid) with (inc2 s1 tid).
    constructor.

    unfold inc, inc2, state_upd; apply functional_extensionality; intros.
      destruct_ifs; omega.

    split.
    simpl; eauto.

    unfold inc, inc2, state_upd;
      destruct_ifs; omega.

  - exec_tid_inv.
    do 2 eexists; split.
    constructor.
    split.
    simpl; eauto.
    eauto.

  - exec_tid_inv.
    do 2 eexists; split.
    constructor.
    split.
    simpl; eauto.
    eauto.

  - exec_tid_inv.
    eapply IHcompile_ok_atomic in H12.
    repeat deex.

    destruct result0; destruct result'; try solve [ exfalso; eauto ].

    + do 2 eexists; split.
      eauto.
      split.
      eauto.
      subst; eauto.

    + do 2 eexists; split.
      eauto.
      split.
      eauto.
      constructor.
      eauto.
      eauto.
Qed.

Theorem all_traces_match_0 :
  forall ts1 ts2,
  compile_ok_all_atomic ts1 ts2 ->
  traces_match_ts op_step opHi_step ts1 ts2.
Proof.
  unfold traces_match_ts; intros.
  generalize dependent ts3.
  induction H0; intros.
  - eapply proc_match_pick with (tid := tid) in H2 as H'.
    intuition try congruence.
    repeat deex.
    rewrite H3 in H; inversion H; clear H; subst.
    repeat maybe_proc_inv.

    edestruct compile_ok_atomic_exec_tid; eauto.
    repeat deex.

    edestruct IHexec.
    shelve.
    intuition idtac.

    eexists; split.
    eapply ExecOne with (tid := tid).
      eauto.
      eauto.
      eauto.

    eapply traces_match_prepend; eauto.
    Unshelve.

    destruct result, x; simpl in *; try solve [ exfalso; eauto ].
    eapply proc_match_del; eauto.
    eapply proc_match_upd; eauto.

  - eexists; split.
    eapply ExecEmpty.
    2: eauto.

    unfold compile_ok_all_atomic in *.
    eauto.
Qed.

Inductive atomize_ok : forall T (p1 : proc opT opHiT T) (p2 : proc opT opHiT T), Prop :=
| AtomizeIncTwice :
  atomize_ok (inc_twice_impl) (inc_twice_impl_atomic)
| AtomizeRet : forall T (x : T),
  atomize_ok (Ret x) (Ret x)
| AtomizeBind : forall T1 T2 (p1a p2a : proc opT opHiT T1)
                             (p1b p2b : T1 -> proc opT opHiT T2),
  atomize_ok p1a p2a ->
  (forall x, atomize_ok (p1b x) (p2b x)) ->
  atomize_ok (Bind p1a p1b) (Bind p2a p2b).

Definition atomize_ok_all (ts1 ts2 : threads_state) :=
  proc_match atomize_ok ts1 ts2.

Definition compile_ok_all (ts1 ts2 : threads_state) :=
  proc_match compile_ok ts1 ts2.

Fixpoint compile_atomic T (p : proc opHiT opHi2T T) : proc opT opHiT T :=
  match p with
  | Ret t => Ret t
  | OpCall op => OpCallHi op
  | OpExec op =>
    match op with
    | IncTwice => Atomic (_ <- Op Inc; Op Inc)
    | Noop2 => Atomic (Ret tt)
    end
  | OpRet r => OpRetHi r
  | Bind p1 p2 =>
    Bind (compile_atomic p1) (fun r => compile_atomic (p2 r))
  | OpCallHi _ => Ret tt
  | OpRetHi v => Ret v
  | Atomic p => Atomic (compile_atomic p)
  end.

Definition atomize_ok_all_upto n (ts1 ts2 : threads_state) :=
  proc_match_upto n atomize_ok ts1 ts2.


Theorem atomize_ok_preserves_trace_0 :
  forall T p1 p2,
  atomize_ok p1 p2 ->
  forall T' (p1rest p2rest : T -> proc _ _ T'),
  (forall x, hitrace_incl op_step (p1rest x) (p2rest x)) ->
  hitrace_incl op_step (Bind p1 p1rest) (Bind p2 p2rest).
Proof.
  induction 1; intros.
  - rewrite inc_twice_atomic.
    eapply hitrace_incl_bind_a.
    eauto.
  - eapply hitrace_incl_bind_a.
    eauto.
  - rewrite exec_equiv_bind_bind.
    rewrite exec_equiv_bind_bind.
    eapply IHatomize_ok.
    eauto.
Qed.

Theorem atomize_ok_preserves_trace :
  forall `(p1 : proc _ _ T) p2,
  atomize_ok p1 p2 ->
  hitrace_incl op_step p1 p2.
Proof.
  intros.
  rewrite <- exec_equiv_bind_ret.
  rewrite <- exec_equiv_bind_ret with (p := p4).
  eapply atomize_ok_preserves_trace_0; eauto.
  reflexivity.
Qed.

Theorem atomize_ok_all_upto_preserves_trace :
  forall n ts1' ts1,
  atomize_ok_all_upto n ts1 ts1' ->
    hitrace_incl_ts op_step ts1 ts1'.
Proof.
  induction n; intros.
  - apply proc_match_upto_0_eq in H; subst.
    reflexivity.
  - destruct (lt_dec n (length ts1)).
    + etransitivity.
      instantiate (1 := thread_upd ts1' n (thread_get ts1 n)).
      * eapply IHn.
        eapply proc_match_upto_Sn in H; eauto.
      * eapply proc_match_upto_pick with (tid := n) in H; intuition idtac.
        edestruct H0. omega.
       -- intuition idtac.
          rewrite H2.
          rewrite <- exec_equiv_ts_upd_same; eauto.
          reflexivity.
       -- repeat deex.
          rewrite H.
          rewrite atomize_ok_preserves_trace; eauto.
          rewrite thread_upd_same; eauto.
          reflexivity.
    + eapply IHn.
      eapply proc_match_upto_Sn'.
      omega.
      eauto.
Qed.

Theorem atomize_ok_all_preserves_trace :
  forall ts1' ts1,
  atomize_ok_all ts1 ts1' ->
    hitrace_incl_ts op_step ts1 ts1'.
Proof.
  intros.
  eapply atomize_ok_all_upto_preserves_trace.
  eapply proc_match_upto_all.
  eauto.
Qed.

Theorem all_traces_match_1 :
  forall ts1 ts1' ts2,
  atomize_ok_all ts1 ts1' ->
  compile_ok_all_atomic ts1' ts2 ->
  traces_match_ts op_step opHi_step ts1 ts2.
Proof.
  intros.
  rewrite atomize_ok_all_preserves_trace; eauto.
  eapply all_traces_match_0; eauto.
Qed.

Theorem make_one_atomic :
  forall T p2 (p1 : proc _ _ T),
  compile_ok p1 p2 ->
    atomize_ok p1 (compile_atomic p2) /\
    compile_ok_atomic (compile_atomic p2) p2.
Proof.
  induction 1; simpl; intros.
  - split. constructor. repeat constructor.
  - split; constructor.
  - intuition idtac.
    constructor. eauto. intros. specialize (H1 x). intuition eauto.
    constructor. eauto. intros. specialize (H1 x). intuition eauto.
Qed.

Lemma atomize_ok_cons : forall T (p1 : proc _ _ T) p2 ts1 ts2,
  atomize_ok_all ts1 ts2 ->
  atomize_ok p1 p2 ->
  atomize_ok_all (Proc p1 :: ts1) (Proc p2 :: ts2).
Proof.
  intros.
  eapply proc_match_cons_Proc; eauto.
Qed.

Lemma atomize_ok_cons_None : forall ts1 ts2,
  atomize_ok_all ts1 ts2 ->
  atomize_ok_all (NoProc :: ts1) (NoProc :: ts2).
Proof.
  intros.
  eapply proc_match_cons_NoProc; eauto.
Qed.

Lemma compile_ok_atomic_cons : forall T (p1 : proc _ _ T) p2 ts1 ts2,
  compile_ok_all_atomic ts1 ts2 ->
  compile_ok_atomic p1 p2 ->
  compile_ok_all_atomic (Proc p1 :: ts1) (Proc p2 :: ts2).
Proof.
  intros.
  eapply proc_match_cons_Proc; eauto.
Qed.

Lemma compile_ok_atomic_cons_None : forall ts1 ts2,
  compile_ok_all_atomic ts1 ts2 ->
  compile_ok_all_atomic (NoProc :: ts1) (NoProc :: ts2).
Proof.
  intros.
  eapply proc_match_cons_NoProc; eauto.
Qed.

Hint Resolve atomize_ok_cons.
Hint Resolve atomize_ok_cons_None.
Hint Resolve compile_ok_atomic_cons.
Hint Resolve compile_ok_atomic_cons_None.


Theorem make_all_atomic :
  forall ts1 ts2,
  compile_ok_all ts1 ts2 ->
  exists ts1',
    atomize_ok_all ts1 ts1' /\
    compile_ok_all_atomic ts1' ts2.
Proof.
  induction ts1; intros.
  - eapply proc_match_len in H.
    destruct ts3; simpl in *; try omega.
    eexists; split.
    eapply proc_match_nil.
    eapply proc_match_nil.
  - eapply proc_match_len in H as H'.
    destruct ts3; simpl in *; try omega.

    eapply proc_match_cons_inv in H.
    edestruct IHts1; intuition eauto.
    + exists (NoProc :: x); subst; intuition eauto.
    + repeat deex.
      edestruct (make_one_atomic H4).
      eexists (Proc _ :: x); intuition eauto.
Qed.

Theorem all_traces_match :
  forall ts1 ts2,
  compile_ok_all ts1 ts2 ->
  traces_match_ts op_step opHi_step ts1 ts2.
Proof.
  intros.
  eapply make_all_atomic in H; deex.
  eapply all_traces_match_1; eauto.
Qed.