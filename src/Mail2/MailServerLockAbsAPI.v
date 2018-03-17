Require Import POCS.
Require Import String.
Require Import MailServerAPI.


Module MailServerLockAbsAPI <: Layer.

  Import MailServerAPI.

  Record state_rec := mk_state {
    maildir : dir_contents;
    locked : option nat;
  }.

  Definition opT := opT.
  Definition State := state_rec.
  Definition initP (s : State) := True.

  Inductive xstep : forall T, opT T -> nat -> State -> T -> State -> list event -> Prop :=
  | StepDeliver : forall m mbox fn tid lock,
    ~ FMap.In fn mbox ->
    xstep (Deliver m) tid
      (mk_state mbox lock)
      tt
      (mk_state (FMap.add fn m mbox) lock)
      nil
  | StepPickup : forall mbox tid r lock,
    FMap.is_permutation_kv r mbox ->
    xstep Pickup tid
      (mk_state mbox lock)
      r
      (mk_state mbox lock)
      nil
  | StepDelete : forall mbox tid id lock,
    xstep (Delete id) tid
      (mk_state mbox lock)
      tt
      (mk_state (FMap.remove id mbox) lock)
      nil
  | StepGetRequest : forall mbox tid r lock,
    xstep GetRequest tid
      (mk_state mbox lock)
      r
      (mk_state mbox lock)
      (Event r :: nil)
  | StepRespond : forall mbox tid T (v : T) lock,
    xstep (Respond v) tid
      (mk_state mbox lock)
      tt
      (mk_state mbox lock)
      (Event v :: nil)
  .

  Definition step := xstep.

End MailServerLockAbsAPI.