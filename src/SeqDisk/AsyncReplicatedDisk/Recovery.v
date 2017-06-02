Require Import Automation.
Require Import Disk.AsyncDisk.

Require Import Refinement.Interface.
Require Import Refinement.ProgLang.Prog.
Require Import Refinement.ProgLang.Hoare.
Require Import
        TwoDisk.AsyncTwoDiskAPI
        TwoDisk.AsyncTwoDiskTheorems
        TwoDisk.TwoDiskFacts.

Require Import
        SeqDisk.AsyncReplicatedDisk.Step
        SeqDisk.AsyncReplicatedDisk.DiskSize.

Require Import MaybeHolds.

Section AsyncReplicatedDisk.

    Variable (td:Interface TD.API).

    (* Recovery tracks what happens at each step in order to implement control
       flow. *)
    Inductive RecStatus :=
    (* continue working, nothing interesting has happened *)
    | Continue
    (* one of the disks has failed, so don't bother continuing recovery since the
       invariant is now trivially satisfied *)
    | DiskFailed (i:diskId).

    Definition fixup (a:addr) : prog RecStatus :=
      mv0 <- Prim td (TD.Read d0 a);
        match mv0 with
        | Working v => mv2 <- Prim td (TD.Read d1 a);
                        match mv2 with
                        | Working v' => if v == v' then
                                         Ret Continue
                                       else
                                         mu <- Prim td (TD.Write d1 a v);
                                         Ret (match mu with
                                              | Working _ => Continue
                                              | Failed => DiskFailed d1
                                              end)
                        | Failed => Ret (DiskFailed d1)
                        end
        | Failed => Ret (DiskFailed d0)
        end.

    (* recursively performs recovery at [a-1], [a-2], down to 0 *)
    Fixpoint recover_at (a:addr) : prog RecStatus :=
      match a with
      | 0 => Ret Continue
      | S n => s <- fixup n;
                match s with
                | Continue => recover_at n
                | DiskFailed i => Ret (DiskFailed i)
                end
      end.

    Definition Recover : prog unit :=
      sz <- DiskSize td;
        _ <- recover_at sz;
        _ <- Prim td (TD.Sync d1);
        Ret tt.

    (* crashesTo_one_of d_0 d_1 d says [forall a, d_0(a) ~> d(a) \/ d_1(a) ~> d(a)]
    where [h ~> h'] is made-up notation for h crashing to the current value in
    h' (with any set of durable writes in h').

     This isn't a pointwise_rel, unfortunately, since it covers three disks. *)
    Record crashesTo_one_of (d_0 d_1 d:histdisk) : Prop :=
      { crashesTo_one_size0 : size d_0 = size d;
        crashesTo_one_size1 : size d_1 = size d;
        crashesTo_one_pointwise : forall a,
            match d_0 a, d_1 a, d a with
            | Some h0, Some h1, Some h => durable_vals h0 (curr_val h) \/
                                         durable_vals h1 (curr_val h)
            | None, None, None => True
            | _, _, _ => False
            end;
      }.

    Definition Recover_spec :=
      (fun '(d_0, d_1) state =>
         {|
           pre :=
             TD.disk0 state |= crashesTo d_0 /\
             TD.disk1 state |= crashesTo d_1;
           post :=
             fun (_:unit) state' =>
               exists d,
                 TD.disk0 state' |= crashesTo d /\
                 TD.disk1 state' |= crashesTo d /\
                 crashesTo_one_of d_0 d_1 d /\
                 histdisk_flushed d;
           recover :=
             fun (_:unit) state' =>
               (* either disk could change due to failures *)
               exists d_0' d_1',
                 TD.disk0 state' |= crashesTo d_0' /\
                 TD.disk1 state' |= crashesTo d_1' /\
                 crashesTo_one_of d_0 d_1 d_0' /\
                 crashesTo_one_of d_0 d_1 d_1' /\
                 histdisk_flushed d_0' /\
                 histdisk_flushed d_1';
         |}).

    Theorem Recover_rok :
      prog_spec
        Recover_spec
        (Recover)
        (irec td)
        (refinement td).
    Proof.
    Admitted.

    Lemma histblock_trans : forall h h',
        durable_vals h (curr_val h') ->
        hist_flushed h' ->
        forall h'', durable_vals h' (curr_val h'') ->
               durable_vals h (curr_val h'').
    Proof.
      unfold hist_flushed; intros.
      rewrite H0 in *.
      inversion H1; auto.
    Qed.

    Hint Resolve histblock_trans.

    Lemma crashesTo_one_of_trans:
      forall d_0 d_1 d_0' d_1' : histdisk,
        crashesTo_one_of d_0 d_1 d_0' ->
        crashesTo_one_of d_0 d_1 d_1' ->
        histdisk_flushed d_0' ->
        histdisk_flushed d_1' ->
        forall d' : histdisk,
          crashesTo_one_of d_0' d_1' d' ->
          crashesTo_one_of d_0 d_1 d'.
    Proof.
      intros.
      repeat match goal with
             | [ H: histdisk_flushed _ |- _ ] => destruct H
             | [ H: crashesTo_one_of _ _ _ |- _ ] => destruct H
             end.
      econstructor; intros; try congruence.
      repeat match goal with
             | [ H: forall (_:addr), _ |- _ ] =>
               specialize (H a)
             end.
      destruct matches in *; intuition subst; eauto.
    Qed.

    Hint Resolve crashesTo_one_of_trans.

    Theorem Recover_ok :
      prog_loopspec
        Recover_spec
        (Recover)
        (irec td)
        (refinement td).
    Proof.
      eapply idempotent_loopspec; simpl.
      - eapply Recover_rok.
      - unfold idempotent; intuition; simplify.
        descend; intuition eauto.
        repeat deex.
        descend; intuition eauto.
    Qed.

End AsyncReplicatedDisk.
