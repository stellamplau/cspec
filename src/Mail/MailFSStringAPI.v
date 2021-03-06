Require Import CSPEC.
Require Import MailServerAPI.
Require Import MailFSStringAbsAPI.
Require Import MailFSAPI.

Module MailFSStringOp <: Ops.

  Definition extopT := MailServerAPI.MailServerOp.extopT.

  Inductive xOp : Type -> Type :=
  | CreateTmp : forall (tmpfn : string), xOp bool
  | WriteTmp : forall (tmpfn : string) (data : string), xOp bool
  | LinkMail : forall (tmpfn : string) (mboxfn : string), xOp bool
  | UnlinkTmp : forall (tmpfn : string), xOp unit

  | GetTID : xOp nat
  | Random : xOp nat

  | List : xOp (list string)
  | Read : forall (fn : string), xOp (option string)
  | Delete : forall (fn : string), xOp unit
  | Lock : xOp unit
  | Unlock : xOp unit

  | Ext : forall `(op : extopT T), xOp T
  .

  Definition Op := xOp.

End MailFSStringOp.
Module MailFSStringHOp := HOps MailFSStringOp UserIdx.


Module MailFSStringAPI <: Layer MailFSStringOp MailFSStringAbsState.

  Import MailFSStringOp.
  Import MailFSStringAbsState.

  Inductive xstep : forall T, Op T -> nat -> State -> T -> State -> list event -> Prop :=
  | StepCreateTmpOK : forall tmp mbox tid tmpfn lock,
    xstep (CreateTmp tmpfn) tid
      (mk_state tmp mbox lock)
      true
      (mk_state (FMap.add tmpfn empty_string tmp) mbox lock)
      nil
  | StepCreateTmpErr : forall tmp mbox tid tmpfn lock,
    xstep (CreateTmp tmpfn) tid
      (mk_state tmp mbox lock)
      false
      (mk_state tmp mbox lock)
      nil
  | StepWriteTmpOK : forall tmp mbox tid tmpfn data lock,
    FMap.In tmpfn tmp ->
    xstep (WriteTmp tmpfn data) tid
      (mk_state tmp mbox lock)
      true
      (mk_state (FMap.add tmpfn data tmp) mbox lock)
      nil
  | StepWriteTmpErr1 : forall tmp mbox tid tmpfn data lock,
    xstep (WriteTmp tmpfn data) tid
      (mk_state tmp mbox lock)
      false
      (mk_state tmp mbox lock)
      nil
  | StepWriteTmpErr2 : forall tmp mbox tid tmpfn data data' lock,
    FMap.In tmpfn tmp ->
    xstep (WriteTmp tmpfn data) tid
      (mk_state tmp mbox lock)
      false
      (mk_state (FMap.add tmpfn data' tmp) mbox lock)
      nil
  | StepUnlinkTmp : forall tmp mbox tid tmpfn lock,
    xstep (UnlinkTmp tmpfn) tid
      (mk_state tmp mbox lock)
      tt
      (mk_state (FMap.remove tmpfn tmp) mbox lock)
      nil
  | StepLinkMailOK : forall tmp mbox tid mailfn data tmpfn lock,
    FMap.MapsTo tmpfn data tmp ->
    ~ FMap.In mailfn mbox ->
    xstep (LinkMail tmpfn mailfn) tid
      (mk_state tmp mbox lock)
      true
      (mk_state tmp (FMap.add mailfn data mbox) lock)
      nil
  | StepLinkMailErr : forall tmp mbox tid mailfn tmpfn lock,
    xstep (LinkMail tmpfn mailfn) tid
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

  | StepGetTID : forall tmp mbox tid lock,
    xstep GetTID tid
      (mk_state tmp mbox lock)
      tid
      (mk_state tmp mbox lock)
      nil
  | StepRandom : forall tmp mbox tid r lock,
    xstep Random tid
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

  Definition initP := initP.

End MailFSStringAPI.
Module MailFSStringHAPI := HLayer MailFSStringOp MailFSStringAbsState MailFSStringAPI UserIdx.
