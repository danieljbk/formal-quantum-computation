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

def validRequestInstance : AppRequest :=
  { referenceApp := .numberOneAppStoreAlarmApp
  , matchesReferenceCapabilities := true
  , alarmSound := .babyCrying
  , alarmIsMetaphorForBabyCrying := true
  , userCanChooseBabyVoice := true
  , playsBabyCryingInMorningOrWhenAlarmSet := true }

def witnessStandardAlarm : AppRequest :=
  { validRequestInstance with alarmSound := .standardAlarm }

def witnessMissingCapabilities : AppRequest :=
  { validRequestInstance with matchesReferenceCapabilities := false }

def witnessUnselectableVoice : AppRequest :=
  { validRequestInstance with userCanChooseBabyVoice := false }

theorem valid_request_accepted : satisfiesRequest validRequestInstance = true := by rfl
theorem refute_standard_alarm : satisfiesRequest witnessStandardAlarm = false := by rfl
theorem refute_missing_capabilities : satisfiesRequest witnessMissingCapabilities = false := by rfl
theorem refute_unselectable_voice : satisfiesRequest witnessUnselectableVoice = false := by rfl

end UserPrompt
