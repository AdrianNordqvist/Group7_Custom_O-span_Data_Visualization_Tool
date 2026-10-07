# O-Span Data Compilation and Visualization Tool

This repository holds two things:

- **The O-Span test** the participants took: a Swedish version of the Automated Operation Span task, a working-memory test.
- **A macOS app** that merges the result files from the test, scores a phone-use survey, compares experimental conditions, and exports tables and charts.

Group 7 built it for a cognitive psychology course project. The study asks whether having a smartphone on the desk during the test affects working-memory performance, so the app compares two conditions: *with phone* and *without phone*.

The app's interface is in Swedish. The text inside exported charts can be switched to English.

## The O-Span test

The folder `O-Span Test Svenska 10 trails` holds the test. It is an adaptation of the [Automated Operation Span task](https://www.psytoolkit.org/experiment-library/aospan.html) from the PsyToolkit experiment library, with these changes:

- The instructions and feedback texts are in Swedish.
- The main block has 10 sets (set sizes 3–7, twice each) instead of 15.
- The practice is shorter: 2 letter sets, 4 math problems and 1 combined set.

There are two ways to run it:

| Version | File | How to use it |
|---|---|---|
| Offline | `OfflineOpsanTest10trials.html` | Open the file in a web browser. It needs no internet connection. |
| PsyToolkit | `OspanSvenska10trials_psytoolkit.zip` | Log in at https://www.psytoolkit.org/c/3.7.2/, create a new experiment from a zip file, upload the zip and compile it. |

The other files in the folder are the contents of the zip: the script `aospan.psy`, the images and the experiment's description files.

**Getting the results out of the offline version.** When the test ends, it offers *Show data* and *Copy data to clipboard*. Paste the data into a plain text file (`.txt`), one file per participant, and name the file as described under [Input files](#input-files). The app reads that file as it is.

## What the app does

The app has three tabs.

**O-Span**
- Reads one result file per participant, by drag and drop or from a whole folder.
- Reads the condition, participant name and time from each file name.
- Flags files with identical data, incomplete runs and test runs, and leaves them out by default.
- Shows one row per participant and a comparison of the conditions (mean and standard deviation).

**Mobilanvändning (SAS-SV)** — the phone-use survey
- Scores the answers according to the Smartphone Addiction Scale – Short Version.
- Shows each respondent's score and whether it is below or above the cutoff.
- Links each survey answer to the right O-Span run.
- Shows scores per condition, the correlation with O-Span, and the mean per question.
- Reads the survey's other number questions, such as screen time, as measures of their own.

**Diagram** — charts
- Six chart types: mean per group with error bars, box plot, one bar per participant, scatter plot with trend line, results per set size, and SAS-SV per question.
- Choice of measure, grouping (condition, gender or SAS level), error bars, title, size and language.
- A color for each group, chosen with the macOS color picker and saved between launches.
- Export as PNG or PDF, or copy to the clipboard.
- A suggested figure caption and a table of the values behind each chart.

## Requirements

- macOS 15 or later
- Xcode 26 or later

## Getting started

1. Clone the repository.
2. Open `OspanSammanstallning.xcodeproj` in Xcode.
3. Press **⌘R** to build and run.
4. Drag your O-Span files and the survey file into the window, or drag in the folder that holds them. The app sorts out which file is which.

## Input files

### O-Span result files

One file per participant, as `.csv` (semicolon-separated, with a header row) or `.txt` (space-separated, no header). Each row is one set, with these 13 columns:

```
block;blocknamn;ospan;bokstaverRattHittills;matteRattHittills;mathRT1_ms;bokstavRT_ms;maxMathRT1_ms;matteRattProcent;sekvenslangd;matteRattForsok;matteFelForsok;bokstaverRattForsok
```

`OspanExempleFile.csv` shows this layout. It holds no values, so the app will not load it as data.

The app reads three things from the file name:

| Read from the name | How to write it | Example |
|---|---|---|
| Condition | `medmobil` or `utanmobil`, or a lone `M` or `U` | `ospan_data_2026-09-30_12-26-02 M.csv` |
| Test run | the word `TEST` | `Files.data.2026-09-28--11-42 TEST.txt` |
| Time | `YYYY-MM-DD_HH-MM-SS` | `ospan_data_2026-09-28_14-21-29 U.csv` |

Any other word in the name is taken as the participant's name. You can change the name and the condition in the table afterwards.

### Survey file

A `.csv` export from Google Forms, with the time stamp in the first column. The two `Enkät om mobilanvändning (Exempel Svar)` files show the layout.

- **SAS-SV questions** are the columns answered with the scale's text labels, in Swedish (`Stämmer inte alls` … `Stämmer helt`) or English (`Strongly disagree` … `Strongly agree`).
- **A column named `Kön`** (gender) selects the cutoff. It is optional.
- **Other columns with numbers or ranges**, such as hours of screen time, become extra measures. A range counts as its midpoint, so `4–5 timmar` is 4.5.
- **A column that contains the O-Span file name** links the answer to that participant. It is optional. Without it, each answer is linked to the O-Span run saved from 2 minutes before to 10 minutes after the answer.

## How the scores are calculated

| Score | Calculation |
|---|---|
| O-Span absolute | The test's own `ospan` value on the last row of the main block. A set counts only if every letter and every math problem in it was right. |
| O-Span partial | The number of letters recalled correctly over the 10 main sets (maximum 50). |
| Math accuracy | Correct math answers divided by all math answers in the main block. |
| SAS-SV | The sum of the 10 answers, each scored 1–6, giving 10–60. |

The SAS-SV cutoff for risk of problematic use is 31 for men and 33 for women. If the survey holds fewer than 10 of the questions, the app rescales the score to 10–60 (mean × 10) and says so on screen.

Standard deviations use n − 1. Quartiles use linear interpolation, the same as `QUARTILE.INC` in Excel and Google Sheets.

## Exports

**CSV files** (semicolon-separated, with decimal comma or decimal point):
- One row per participant, with all O-Span scores and times, plus the survey scores when the survey is loaded.
- All rows from all files in long format.
- The group comparison.
- The survey with SAS-SV scores.

**Charts** as PNG (three times screen resolution) or PDF.

## Project layout

| Path | Contents |
|---|---|
| `O-Span Test Svenska 10 trails/` | The O-Span test: offline version, PsyToolkit zip and its source files |
| `OspanSammanstallning/Modell/` | Parsing, scoring, statistics and CSV export |
| `OspanSammanstallning/Vyer/` | The three tabs and the chart view |
| `OspanExempleFile.csv` | The column layout of an O-Span result file |
| `Enkät om mobilanvändning (Exempel Svar).csv` | Example survey export |
| `prompt_history.txt` | The prompts used to build the app |

## Data and privacy

The repository holds no participant data. Result files and survey answers stay on your own computer, and the app sends nothing anywhere.

## How it was built

The app was written with Claude Code (Claude Opus 5.5). `prompt_history.txt` lists every prompt, with an English translation.

## References

The O-Span test is built with PsyToolkit and based on its library version of the task:

Stoet, G. (2010). PsyToolkit: A software package for programming psychological experiments using Linux. *Behavior Research Methods, 42*(4), 1096–1104. https://doi.org/10.3758/BRM.42.4.1096

Stoet, G. (2017). PsyToolkit: A novel web-based method for running online questionnaires and reaction-time experiments. *Teaching of Psychology, 44*(1), 24–31. https://doi.org/10.1177/0098628316677643

Unsworth, N., Heitz, R. P., Schrock, J. C., & Engle, R. W. (2005). An automated version of the operation span task. *Behavior Research Methods, 37*(3), 498–505. https://doi.org/10.3758/BF03192720

The survey scoring follows the Smartphone Addiction Scale – Short Version:

Kwon, M., Kim, D.-J., Cho, H., & Yang, S. (2013). The Smartphone Addiction Scale: Development and validation of a short version for adolescents. *PLOS ONE, 8*(12), e83558. https://doi.org/10.1371/journal.pone.0083558

The scale and its scoring are described at https://www.healthyscreens.com/sas-sv.pdf.
