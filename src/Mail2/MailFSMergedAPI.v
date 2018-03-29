Require Import POCS.
Require Import String.
Require Import MailServerAPI.
Require Import MailFSPathAPI.


Module MailFSMergedOp <: Ops.

  Definition extopT := MailServerAPI.MailServerOp.extopT.

  Inductive xopT : Type -> Type :=
  | CreateWrite : forall (fn : string * string * string) (data : string), xopT bool
  | Link : forall (fn : string * string * string) (fn : string * string * string), xopT bool
  | Unlink : forall (fn : string * string * string), xopT unit

  | GetTID : xopT nat
  | Random : xopT nat

  | List : forall (dir : string * string), xopT (list string)
  | Read : forall (fn : string * string * string), xopT (option string)

  | Lock : forall (u : string), xopT unit
  | Unlock : forall (u : string), xopT unit

  | Ext : forall `(op : extopT T), xopT T
  .

  Definition opT := xopT.

End MailFSMergedOp.


Module MailFSMergedState <: State.

  Definition fs_contents := FMap.t (string * string * string) string.
  Definition locked_map := FMap.t string bool.

  Record state_rec := mk_state {
    fs : fs_contents;
    locked : locked_map;
  }.

  Definition State := state_rec.
  Definition initP (s : State) := True.

End MailFSMergedState.


Definition filter_dir (dirname : string * string) (fs : MailFSMergedState.fs_contents) :=
  FMap.filter (fun '(dn, fn) => if dn == dirname then true else false) fs.

Definition drop_dirname (fs : MailFSMergedState.fs_contents) :=
  FMap.map_keys (fun '(dn, fn) => fn) fs.


Module MailFSMergedAPI <: Layer MailFSMergedOp MailFSMergedState.

  Import MailFSMergedOp.
  Import MailFSMergedState.

  Inductive xstep : forall T, opT T -> nat -> State -> T -> State -> list event -> Prop :=
  | StepCreateWriteOK : forall fs tid tmpfn data lock,
    xstep (CreateWrite tmpfn data) tid
      (mk_state fs lock)
      true
      (mk_state (FMap.add tmpfn data fs) lock)
      nil
  | StepCreateWriteErr1 : forall fs tid tmpfn data lock,
    xstep (CreateWrite tmpfn data) tid
      (mk_state fs lock)
      false
      (mk_state fs lock)
      nil
  | StepCreateWriteErr2 : forall fs tid tmpfn data data' lock,
    xstep (CreateWrite tmpfn data) tid
      (mk_state fs lock)
      false
      (mk_state (FMap.add tmpfn data' fs) lock)
      nil
  | StepUnlink : forall fs tid fn lock,
    xstep (Unlink fn) tid
      (mk_state fs lock)
      tt
      (mk_state (FMap.remove fn fs) lock)
      nil
  | StepLinkOK : forall fs tid mailfn data tmpfn lock,
    FMap.MapsTo tmpfn data fs ->
    ~ FMap.In mailfn fs ->
    xstep (Link tmpfn mailfn) tid
      (mk_state fs lock)
      true
      (mk_state (FMap.add mailfn data fs) lock)
      nil
  | StepLinkErr : forall fs tid mailfn tmpfn lock,
    xstep (Link tmpfn mailfn) tid
      (mk_state fs lock)
      false
      (mk_state fs lock)
      nil

  | StepList : forall fs tid r dirname lock,
    FMap.is_permutation_key r (drop_dirname (filter_dir dirname fs)) ->
    xstep (List dirname) tid
      (mk_state fs lock)
      r
      (mk_state fs lock)
      nil

  | StepGetTID : forall s tid,
    xstep GetTID tid
      s
      tid
      s
      nil
  | StepRandom : forall s tid r,
    xstep Random tid
      s
      r
      s
      nil

  | StepReadOK : forall fn fs tid m lock,
    FMap.MapsTo fn m fs ->
    xstep (Read fn) tid
      (mk_state fs lock)
      (Some m)
      (mk_state fs lock)
      nil
  | StepReadNone : forall fn fs tid lock,
    ~ FMap.In fn fs ->
    xstep (Read fn) tid
      (mk_state fs lock)
      None
      (mk_state fs lock)
      nil

  | StepLock : forall fs tid u locked,
    FMap.MapsTo u false locked ->
    xstep (Lock u) tid
      (mk_state fs locked)
      tt
      (mk_state fs (FMap.add u true locked))
      nil
  | StepLockErr : forall fs tid u locked,
    ~ FMap.In u locked ->
    xstep (Lock u) tid
      (mk_state fs locked)
      tt
      (mk_state fs locked)
      nil
  | StepUnlock : forall fs tid u locked,
    xstep (Unlock u) tid
      (mk_state fs locked)
      tt
      (mk_state fs (FMap.add u false locked))
      nil

  | StepExt : forall s tid `(extop : extopT T) r,
    xstep (Ext extop) tid
      s
      r
      s
      (Event (extop, r) :: nil)
  .

  Definition step := xstep.

