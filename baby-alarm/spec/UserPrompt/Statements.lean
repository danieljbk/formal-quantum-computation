import Model

namespace UserPrompt

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

def valid_request_accepted_prop : Prop :=
  satisfiesRequest validRequestInstance = true

def refute_standard_alarm_prop : Prop :=
  satisfiesRequest witnessStandardAlarm = false

def refute_missing_capabilities_prop : Prop :=
  satisfiesRequest witnessMissingCapabilities = false

def refute_unselectable_voice_prop : Prop :=
  satisfiesRequest witnessUnselectableVoice = false

end UserPrompt
