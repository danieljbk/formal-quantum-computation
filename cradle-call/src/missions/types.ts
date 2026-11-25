import type { MissionConfig } from '../core/types';

export interface MissionProps {
  config: MissionConfig;
  seed: number;
  onDone: () => void;
  onActivity: () => void;
}
