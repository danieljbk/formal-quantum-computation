import { defaultMission, MISSIONS, missionInfo } from '../core/missions';
import type { Difficulty, MissionConfig } from '../core/types';

const DIFFICULTIES: Difficulty[] = ['easy', 'normal', 'hard'];
const MAX_MISSIONS = 5;

/** Choose the gates that stand between you and silence. At least one is always required. */
export function MissionPickerView({ value, onChange }: { value: MissionConfig[]; onChange: (m: MissionConfig[]) => void }) {
  const update = (i: number, patch: Partial<MissionConfig>) => onChange(value.map((m, j) => (j === i ? { ...m, ...patch } : m)));
  return (
    <div className="mission-picker">
      <ol>
        {value.map((m, i) => (
          <li key={i} className="mission-row">
            <span className="mission-name">
              {missionInfo(m.kind).icon} {missionInfo(m.kind).title}
            </span>
            <select aria-label="difficulty" value={m.difficulty} onChange={(e) => update(i, { difficulty: e.target.value as Difficulty })}>
              {DIFFICULTIES.map((d) => (
                <option key={d} value={d}>{d}</option>
              ))}
            </select>
            <input
              aria-label="rounds"
              type="number"
              min={1}
              max={10}
              value={m.rounds}
              onChange={(e) => update(i, { rounds: Number(e.target.value) || 1 })}
            />
            <button
              className="chip"
              aria-label={`remove ${missionInfo(m.kind).title}`}
              disabled={value.length <= 1}
              title={value.length <= 1 ? 'At least one mission is required' : 'Remove'}
              onClick={() => onChange(value.filter((_, j) => j !== i))}
            >
              ✕
            </button>
          </li>
        ))}
      </ol>
      {value.length < MAX_MISSIONS && (
        <div className="chips">
          {MISSIONS.map((info) => (
            <button key={info.kind} className="chip" title={info.blurb} onClick={() => onChange([...value, defaultMission(info.kind)])}>
              + {info.icon} {info.title}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
