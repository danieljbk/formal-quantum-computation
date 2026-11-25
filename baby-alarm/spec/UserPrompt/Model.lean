namespace UserPrompt

inductive ReferenceApp where
  | numberOneAppStoreAlarmApp
  deriving DecidableEq, Repr

inductive AlarmSound where
  | standardAlarm
  | babyCrying
  deriving DecidableEq, Repr

structure AppRequest where
  referenceApp : ReferenceApp
  matchesReferenceCapabilities : Bool
  alarmSound : AlarmSound
  alarmIsMetaphorForBabyCrying : Bool
  userCanChooseBabyVoice : Bool
  playsBabyCryingInMorningOrWhenAlarmSet : Bool
  deriving DecidableEq, Repr

def satisfiesRequest (r : AppRequest) : Bool :=
  r.referenceApp == .numberOneAppStoreAlarmApp &&
  r.matchesReferenceCapabilities &&
  r.alarmSound == .babyCrying &&
  r.alarmIsMetaphorForBabyCrying &&
  r.userCanChooseBabyVoice &&
  r.playsBabyCryingInMorningOrWhenAlarmSet

end UserPrompt
