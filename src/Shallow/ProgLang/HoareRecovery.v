Require Import Automation.
Require Import Prog.
Require Import ProgTheorems.
Require Import Hoare.

Set Implicit Arguments.

Record RecQuadruple T R State :=
  RecSpec {
      rec_pre: Prop;
      rec_post: T -> State -> Prop;
      recover_post: R -> State -> Prop;
    }.

Definition RecSpecification A T R State := A -> State -> RecQuadruple T R State.

Definition prog_rspec `(spec: RecSpecification A T R State) `(p: prog opT T) `(rec: prog opT R)
           `(step: Semantics opT State) :=
  forall a state,
    rec_pre (spec a state) ->
    forall r, rexec step p rec state r ->
         match r with
         | RFinished v state' => rec_post (spec a state) v state'
         | Recovered v state' => recover_post (spec a state) v state'
         end.

Definition prog_loopspec
           `(spec: Specification A R State)
           `(rec: prog opT R)
           `(step: Semantics opT State) :=
  forall a state, pre (spec a state) ->
         forall rv state', exec_recover step rec state rv state' ->
                  post (spec a state) rv state'.

Definition idempotent `(spec: Specification A R State) :=
  (* idempotency: crash invariant implies precondition to re-run on every
  crash *)
  (forall a state, pre (spec a state) ->
          forall state', crash (spec a state) state' ->
                pre (spec a state')) /\
  (* postcondition transitivity: establishing the postcondition from a crash
  state is sufficient to establish it with respect to the original initial state
  (note all with the same ghost state) *)
  (forall a state,
      pre (spec a state) ->
      forall state' rv state'',
        crash (spec a state) state' ->
        post (spec a state') rv state'' ->
        post (spec a state) rv state'').

Lemma exec_recover_idempotent : forall `(spec: Specification A R State)
                                  `(rec: prog opT R)
                                  `(step: Semantics opT State),
    forall (Hspec: prog_spec spec rec step),
      idempotent spec ->
      prog_loopspec spec rec step.
Proof.
  unfold idempotent, prog_loopspec; intuition.
  induction H2.
  - eapply Hspec in H2; eauto.
  - eapply Hspec in H2; eauto.
Qed.

Theorem prog_spec_from_crash : forall `(spec: RecSpecification A T R State)
                                 `(p: prog opT T) `(rec: prog opT R)
                                 (step: Semantics opT State)
                                 `(pspec: Specification A1 T State)
                                 `(rspec: Specification A2 R State),
    forall (Hpspec: prog_spec pspec p step)
      (Hrspec: prog_spec rspec rec step),
      idempotent rspec ->
      (forall a state, rec_pre (spec a state) ->
              (* program's precondition holds *)
              exists a1, pre (pspec a1 state) /\
                    (* within same ghost state, normal postcondition is correct *)
                    (forall v state', post (pspec a1 state) v state' ->
                             rec_post (spec a state) v state') /\
                    (* crash invariant allows running recovery *)
                    (forall state', crash (pspec a1 state) state' ->
                           exists a2, pre (rspec a2 state') /\
                                 (* and recovery establishes recovery postcondition *)
                                 (forall rv state'', post (rspec a2 state') rv state'' ->
                                                recover_post (spec a state) rv state'') /\
                                 (forall state'', crash (rspec a2 state') state'' ->
                                             pre (rspec a2 state'')))) ->
      prog_rspec spec p rec step.
Proof.
  unfold prog_rspec; intros.
  inversion H2; subst.
  - eapply H0 in H1; eauto.
    deex.
    eapply Hpspec in H3; eauto.
  - eapply H0 in H1; eauto.
    deex.
    eapply Hpspec in H3; eauto.
    eapply H6 in H3.
    deex.
    eapply exec_recover_idempotent in H4; eauto.
Qed.
