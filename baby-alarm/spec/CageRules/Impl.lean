import Model
import Statements
namespace CageRules.Impl

theorem valid_deep_surface : valid_deep_surface_prop := by
  unfold valid_deep_surface_prop
  decide

theorem reject_few_categories : reject_few_categories_prop := by
  unfold reject_few_categories_prop
  decide

theorem reject_no_persistence : reject_no_persistence_prop := by
  unfold reject_no_persistence_prop
  decide

theorem reject_fabricated_deep : reject_fabricated_deep_prop := by
  unfold reject_fabricated_deep_prop
  decide

end CageRules.Impl
