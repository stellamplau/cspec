Require Import POCS.
Require Import String.
Require Import MailboxAPI.
Require Import TryDeliverAPI.
Require Import MailFSAPI.
Require Import MailboxTmpAbsAPI.


Module TryDeliverImpl' <:
  LayerImplMoversT
    MailboxTmpAbsState
    MailFSOp     MailFSAPI
    TryDeliverOp TryDeliverAPI.

  Definition linkmail_core :=
    ts <- Op MailFSOp.Random;
    ok <- Op (MailFSOp.LinkMail ts);
    Ret ok.

  Definition compile_op T (op : TryDeliverOp.opT T) : proc MailFSOp.opT T :=
    match op with
    | TryDeliverOp.CreateWriteTmp data => Op (MailFSOp.CreateWriteTmp data)
    | TryDeliverOp.LinkMail => linkmail_core
    | TryDeliverOp.UnlinkTmp => Op (MailFSOp.UnlinkTmp)
    | TryDeliverOp.List => Op (MailFSOp.List)
    | TryDeliverOp.Read fn => Op (MailFSOp.Read fn)
    | TryDeliverOp.Delete fn => Op (MailFSOp.Delete fn)
    | TryDeliverOp.Lock => Op (MailFSOp.Lock)
    | TryDeliverOp.Unlock => Op (MailFSOp.Unlock)
    | TryDeliverOp.Ext extop => Op (MailFSOp.Ext extop)
    end.

  Theorem compile_op_no_atomics :
    forall `(op : _ T),
      no_atomics (compile_op op).
  Proof.
    destruct op; compute; eauto.
  Qed.

  Ltac step_inv :=
    match goal with
    | H : TryDeliverAPI.step _ _ _ _ _ _ |- _ =>
      inversion H; clear H; subst; repeat sigT_eq
    | H : MailFSAPI.step _ _ _ _ _ _ |- _ =>
      inversion H; clear H; subst; repeat sigT_eq
    end; intuition idtac.

  Hint Extern 1 (TryDeliverAPI.step _ _ _ _ _ _) => econstructor.
  Hint Extern 1 (MailFSAPI.step _ _ _ _ _ _) => econstructor.

  Lemma random_right_mover :
    right_mover
      MailFSAPI.step
      (MailFSOp.Random).
  Proof.
    unfold right_mover; intros.
    repeat step_inv; eauto 10.

    eexists; split; econstructor.
  Qed.

  Hint Resolve random_right_mover.

  Theorem ysa_movers_linkmail_core :
    ysa_movers MailFSAPI.step linkmail_core.
  Proof.
    econstructor; eauto 20.
  Qed.

  Hint Resolve ysa_movers_linkmail_core.

  Theorem ysa_movers : forall `(op : _ T),
    ysa_movers MailFSAPI.step (compile_op op).
  Proof.
    destruct op; simpl; eauto 20.
  Qed.

  Theorem compile_correct :
    compile_correct compile_op MailFSAPI.step TryDeliverAPI.step.
  Proof.
    unfold compile_correct; intros.
    destruct op.

    all: repeat atomic_exec_inv; repeat step_inv; eauto.
  Qed.

End TryDeliverImpl'.


Module TryDeliverImpl :=
  LayerImplMovers
    MailboxTmpAbsState
    MailFSOp     MailFSAPI
    TryDeliverOp TryDeliverAPI
    TryDeliverImpl'.
