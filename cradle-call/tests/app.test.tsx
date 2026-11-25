import { act, fireEvent, render, screen } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { App } from '../src/App';
import { makeAlarm, STORAGE_KEY } from '../src/core/store';
import { defaultMission } from '../src/core/missions';

describe('App', () => {
  beforeEach(() => {
    localStorage.clear();
    vi.useFakeTimers();
  });
  afterEach(() => vi.useRealTimers());

  it('renders the alarm list with a live status bar', () => {
    render(<App />);
    expect(screen.getByRole('heading', { name: 'Alarms' })).toBeTruthy();
    expect(screen.getByRole('status').textContent).toContain('No alarms set');
  });

  it('quick nap creates an alarm and the status bar counts down', () => {
    render(<App />);
    fireEvent.click(screen.getByText('20m'));
    expect(screen.getAllByText(/Nap · 20 min/).length).toBeGreaterThan(0);
    act(() => vi.advanceTimersByTime(1100));
    expect(screen.getByRole('status').textContent).toMatch(/Next: Nap · 20 min in/);
  });

  it('a ringing alarm offers missions and snooze, but no plain dismiss', () => {
    const now = new Date(2026, 10, 25, 7, 0, 0);
    vi.setSystemTime(now);
    const alarm = makeAlarm(0, { id: 'x', hour: 7, minute: 0, repeat: [3], missions: [defaultMission('sequence', 'easy')] });
    localStorage.setItem(STORAGE_KEY, JSON.stringify({ alarms: [alarm] }));
    render(<App />);
    act(() => vi.advanceTimersByTime(1100));
    const dialog = screen.getByRole('alertdialog', { name: 'Alarm ringing' });
    expect(dialog).toBeTruthy();
    expect(screen.queryByText(/^(dismiss|stop|turn off)$/i)).toBeNull();
    expect(screen.getByText(/Snooze 5 min/)).toBeTruthy();

    fireEvent.click(screen.getByText(/Soothe the baby/));
    expect(screen.getByRole('alertdialog', { name: 'Mission' })).toBeTruthy();
    // Solve both easy sequence boards by tapping 1..6 in order.
    for (let board = 0; board < 2; board++)
      for (let n = 1; n <= 6; n++) fireEvent.click(screen.getByRole('button', { name: String(n) }));
    expect(screen.queryByRole('alertdialog')).toBeNull();
    expect(screen.getByText(/Good (morning|afternoon|evening)!/)).toBeTruthy();
  });
});
