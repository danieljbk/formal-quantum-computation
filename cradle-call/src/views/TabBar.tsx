import type { Screen } from '../core/types';

const TABS: { screen: Screen; label: string; icon: string }[] = [
  { screen: 'alarms', label: 'Alarms', icon: '⏰' },
  { screen: 'history', label: 'History', icon: '📈' },
  { screen: 'settings', label: 'Settings', icon: '⚙️' },
];

export function TabBar({ screen, onNavigate }: { screen: Screen; onNavigate: (s: Screen) => void }) {
  return (
    <nav className="tab-bar">
      {TABS.map((t) => (
        <button key={t.screen} className={screen === t.screen ? 'active' : ''} onClick={() => onNavigate(t.screen)}>
          <span aria-hidden>{t.icon}</span>
          {t.label}
        </button>
      ))}
    </nav>
  );
}