End MailFSMergedAPI.


Module MailFSMergedAbsAPI <: Layer MailFSPathHOp MailFSMergedState.

  Import MailFSPathOp.
  Import MailFSPathHOp.
  Import MailFSMergedState.

  Inductive xstep : forall T, opT T -> nat -> State -> T -> State -> list event -> Prop :=
  | StepCreateWriteOK : forall fs tid dir fn data lock u,
    xstep (Slice u (CreateWrite (dir, fn) data)) tid
      (mk_state fs lock)
      true
      (mk_state (FMap.add (u, dir, fn) data fs) lock)
      nil
  | StepCreateWriteErr1 : forall fs tid dir fn data lock u,
    xstep (Slice u (CreateWrite (dir, fn) data)) tid
      (mk_state fs lock)
      false
      (mk_state fs lock)
      nil
  | StepCreateWriteErr2 : forall fs tid dir fn data data' lock u,
    xstep (Slice u (CreateWrite (dir, fn) data)) tid
      (mk_state fs lock)
      false
      (mk_state (FMap.add (u, dir, fn) data' fs) lock)
      nil
  | StepUnlink : forall fs tid dir fn lock u,
    xstep (Slice u (Unlink (dir, fn))) tid
      (mk_state fs lock)
      tt
      (mk_state (FMap.remove (u, dir, fn) fs) lock)
      nil
  | StepLinkOK : forall fs tid srcdir srcfn data dstdir dstfn lock u,
    FMap.MapsTo (u, srcdir, srcfn) data fs ->
    ~ FMap.In (u, dstdir, dstfn) fs ->
    xstep (Slice u (Link (srcdir, srcfn) (dstdir, dstfn))) tid
      (mk_state fs lock)
      true
      (mk_state (FMap.add (u, dstdir, dstfn) data fs) lock)
      nil
  | StepLinkErr : forall fs tid srcdir srcfn dstdir dstfn lock u,
    xstep (Slice u (Link (srcdir, srcfn) (dstdir, dstfn))) tid
      (mk_state fs lock)
      false
      (mk_state fs lock)
      nil

  | StepList : forall fs tid r dirname lock u,
    FMap.is_permutation_key r (drop_dirname (filter_dir (u, dirname) fs)) ->
    xstep (Slice u (List dirname)) tid
      (mk_state fs lock)
      r
      (mk_state fs lock)
      nil

  | StepGetTID : forall s tid u,
    xstep (Slice u GetTID) tid
      s
      tid
      s
      nil
  | StepRandom : forall s tid r u,
    xstep (Slice u Random) tid
      s
      r
      s
      nil

  | StepReadOK : forall dir fn fs tid m lock u,
    FMap.MapsTo (u, dir, fn) m fs ->
    xstep (Slice u (Read (dir, fn))) tid
      (mk_state fs lock)
      (Some m)
      (mk_state fs lock)
      nil
  | StepReadNone : forall dir fn fs tid lock u,
    ~ FMap.In (u, dir, fn) fs ->
    xstep (Slice u (Read (dir, fn))) tid
      (mk_state fs lock)
      None
      (mk_state fs lock)
      nil

  | StepLock : forall fs tid u locked,
    FMap.MapsTo u false locked ->
    xstep (Slice u Lock) tid
      (mk_state fs locked)
      tt
      (mk_state fs (FMap.add u true locked))
      nil
  | StepLockErr : forall fs tid u locked,
    ~ FMap.In u locked ->
    xstep (Slice u Lock) tid
      (mk_state fs locked)
      tt
      (mk_state fs locked)
      nil
  | StepUnlock : forall fs tid u locked,
    xstep (Slice u Unlock) tid
      (mk_state fs locked)
      tt
      (mk_state fs (FMap.add u false locked))
      nil

  | StepExt : forall s tid `(extop : extopT T) r u,
    xstep (Slice u (Ext extop)) tid
      s
      r
      s
      (Event (extop, r) :: nil)
  .

  Definition step := xstep.

End MailFSMergedAbsAPI.
