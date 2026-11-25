export type Tab = "alarms" | "nap" | "babies" | "settings";

export const TABS: { id: Tab; label: string; icon: string }[] = [
  { id: "alarms", label: "Alarms", icon: "⏰" },
  { id: "nap", label: "Nap", icon: "🌙" },
  { id: "babies", label: "Babies", icon: "👶" },
  { id: "settings", label: "Settings", icon: "⚙️" },
];

interface Props {
  active: Tab;
  onChange: (tab: Tab) => void;
}

/** Bottom navigation, iOS tab-bar style. */
export function TabBar({ active, onChange }: Props) {
  return (
    <nav className="tabbar" role="tablist" aria-label="Sections">
      {TABS.map((t) => (
        <button
          key={t.id}
          type="button"
          role="tab"
          aria-selected={active === t.id}
          className={active === t.id ? "on" : ""}
          onClick={() => onChange(t.id)}
        >
          <span className="tab-icon" aria-hidden>
            {t.icon}
          </span>
          <span className="tab-label">{t.label}</span>
        </button>
      ))}
    </nav>
  );
}
