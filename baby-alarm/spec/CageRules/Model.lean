namespace CageRules

inductive ArtifactOrigin where
  | externalFetched
  | localGenerated
  | placeholderStub
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
  assetGrant : GrantStatus
  assetCount : Nat
  categoryCount : Nat
  interactiveChallenges : Nat
  persistentSettings : Bool
  analyticsHistory : Bool
  vibrationalPattern : Bool
  directExecution : Bool
deriving DecidableEq, Repr

def validBuilderState (s : BuilderState) : Bool :=
  s.manifestPresent && s.typeConfigPresent && Nat.ble 10 s.modularSources && s.testsPass && s.bundleEmitted && (s.assetOrigin == ArtifactOrigin.externalFetched) && (s.assetGrant == GrantStatus.verifiedRedistributable) && Nat.ble 8 s.assetCount && Nat.ble 3 s.categoryCount && Nat.ble 5 s.interactiveChallenges && s.persistentSettings && s.analyticsHistory && s.vibrationalPattern && s.directExecution

def referenceState : BuilderState :=
  { manifestPresent := true, typeConfigPresent := true, modularSources := 12, testsPass := true, bundleEmitted := true, assetOrigin := ArtifactOrigin.externalFetched, assetGrant := GrantStatus.verifiedRedistributable, assetCount := 8, categoryCount := 3, interactiveChallenges := 7, persistentSettings := true, analyticsHistory := true, vibrationalPattern := true, directExecution := true }

end CageRules
