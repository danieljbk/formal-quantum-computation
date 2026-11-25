import Model
namespace CageRules

def valid_deep_surface_prop : Prop :=
  validBuilderState referenceState = true

def reject_few_categories_prop : Prop :=
  validBuilderState { referenceState with categoryCount := 1 } = false

def reject_no_persistence_prop : Prop :=
  validBuilderState { referenceState with persistentSettings := false } = false

def reject_fabricated_deep_prop : Prop :=
  validBuilderState { referenceState with assetOrigin := ArtifactOrigin.localGenerated } = false

end CageRules
