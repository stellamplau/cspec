Require Import POCS.
Require Import MailServerAPI.
Require Import MailFSStringAbsAPI.
Require Import MailboxTmpAbsAPI.

Module TryDeliverOp <: Ops.

  Definition extopT := MailServerAPI.MailServerOp.extopT.

  Inductive xopT : Type -> Type :=
  | CreateWriteTmp : forall (data : string), xopT bool
  | LinkMail : xopT bool
  | UnlinkTmp : xopT unit

  | List : xopT (list (nat * nat))
  | Read : forall (fn : nat * nat), xopT (option string)
  | Delete : forall (fn : nat * nat), xopT unit
  | Lock : xopT unit
  | Unlock : xopT unit

  | Ext : forall `(op : extopT T), xopT T
  .

  Definition opT := xopT.

End TryDeliverOp.
Module TryDeliverHOp := HOps TryDeliverOp UserIdx.


Module TryDeliverAPI <: Layer TryDeliverOp MailboxTmpAbsState.

  Import TryDeliverOp.
  Import MailboxTmpAbsState.

  Inductive xstep : forall T, opT T -> nat -> State -> T -> State -> list event -> Prop :=
  | StepCreateWriteTmpOK : forall tmp mbox tid data lock,
    xstep (CreateWriteTmp data) tid
      (mk_state tmp mbox lock)
      true
      (mk_state (FMap.add (tid, 0) data tmp) mbox lock)
      nil
  | StepCreateWriteTmpErr1 : forall tmp mbox tid data lock,
    xstep (CreateWriteTmp data) tid
      (mk_state tmp mbox lock)
      false
      (mk_state tmp mbox lock)
      nil
  | StepCreateWriteTmpErr2 : forall tmp mbox tid data data' lock,
    xstep (CreateWriteTmp data) tid
      (mk_state tmp mbox lock)
      false
      (mk_state (FMap.add (tid, 0) data' tmp) mbox lock)
      nil
  | StepUnlinkTmp : forall tmp mbox tid lock,
    xstep (UnlinkTmp) tid
      (mk_state tmp mbox lock)
      tt
      (mk_state (FMap.remove (tid, 0) tmp) mbox lock)
      nil
  | StepLinkMailOK : forall tmp mbox tid mailfn data lock,
    FMap.MapsTo (tid, 0) data tmp ->
    ~ FMap.In (tid, mailfn) mbox ->
    xstep (LinkMail) tid
      (mk_state tmp mbox lock)
      true
      (mk_state tmp (FMap.add (tid, mailfn) data mbox) lock)
      nil
  | StepLinkMailRetry : forall tmp mbox tid lock,
    xstep (LinkMail) tid
      (mk_state tmp mbox lock)
      false
      (mk_state tmp mbox lock)
      nil

  | StepList : forall tmp mbox tid r lock,
    FMap.is_permutation_key r mbox ->
    xstep List tid
      (mk_state tmp mbox lock)
      r
      (mk_state tmp mbox lock)
      nil

  | StepReadOK : forall fn tmp mbox tid m lock,
    FMap.MapsTo fn m mbox ->
    xstep (Read fn) tid
      (mk_state tmp mbox lock)
      (Some m)
      (mk_state tmp mbox lock)
      nil
  | StepReadNone : forall fn tmp mbox tid lock,
    ~ FMap.In fn mbox ->
    xstep (Read fn) tid
      (mk_state tmp mbox lock)
      None
      (mk_state tmp mbox lock)
      nil

  | StepDelete : forall fn tmp mbox tid lock,
    xstep (Delete fn) tid
      (mk_state tmp mbox lock)
      tt
      (mk_state tmp (FMap.remove fn mbox) lock)
      nil

  | StepLock : forall tmp mbox tid,
    xstep Lock tid
      (mk_state tmp mbox false)
      tt
      (mk_state tmp mbox true)
      nil
  | StepUnlock : forall tmp mbox tid lock,
    xstep Unlock tid
      (mk_state tmp mbox lock)
      tt
      (mk_state tmp mbox false)
      nil

  | StepExt : forall s tid `(extop : extopT T) r,
    xstep (Ext extop) tid
      s
      r
      s
      (Event (extop, r) :: nil)
  .

  Definition step := xstep.

End TryDeliverAPI.
Module TryDeliverHAPI := HLayer TryDeliverOp MailboxTmpAbsState TryDeliverAPI UserIdx.