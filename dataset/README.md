# Dataset

Two real, already-finished UFC events. Twenty bouts, forty fighters, real closing odds,
real results. Because both events are in the past, every settlement in the golden
fixtures is a matter of record rather than a made-up number, which is the whole reason
these two cards were chosen.

Regenerate with:

```bash
./tools/build-dataset.py            # events.json, fighters.json, news.json, media.json
python3 tools/fetch-real-art.py     # real Wikimedia photos + placeholders for gaps
```

Do not hand-edit the JSON. The source facts live in `tools/build-dataset.py`, and the
odds notations are computed from the published American lines so the three
representations cannot drift apart.

## Files

| File | Contents |
| --- | --- |
| `events.json` | Both events, each with its bouts in card order, closing odds and results |
| `fighters.json` | 40 fighters with pre-fight records and physicals |
| `news.json` | Feed items for the news screen |
| `media.json` | Video sources for the video screen |
| `assets/fighters/` | Portrait placeholders, 512×512 JPEG |
| `assets/events/` | Event posters, 1024×576 JPEG |

## The events

**UFC Freedom 250** — 14 June 2026, South Lawn of the White House, Washington D.C.
Seven bouts, every one ending by KO or TKO. Justin Gaethje beat Ilia Topuria by TKO
(corner stoppage) at 5:00 of round four to unify the lightweight title.

**UFC 328: Chimaev vs. Strickland** — 9 May 2026, Prudential Center, Newark.
Thirteen bouts, attendance 17,783, gate $7,518,918. Sean Strickland took the
middleweight title by split decision, 48-47, 48-47, 47-48.

Seven of the twenty bouts were won by the fighter who was the longer price. That is
unusually generous for a demo: accumulators that should have lost actually lose, and
the settlement screen has something to show.

## Odds

Stored in three notations per corner. Decimal is what the app treats as canonical;
fractional drives the display toggle; American is kept only as the provenance trail
back to the sportsbook.

Decimal values are **strings**, not JSON numbers. `1.20` cannot be represented exactly
in binary floating point, and a repository whose entire argument is that five
implementations must agree about money to the cent has no business handing them a
lossy literal to parse. Every core is expected to read these into a decimal type —
`Decimal` in Swift, `rust_decimal` in Rust — and never into a `Double`.

Closing lines move by roughly 5 to 15 points between books. One canonical value per
corner was chosen from the DraftKings column on BestFightOdds, cross-checked against
UFC.com where it published a line. Prices are a snapshot, not a universal truth.

## Caveats worth knowing before anything goes on a slide

**"The first UFC event without a decision" is an overclaim.** Freedom 250 is the only
UFC card on which *every* bout ended by KO or TKO specifically. It is not the only card
on which every bout ended in a finish — at least two earlier events achieved that with
submissions in the mix. The precise, defensible sentence is "the only card where all
seven fights ended by knockout".

**Gaethje–Topuria was a corner stoppage**, recorded at 5:00 of round four because
Topuria did not answer the bell for the fifth. Not a mid-round referee stoppage.
Gaethje also entered as interim champion, so the bout was a unification.

**Freedom 250 attendance is `null`.** No official figure was announced. Roughly 4,300
invite-only guests was widely reported, and that estimate sits in `attendanceNote`
rather than in `attendance`, because an estimate presented as a fact is the kind of
detail that gets challenged from the floor.

**Green vs. Stephens was a catchweight at 160 lb.** Stephens missed the lightweight
limit by four pounds; the bout went ahead with a purse deduction. It is recorded as
`catchweight_160`, not `lightweight`.

**Method taxonomy differs between sources.** UFC.com lists O'Malley–Zahabi as KO (right
hand); Sherdog and Wikipedia call it TKO (punches). Same stoppage, different vocabulary.
The dataset follows the UFC.com label.

## Images and video are not UFC property

Portrait and poster JPEGs live under `assets/` and are fetched over HTTP like a production
CDN would serve them — async load, decode, downsample and cache behaviour is part of what
the five apps compare.

Real photographs come from Wikimedia Commons where a suitably licensed portrait exists;
see `dataset/image-credits.json` for source URL and licence per file. Gaps fall back to
deterministic placeholders from `tools/generate-placeholder-art.swift` (gradients and
silhouettes). Nothing hotlinks to ufc.com.

Regenerate art after editing `tools/image-sources.json`:

```bash
python3 tools/fetch-real-art.py
```

Video is likewise public test media: Apple's BipBop HLS stream and a W3C-hosted MP4.
A YouTube link would not work — playing it through AVPlayer requires extracting the
stream, which breaks YouTube's terms, and the compliant route is an iframe in a WebView,
which would gut the point the video screen exists to make.

## Sources

Names, dates, venues, results, records and odds are matters of public record.

- UFC Freedom 250 — [event](https://www.ufc.com/event/ufc-freedom-250) ·
  [results](https://www.ufc.com/news/ufc-freedom-250-results-highlights-interviews) ·
  [Wikipedia](https://en.wikipedia.org/wiki/UFC_Freedom_250) ·
  [Sherdog play-by-play](https://www.sherdog.com/news/news/UFC-White-House-Freedom-250-playbyplay-results-round-scoring-201514)
- UFC 328 — [event](https://www.ufc.com/event/ufc-328) ·
  [results](https://www.ufc.com/news/ufc-328-chimaev-vs-strickland-results-highlights-main-card-winners-interviews-newark) ·
  [official scorecards](https://www.ufc.com/news/ufc-328-official-scorecards-chimaev-vs-strickland-judges) ·
  [Wikipedia](https://en.wikipedia.org/wiki/UFC_328) ·
  [ufcstats](http://www.ufcstats.com/event-details/9eedac48b497de5a)
- Closing odds — [BestFightOdds: Freedom 250](https://www.bestfightodds.com/events/ufc-freedom-fights-250-4082) ·
  [BestFightOdds: UFC 328](https://www.bestfightodds.com/events/ufc-328-4165)
- Attendance and gate — [MMA Junkie post-event facts](https://mmajunkie.usatoday.com/story/sports/ufc/2026/05/10/ufc-328-post-event-facts-sean-strickland-jim-miller-make-history/89988679007/)

News copy in `news.json` was written for this demo. The facts underneath it are real;
the prose reproduces no publication and every item carries `"source": "fightdeck-demo"`.
