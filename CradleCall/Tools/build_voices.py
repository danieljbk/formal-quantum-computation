#!/usr/bin/env python3
"""Builds the bundled baby-cry alarm voices from the Donate-a-cry corpus.

Every bundled voice is a real recording of a human infant, taken unmodified
(apart from trimming, fades, loudness normalisation and transcoding) from the
iOS upload bucket of https://github.com/gveres/donateacry-corpus
(ODbL 1.0 database / DbCL 1.0 contents).

Usage:
    git clone --depth 1 https://github.com/gveres/donateacry-corpus /tmp/dac
    python3 CradleCall/Tools/build_voices.py /tmp/dac CradleCall/App/Resources/Sounds

Each voice concatenates clips recorded by the same app install (i.e. the same
baby), keeps the result under 30 s (the iOS limit for notification sounds),
normalises loudness and writes IMA4 CAF, which iOS can use both for
AVAudioPlayer playback and as a UNNotificationSound / AlarmKit sound.
"""
import json
import os
import re
import subprocess
import sys

# voice id -> (recording install id, display name)
VOICES = [
    ("cry_newborn_girl", "9CFD61B9-BF13-406D-8B2F-F73CFAAF25CB"),
    ("cry_newborn_boy", "DCB33551-F9BA-4B4A-8DA1-A3107E1AD859"),
    ("cry_hungry_girl", "10A40438-09AA-4A21-83B4-8119F03F7A11"),
    ("cry_fussy_girl", "1309B82C-F146-46F0-A723-45345AFA6EA8"),
    ("cry_baby_boy", "50DC5FBC-AC95-44F2-B55F-E4E5FB03AC96"),
    ("cry_toddler_boy", "9641D2D5-7D9F-41B2-8345-229AE9555FEC"),
    ("cry_toddler_girl", "69309582-5CAE-415F-A7E3-67BEC99DCB1B"),
]
TARGET_SECONDS = 26.0
# Core Audio Format: playable by AVAudioPlayer and usable as a notification sound.
AUDIO_EXT = "caf"


def probe(path):
    out = subprocess.run(
        ["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af",
         "silencedetect=n=-35dB:d=0.4,volumedetect", "-f", "null", "-"],
        capture_output=True, text=True).stderr
    mean = re.search(r"mean_volume: (-?[\d.]+)", out)
    dur = re.search(r"Duration: (\d+):(\d+):([\d.]+)", out)
    silence = sum(float(x) for x in re.findall(r"silence_duration: ([\d.]+)", out))
    return (float(mean.group(1)) if mean else -99.0,
            float(dur.group(3)) if dur else 0.0, silence)


def main(corpus, out_dir):
    bucket = os.path.join(corpus, "donateacry-ios-upload-bucket")
    os.makedirs(out_dir, exist_ok=True)
    manifest = []
    for voice_id, install in VOICES:
        clips = []
        for name in sorted(os.listdir(bucket)):
            if not name.startswith(install) or os.path.splitext(name)[1].lstrip(".") != AUDIO_EXT:
                continue
            mean, dur, silence = probe(os.path.join(bucket, name))
            if silence < 1.0 and dur >= 4.0:
                clips.append((mean, dur, name))
        clips.sort(reverse=True)
        chosen, total = [], 0.0
        while total < TARGET_SECONDS and clips:
            for mean, dur, name in clips:
                chosen.append(name)
                total += dur
                if total >= TARGET_SECONDS:
                    break
        inputs, filters = [], []
        for i, name in enumerate(chosen):
            inputs += ["-i", os.path.join(bucket, name)]
            filters.append(
                f"[{i}:a]aresample=22050,afade=t=in:d=0.04,"
                f"areverse,afade=t=in:d=0.04,areverse[a{i}]")
        concat = "".join(f"[a{i}]" for i in range(len(chosen)))
        graph = ";".join(filters) + (
            f";{concat}concat=n={len(chosen)}:v=0:a=1,highpass=f=120,"
            f"loudnorm=I=-14:TP=-1.0:LRA=11,aresample=22050,"
            f"atrim=0:{TARGET_SECONDS},afade=t=out:st={TARGET_SECONDS - 0.3}:d=0.3[out]")
        dest = os.path.join(out_dir, os.extsep.join([voice_id, AUDIO_EXT]))
        subprocess.run(["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", *inputs,
                        "-filter_complex", graph, "-map", "[out]", "-ac", "1",
                        "-c:a", "adpcm_ima_qt", "-f", "caf", dest], check=True)
        manifest.append({"id": voice_id, "sourceClips": chosen})
        print(voice_id, len(chosen), "clips")
    with open(os.path.join(out_dir, "voice_sources.json"), "w") as fh:
        json.dump(manifest, fh, indent=2)
        fh.write("\n")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
