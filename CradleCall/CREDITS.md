# Credits

## Baby cry recordings

All seven bundled alarm voices (`App/Resources/Sounds/cry_*.caf`) are real recordings
of crying infants from the **Donate-a-cry corpus**
(<https://github.com/gveres/donateacry-corpus>), recorded by parents with the
Donate-a-cry iOS app.

> This donateacry-corpus is made available under the Open Database License:
> <http://opendatacommons.org/licenses/odbl/1.0/>. Any rights in individual contents of
> the database are licensed under the Database Contents License:
> <http://opendatacommons.org/licenses/dbcl/1.0/>

Each voice joins up to four clips recorded by the same app install (the same baby),
then trims them to 26 s, adds 40 ms fades, applies a 120 Hz high-pass filter, normalises
loudness and encodes IMA4 CAF at 22.05 kHz. Nothing is synthesised. The exact source
clips for every voice are listed in `App/Resources/Sounds/voice_sources.json`, and
`Tools/build_voices.py` regenerates the files from a checkout of the corpus.

| Voice | Source install | Tags (sex · age · reason) |
| --- | --- | --- |
| Newborn girl | `9CFD61B9-…` | f · 0–4 weeks · hungry |
| Newborn boy | `DCB33551-…` | m · 0–4 weeks · hungry |
| Hungry little girl | `10A40438-…` | f · 2–6 months · hungry |
| Fussy little girl | `1309B82C-…` | f · 1–6 months · discomfort |
| Baby boy | `50DC5FBC-…` | m · 2–6 months · hungry |
| Toddler boy | `9641D2D5-…` | m · 7 months–2 years · hungry/unknown |
| Toddler girl | `69309582-…` | f · 2 years+ · unknown |

## Weather

Morning-briefing weather comes from [Open-Meteo](https://open-meteo.com/) (CC BY 4.0).
