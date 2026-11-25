import type { ComponentType } from 'react';
import type { MissionKind } from '../core/types';
import { ColorsMission } from './ColorsMission';
import { MathMission } from './MathMission';
import { MemoryMission } from './MemoryMission';
import { RockMission } from './RockMission';
import { SequenceMission } from './SequenceMission';
import { TypingMission } from './TypingMission';
import type { MissionProps } from './types';

export const MISSION_COMPONENTS: Record<MissionKind, ComponentType<MissionProps>> = {
  math: MathMission,
  typing: TypingMission,
  memory: MemoryMission,
  rock: RockMission,
  sequence: SequenceMission,
  colors: ColorsMission,
};
