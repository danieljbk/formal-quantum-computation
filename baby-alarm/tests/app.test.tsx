import { act, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, beforeAll, describe, expect, it, vi } from "vitest";
import { App } from "../src/App";
import { MathChallenge } from "../src/components/challenges/MathChallenge";
import { SequenceChallenge } from "../src/components/challenges/SequenceChallenge";
import { makeMathProblem, makeSequenceBoard, seededRng } from "../src/lib/challenges";
import { STORAGE_KEY, defaultState } from "../src/lib/storage";

beforeAll(() => {
  // jsdom has no media playback.
  vi.spyOn(window.HTMLMediaElement.prototype, "play").mockImplementation(() => Promise.resolve());
  vi.spyOn(window.HTMLMediaElement.prototype, "pause").mockImplementation(() => {});
});
afterEach(() => {
  vi.useRealTimers();
  localStorage.clear();
});

describe("MathChallenge", () => {
  it("solves after answering every round via the keypad", () => {
    const onSolved = vi.fn();
    const onFailed = vi.fn();
    // Each render's useMemo draws from a fresh copy of the same seed, so recompute expected answers in lockstep.
    const seed = 11;
    const rng = seededRng(seed);
    render(<MathChallenge difficulty="easy" onSolved={onSolved} onFailedAttempt={onFailed} rng={rng} />);
    const shadow = seededRng(seed);
    for (let round = 0; round < 2; round++) {
      const { answer } = makeMathProblem("easy", shadow);
      expect(screen.getByTestId("math-problem").textContent).toContain("+");
      for (const ch of String(answer)) fireEvent.click(screen.getByRole("button", { name: ch }));
      fireEvent.click(screen.getByRole("button", { name: "Submit" }));
    }
    expect(onFailed).not.toHaveBeenCalled();
    expect(onSolved).toHaveBeenCalledTimes(1);
  });

  it("reports wrong answers", () => {
    const onFailed = vi.fn();
    render(<MathChallenge difficulty="easy" onSolved={() => {}} onFailedAttempt={onFailed} rng={seededRng(1)} />);
    fireEvent.click(screen.getByRole("button", { name: "0" }));
    fireEvent.click(screen.getByRole("button", { name: "Submit" }));
    expect(onFailed).toHaveBeenCalledTimes(1);
  });
});

describe("SequenceChallenge", () => {
  it("solves when tapping 1..n in order", () => {
    const onSolved = vi.fn();
    render(<SequenceChallenge difficulty="easy" onSolved={onSolved} onFailedAttempt={() => {}} rng={seededRng(5)} />);
    const n = makeSequenceBoard(6, seededRng(5)).length;
    for (let v = 1; v <= n; v++) fireEvent.click(screen.getByRole("button", { name: String(v) }));
    expect(onSolved).toHaveBeenCalled();
  });
});

describe("App", () => {
  it("renders the alarm list with the default morning alarm", () => {
    render(<App initialState={defaultState()} />);
    expect(screen.getByRole("heading", { name: "Alarms" })).toBeTruthy();
    expect(screen.getByText("Morning · Weekdays")).toBeTruthy();
  });

  it("test-rings an alarm, completes the mission, logs history and persists it", () => {
    vi.useFakeTimers();
    const state = defaultState();
    state.alarms[0].challenge = "sequence";
    state.alarms[0].difficulty = "easy";
    render(<App initialState={state} />);

    fireEvent.click(screen.getByRole("button", { name: "Ring Morning now" }));
    expect(screen.getByRole("alertdialog", { name: "Alarm ringing" })).toBeTruthy();

    fireEvent.click(screen.getByRole("button", { name: "Soothe the baby" }));
    for (let v = 1; v <= 6; v++) fireEvent.click(screen.getByRole("button", { name: String(v) }));
    expect(screen.getByText("Baby soothed.")).toBeTruthy();

    act(() => {
      vi.advanceTimersByTime(2000);
    });
    expect(screen.getByRole("heading", { name: "Wake Stats" })).toBeTruthy();
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEY)!);
    expect(saved.history).toHaveLength(1);
    expect(saved.history[0].challenge).toBe("sequence");
  });

  it("snoozes and re-rings after the snooze period", () => {
    vi.useFakeTimers();
    const state = defaultState();
    state.alarms[0].snoozeMinutes = 1;
    render(<App initialState={state} />);
    fireEvent.click(screen.getByRole("button", { name: "Ring Morning now" }));
    fireEvent.click(screen.getByRole("button", { name: /Snooze 1 min/ }));
    expect(screen.queryByRole("alertdialog")).toBeNull();
    expect(screen.getByText(/Snoozed/)).toBeTruthy();
    act(() => {
      vi.advanceTimersByTime(61_000);
    });
    expect(screen.getByRole("alertdialog")).toBeTruthy();
    expect(screen.getByText(/snoozed 1×/)).toBeTruthy();
  });

  it("lets the user choose a different baby voice for an alarm", () => {
    render(<App initialState={defaultState()} />);
    fireEvent.click(screen.getByRole("button", { name: "Edit Morning" }));
    fireEvent.click(screen.getByRole("button", { name: /Baby voice/ }));
    fireEvent.click(screen.getByRole("button", { name: /^✓?Bathtime Meltdown/ }));
    fireEvent.click(screen.getByRole("button", { name: "‹ Back" }));
    fireEvent.click(screen.getByRole("button", { name: "Save" }));
    expect(screen.getByRole("button", { name: "Edit Morning" }).textContent).toContain("Bathtime Meltdown");
  });
});
