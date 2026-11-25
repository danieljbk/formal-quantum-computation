import { act, cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { App } from "../src/App";
import { BabyPlayer, rampVolume, RAMP_FLOOR } from "../src/audio";
import { MissionPanel } from "../src/components/MissionPanel";
import { makeMathProblem, makeRng } from "../src/missions";
import { defaultAlarm, serialize, STORAGE_KEY } from "../src/storage";
import type { SoundId } from "../src/types";

class FakePlayer extends BabyPlayer {
  plays: SoundId[] = [];
  stops = 0;
  override async unlock() {
    this.unlocked = true;
    return true;
  }
  override preload() {
    return null;
  }
  override async play(id: SoundId) {
    this.plays.push(id);
  }
  override stop() {
    this.stops++;
  }
}

const WED_659 = new Date(2026, 10, 25, 6, 59, 0, 0).getTime();

beforeEach(() => {
  localStorage.clear();
});

afterEach(() => {
  cleanup();
  vi.useRealTimers();
});

describe("App", () => {
  it("starts with a weekday morning baby alarm", () => {
    render(<App player={new FakePlayer()} clockNow={() => WED_659} />);
    expect(screen.getByRole("article", { name: /Alarm 7:00 AM, Good morning/ })).toBeTruthy();
    expect(screen.getByText("Weekdays")).toBeTruthy();
    expect(screen.getByText(/Next cry in 1 min|Next cry in less than a minute/)).toBeTruthy();
  });

  it("lets the user pick which baby cries", () => {
    render(<App player={new FakePlayer()} clockNow={() => WED_659} />);
    fireEvent.click(screen.getByLabelText("Add alarm"));
    const voices = screen.getAllByRole("radio").filter((r) => r.classList.contains("voice"));
    expect(voices.map((v) => v.querySelector(".voice-name")?.textContent)).toEqual([
      "Newborn wail",
      "Hungry build-up",
      "Fussy & let down",
      "Kunjappi",
      "Surprise baby",
    ]);
    fireEvent.click(screen.getByText("Kunjappi"));
    fireEvent.change(screen.getByLabelText("Alarm time"), { target: { value: "05:30" } });
    fireEvent.click(screen.getByText("Save"));
    const card = screen.getByRole("article", { name: /Alarm 5:30 AM/ });
    expect(card.textContent).toContain("Kunjappi");
  });

  it("previews a baby voice", async () => {
    const player = new FakePlayer();
    render(<App player={player} clockNow={() => WED_659} />);
    fireEvent.click(screen.getByLabelText("Add alarm"));
    await act(async () => {
      fireEvent.click(screen.getByLabelText("Preview Hungry build-up"));
    });
    expect(player.plays).toContain("hungry");
  });

  it("cries at the alarm time and stops when dismissed", async () => {
    vi.useFakeTimers();
    let t = WED_659;
    const player = new FakePlayer();
    const alarm = defaultAlarm({ id: "m", hour: 7, minute: 0, label: "Wake up", voice: "fussy", mission: { kind: "none" } });
    localStorage.setItem(STORAGE_KEY, serialize({ alarms: [alarm], snoozes: [], seeded: true }));
    render(<App player={player} clockNow={() => t} />);
    expect(screen.queryByRole("alertdialog")).toBeNull();

    t = WED_659 + 61_000;
    await act(async () => {
      vi.advanceTimersByTime(1000);
    });
    expect(screen.getByRole("alertdialog")).toBeTruthy();
    expect(screen.getByText(/Fussy & let down is crying/)).toBeTruthy();
    expect(player.plays).toEqual(["fussy"]);

    const stopsBefore = player.stops;
    await act(async () => {
      fireEvent.click(screen.getByText("I’m up"));
    });
    expect(screen.queryByRole("alertdialog")).toBeNull();
    expect(player.stops).toBeGreaterThan(stopsBefore);
  });

  it("snooze silences the baby and it cries again later", async () => {
    vi.useFakeTimers();
    let t = WED_659;
    const player = new FakePlayer();
    const alarm = defaultAlarm({ id: "m", hour: 7, minute: 0, voice: "newborn", repeat: [3] });
    localStorage.setItem(STORAGE_KEY, serialize({ alarms: [alarm], snoozes: [], seeded: true }));
    render(<App player={player} clockNow={() => t} />);

    t = WED_659 + 61_000;
    await act(async () => void vi.advanceTimersByTime(1000));
    await act(async () => void fireEvent.click(screen.getByText(/Snooze 5 min · 3 left/)));
    expect(screen.queryByRole("alertdialog")).toBeNull();

    t += 5 * 60_000;
    await act(async () => void vi.advanceTimersByTime(1000));
    expect(screen.getByText(/Snooze 5 min · 2 left/)).toBeTruthy();
    expect(player.plays).toEqual(["newborn", "newborn"]);
  });
});

describe("MissionPanel", () => {
  it("only finishes after every math problem is solved", () => {
    const onDone = vi.fn();
    const seed = 1234;
    const rng = makeRng(seed);
    const p1 = makeMathProblem(2, rng);
    const p2 = makeMathProblem(2, rng);
    render(<MissionPanel mission={{ kind: "math", difficulty: 2, rounds: 2 }} seed={seed} onDone={onDone} />);

    expect(screen.getByLabelText("Problem").textContent).toContain(p1.prompt);
    fireEvent.change(screen.getByLabelText("Answer"), { target: { value: String(p1.answer + 1) } });
    fireEvent.click(screen.getByText("Check"));
    expect(screen.getByText(/Not quite/)).toBeTruthy();

    fireEvent.change(screen.getByLabelText("Answer"), { target: { value: String(p1.answer) } });
    fireEvent.click(screen.getByText("Check"));
    expect(onDone).not.toHaveBeenCalled();
    expect(screen.getByLabelText("Problem").textContent).toContain(p2.prompt);

    fireEvent.change(screen.getByLabelText("Answer"), { target: { value: String(p2.answer) } });
    fireEvent.click(screen.getByText("Check"));
    expect(onDone).toHaveBeenCalledTimes(1);
  });

  it("rock mission counts cradle taps", () => {
    const onDone = vi.fn();
    render(<MissionPanel mission={{ kind: "rock", rocks: 5 }} seed={1} onDone={onDone} />);
    for (let i = 0; i < 4; i++) fireEvent.click(screen.getByLabelText("Rock the cradle"));
    expect(onDone).not.toHaveBeenCalled();
    fireEvent.click(screen.getByLabelText("Rock the cradle"));
    expect(onDone).toHaveBeenCalledTimes(1);
  });
});

describe("volume ramp", () => {
  it("fades from quiet to peak", () => {
    expect(rampVolume(0, 30, 1)).toBeCloseTo(RAMP_FLOOR);
    expect(rampVolume(15, 30, 1)).toBeCloseTo(RAMP_FLOOR + (1 - RAMP_FLOOR) / 2);
    expect(rampVolume(30, 30, 0.8)).toBe(0.8);
    expect(rampVolume(0, 0, 0.6)).toBe(0.6);
  });
});
