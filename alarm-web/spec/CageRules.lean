namespace CageRules

inductive ArtifactOrigin where
  | externalFetched
  | localGenerated
  | placeholderStub
  | absent
deriving DecidableEq, Repr

inductive SourceChannel where
  | openNetworkFetch
  | localFabrication
deriving DecidableEq, Repr

inductive GrantStatus where
  | verifiedRedistributable
  | unverified
deriving DecidableEq, Repr

structure BuilderState where
  manifestPresent : Bool
  typeConfigPresent : Bool
  modularSources : Nat
  testsPass : Bool
  bundleEmitted : Bool
  assetOrigin : ArtifactOrigin
  assetChannel : SourceChannel
  assetGrant : GrantStatus
  assetCount : Nat
  provenanceLogged : Bool
  directExecution : Bool
deriving DecidableEq, Repr

def originAccepted (o : ArtifactOrigin) : Bool :=
  match o with
  | ArtifactOrigin.externalFetched => true
  | _ => false

def channelAccepted (c : SourceChannel) : Bool :=
  match c with
  | SourceChannel.openNetworkFetch => true
  | _ => false

def grantAccepted (g : GrantStatus) : Bool :=
  match g with
  | GrantStatus.verifiedRedistributable => true
  | _ => false

def validBuilderState (s : BuilderState) : Bool :=
  s.manifestPresent && s.typeConfigPresent && Nat.ble 8 s.modularSources && s.testsPass && s.bundleEmitted && originAccepted s.assetOrigin && channelAccepted s.assetChannel && grantAccepted s.assetGrant && Nat.ble 4 s.assetCount && s.provenanceLogged && s.directExecution

def referenceState : BuilderState :=
  { manifestPresent := true, typeConfigPresent := true, modularSources := 10, testsPass := true, bundleEmitted := true, assetOrigin := ArtifactOrigin.externalFetched, assetChannel := SourceChannel.openNetworkFetch, assetGrant := GrantStatus.verifiedRedistributable, assetCount := 4, provenanceLogged := true, directExecution := true }

def valid_ref_prop : Prop :=
  validBuilderState referenceState = true

def reject_fabricated_prop : Prop :=
  validBuilderState { referenceState with assetOrigin := ArtifactOrigin.localGenerated } = false

def reject_stub_prop : Prop :=
  validBuilderState { referenceState with assetOrigin := ArtifactOrigin.placeholderStub } = false

def reject_local_channel_prop : Prop :=
  validBuilderState { referenceState with assetChannel := SourceChannel.localFabrication } = false

theorem valid_ref : valid_ref_prop := by
  unfold valid_ref_prop
  decide

theorem reject_fabricated : reject_fabricated_prop := by
  unfold reject_fabricated_prop
  decide

theorem reject_stub : reject_stub_prop := by
  unfold reject_stub_prop
  decide

theorem reject_local_channel : reject_local_channel_prop := by
  unfold reject_local_channel_prop
  decide

end CageRules
