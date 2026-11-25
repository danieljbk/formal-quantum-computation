/**
 * The capability set of a leading mission-based alarm app, and where each one
 * lives in this codebase. The test suite checks this list is complete.
 */
export interface Capability {
  id: string;
  title: string;
  where: string;
}

export const CAPABILITIES: readonly Capability[] = [
  { id: 'multi-alarm', title: 'Multiple named alarms with on/off toggles', where: 'views/AlarmListView' },
  { id: 'repeat', title: 'Weekday repeat schedules and one-shot alarms', where: 'core/schedule' },
  { id: 'missions', title: 'Wake-up missions that must be completed to dismiss (6 types)', where: 'missions/*' },
  { id: 'difficulty', title: 'Per-mission difficulty and round count', where: 'views/MissionPickerView' },
  { id: 'snooze-limit', title: 'Snooze with configurable length and hard limit (or none)', where: 'core/store SNOOZE' },
  { id: 'gradual-volume', title: 'Gradual multi-stage volume escalation', where: 'core/escalation' },
  { id: 'sound-choice', title: 'Choose the alarm sound (baby voice) per alarm, with preview', where: 'views/VoicePickerView' },
  { id: 'wake-check', title: 'Wake-up check that re-rings if you fall back asleep', where: 'views/WakeCheckView' },
  { id: 'no-bypass', title: 'Cannot silence by deleting, toggling or reloading while ringing', where: 'core/store' },
  { id: 'quick-alarm', title: 'Quick nap alarm in one tap', where: 'views/AlarmListView' },
  { id: 'history', title: 'Wake-up history and statistics', where: 'views/HistoryView' },
  { id: 'briefing', title: 'Morning briefing after dismissal', where: 'views/BriefingView' },
  { id: 'vibration', title: 'Vibration with the alarm', where: 'audio/engine' },
  { id: 'live-status', title: 'Live next-alarm countdown and ring status', where: 'views/StatusBar' },
  { id: 'mission-timeout', title: 'Idle during a mission? The full cry comes back', where: 'core/store TICK' },
];
