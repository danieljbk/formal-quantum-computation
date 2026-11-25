export type Tab = "alarms" | "voices" | "stats" | "settings";

const TABS: { id: Tab; label: string; icon: string }[] = [
  { id: "alarms", label: "Alarms", icon: "⏰" },
  { id: "voices", label: "Voices", icon: "👶" },
  { id: "stats", label: "Stats", icon: "📈" },
  { id: "settings", label: "Settings", icon: "⚙️" },
];

export function TabBar({ tab, onChange }: { tab: Tab; onChange: (t: Tab) => void }) {
  return (
    <nav className="tab-bar">
      {TABS.map((t) => (
        <button key={t.id} className={`tab ${tab === t.id ? "on" : ""}`} onClick={() => onChange(t.id)} aria-current={tab === t.id}>
          <span className="tab-icon">{t.icon}</span>
          <span className="tab-label">{t.label}</span>
        </button>
      ))}
    </nav>
  );
}
