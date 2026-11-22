import 'package:sax_buddy/features/sax/domain/entities/sax_models.dart';

class SaxCatalogData {
  static const Set<SaxKeyId> _lhStack = {
    SaxKeyId.lh1,
    SaxKeyId.lh2,
    SaxKeyId.lh3,
  };

  static const Set<SaxKeyId> _rhStack = {
    SaxKeyId.rh4,
    SaxKeyId.rh5,
    SaxKeyId.rh6,
  };

  static const Set<SaxKeyId> _fullStack = {
    ..._lhStack,
    ..._rhStack,
  };

  /// Complete saxophone fingering chart from Low Bb3 (58) to Altissimo C7 (96).
  static final List<SaxFingeringEntry> fingerings = <SaxFingeringEntry>[
    SaxFingeringEntry(
      writtenNote: 'Bb3',
      enharmonicLabel: 'A#3',
      midiNote: 58,
      register: 'Low',
      tendencyCents: -6,
      practiceDrill: 'Play long-tone crescendo/decrescendo with warm, open throat ("oh").',
      variants: [
        SaxFingeringVariant(
          label: 'Primary Low Bb',
          pressedKeys: {..._fullStack, SaxKeyId.lowC, SaxKeyId.lowBb},
          tip: 'Support with steady diaphragm pressure; keep lower lip relaxed so Low Bb speaks without subtone breakup.',
        ),
      ],
    ),
    SaxFingeringEntry(
      writtenNote: 'B3',
      enharmonicLabel: '',
      midiNote: 59,
      register: 'Low',
      tendencyCents: -4,
      practiceDrill: 'Slur C4 -> B3 -> Bb3 slowly at 60 BPM without jaw movement.',
      variants: [
        SaxFingeringVariant(
          label: 'Primary Low B',
          pressedKeys: {..._fullStack, SaxKeyId.lowC, SaxKeyId.lowB},
          tip: 'Roll left pinky smoothly from Low B to Low Bb table roller.',
        ),
      ],
    ),
    SaxFingeringEntry(
      writtenNote: 'C4',
      enharmonicLabel: '',
      midiNote: 60,
      register: 'Low',
      tendencyCents: -3,
      practiceDrill: 'Overtone fundamental base note: match 1st and 2nd overtones.',
      variants: [
        SaxFingeringVariant(
          label: 'Primary Low C',
          pressedKeys: {..._fullStack, SaxKeyId.lowC},
          tip: 'Ensure right-hand ring finger (6) and Low C roller close simultaneously.',
        ),
      ],
    ),
    SaxFingeringEntry(
      writtenNote: 'C#4',
      enharmonicLabel: 'Db4',
      midiNote: 61,
      register: 'Low',
      tendencyCents: 2,
      practiceDrill: 'Chromatic low table workout: C4 - C#4 - D4 - Eb4.',
      variants: [
        SaxFingeringVariant(
          label: 'Primary Low C#',
          pressedKeys: {..._fullStack, SaxKeyId.lowC, SaxKeyId.lowCSharp},
          tip: 'Keep left pinky curved on the outside Low C# spatula.',
        ),
      ],
    ),
    SaxFingeringEntry(
      writtenNote: 'D4',
      enharmonicLabel: '',
      midiNote: 62,
      register: 'Low',
      tendencyCents: 0,
      practiceDrill: 'Octave leaps D4 <-> D5 checking even timbre.',
      variants: [
        SaxFingeringVariant(
          label: 'Standard (1-2-3 | 4-5-6)',
          pressedKeys: {..._fullStack},
          tip: 'All six main stack pearls closed; neutral intonation reference.',
        ),
      ],
    ),
    SaxFingeringEntry(
      writtenNote: 'Eb4',
      enharmonicLabel: 'D#4',
      midiNote: 63,
      register: 'Low',
      tendencyCents: 2,
      practiceDrill: 'Arpeggiate Eb Major across two octaves.',
      variants: [
        SaxFingeringVariant(
          label: 'Primary Low Eb',
          pressedKeys: {..._fullStack, SaxKeyId.lowEb},
          tip: 'Right pinky depresses top roller key (Eb).',
        ),
      ],
    ),
    SaxFingeringEntry(
      writtenNote: 'E4',
      enharmonicLabel: '',
      midiNote: 64,
      register: 'Low',
      tendencyCents: 0,
      practiceDrill: 'E Major pentatonic slurs.',
      variants: [
        SaxFingeringVariant(
          label: 'Standard (1-2-3 | 4-5)',
          pressedKeys: {..._lhStack, SaxKeyId.rh4, SaxKeyId.rh5},
          tip: 'Clean, centered tone in the lower stack.',
        ),
      ],
    ),
    SaxFingeringEntry(
      writtenNote: 'F4',
      enharmonicLabel: '',
      midiNote: 65,
      register: 'Low',
      tendencyCents: 0,
      practiceDrill: 'Bb blues scale starting on F4.',
      variants: [
        SaxFingeringVariant(
          label: 'Standard (1-2-3 | 4)',
          pressedKeys: {..._lhStack, SaxKeyId.rh4},
          tip: 'Core warm horn resonance; great starting pitch for long tones.',
        ),
      ],
    ),
    SaxFingeringEntry(
      writtenNote: 'F#4',
      enharmonicLabel: 'Gb4',
      midiNote: 66,
      register: 'Low',
      tendencyCents: 3,
      practiceDrill: 'Alternate between standard 5 and Fork F# in chromatic passages.',
      variants: [
        SaxFingeringVariant(
          label: 'Primary (1-2-3 | 5)',
          pressedKeys: {..._lhStack, SaxKeyId.rh5},
          tip: 'Primary F# for diatonic and melodic playing.',
        ),
        SaxFingeringVariant(
          label: 'Fork / Chromatic F# (1-2-3 | 4 + Tf#)',
          pressedKeys: {..._lhStack, SaxKeyId.rh4, SaxKeyId.sideFSharp},
          tip: 'Use when slurring rapidly between F4 and F#4 to avoid finger flip.',
        ),
      ],
    ),
    SaxFingeringEntry(
      writtenNote: 'G4',
      enharmonicLabel: '',
      midiNote: 67,
      register: 'Middle',
      tendencyCents: 0,
      practiceDrill: 'Slur over the break G4 -> D5 -> G4.',
      variants: [
        SaxFingeringVariant(
          label: 'Standard (1-2-3)',
          pressedKeys: {..._lhStack},
          tip: 'Left-hand stack only; keep right-hand fingers hovering close to pearls.',
        ),
      ],
    ),
    SaxFingeringEntry(
      writtenNote: 'G#4',
      enharmonicLabel: 'Ab4',
      midiNote: 68,
      register: 'Middle',
      tendencyCents: 2,
      practiceDrill: 'Practice G# pinky articulated stays down during right-hand notes.',
      variants: [
        SaxFingeringVariant(
          label: 'Standard (1-2-3 + G#)',
          pressedKeys: {..._lhStack, SaxKeyId.gSharp},
          tip: 'Modern saxophones have an articulated G# link—you can leave G# down when playing F/E/D.',
        ),
      ],
    ),
    SaxFingeringEntry(
      writtenNote: 'A4',
      enharmonicLabel: '',
      midiNote: 69,
      register: 'Middle',
      tendencyCents: 0,
      practiceDrill: 'Concert tuning check (A4 on Alto = Concert C5; F#5 on Alto = Concert A4 440 Hz).',
      variants: [
        SaxFingeringVariant(
          label: 'Standard (1-2)',
          pressedKeys: {SaxKeyId.lh1, SaxKeyId.lh2},
          tip: 'Stable middle-register reference note.',
        ),
      ],
    ),
    SaxFingeringEntry(
      writtenNote: 'Bb4',
      enharmonicLabel: 'A#4',
      midiNote: 70,
      register: 'Middle',
      tendencyCents: 0,
      practiceDrill: 'Master all 4 Bb fingerings across flat keys, arpeggios, and chromatic lines.',
      variants: [
        SaxFingeringVariant(
          label: 'Bis Bb (1 + Bis)',
          pressedKeys: {SaxKeyId.lh1, SaxKeyId.bis},
          tip: 'Roll left index finger to cover both 1 and Bis pearl; ideal in flat keys (F, Bb, Eb, Ab).',
        ),
        SaxFingeringVariant(
          label: 'Side Bb (1-2 + Ta)',
          pressedKeys: {SaxKeyId.lh1, SaxKeyId.lh2, SaxKeyId.sideTa},
          tip: 'Press bottom right side key (Ta) with base of right index finger; best for A <-> Bb chromatic passages.',
        ),
        SaxFingeringVariant(
          label: '1 + 1 (1 | 4)',
          pressedKeys: {SaxKeyId.lh1, SaxKeyId.rh4},
          tip: 'Great when arpeggiating F -> Bb -> D.',
        ),
      ],
    ),
    SaxFingeringEntry(
      writtenNote: 'B4',
      enharmonicLabel: '',
      midiNote: 71,
      register: 'Middle',
      tendencyCents: 0,
      practiceDrill: 'B4 -> C5 -> D5 break-crossing smoothness drill.',
      variants: [
        SaxFingeringVariant(
          label: 'Standard (1)',
          pressedKeys: {SaxKeyId.lh1},
          tip: 'Single left index key; keep left thumb resting lightly on the octave rest.',
        ),
      ],
    ),
    SaxFingeringEntry(
      writtenNote: 'C5',
      enharmonicLabel: '',
      midiNote: 72,
      register: 'Middle',
      tendencyCents: -2,
      practiceDrill: 'Practice B4 <-> C5 with Side C (Tc) vs Middle C (2).',
      variants: [
        SaxFingeringVariant(
          label: 'Standard (2)',
          pressedKeys: {SaxKeyId.lh2},
          tip: 'Left middle finger only.',
        ),
        SaxFingeringVariant(
          label: 'Side C (1 + Tc)',
          pressedKeys: {SaxKeyId.lh1, SaxKeyId.sideTc},
          tip: 'Eliminates finger flip when trilling or moving rapidly between B4 and C5.',
        ),
      ],
    ),
    SaxFingeringEntry(
      writtenNote: 'C#5',
      enharmonicLabel: 'Db5',
      midiNote: 73,
      register: 'Middle',
      tendencyCents: -12,
      practiceDrill: 'Compare Open C#5 against Covered C#5 (3 + Oct) with a drone.',
      variants: [
        SaxFingeringVariant(
          label: 'Open (No keys pressed)',
          pressedKeys: {},
          tip: 'All keys open—naturally tends flat & hollow; raise tongue ("ee") or use Covered C#.',
        ),
        SaxFingeringVariant(
          label: 'Covered / Corrected (3 + Oct)',
          pressedKeys: {SaxKeyId.oct, SaxKeyId.lh3},
          tip: 'Adds resistance, darkens tone to match D5, and raises pitch into tune.',
        ),
      ],
    ),
    SaxFingeringEntry(
      writtenNote: 'D5',
      enharmonicLabel: '',
      midiNote: 74,
      register: 'Middle',
      tendencyCents: 10,
      practiceDrill: 'Slur C5 -> D5 -> E5 matching warmth across the octave break.',
      variants: [
        SaxFingeringVariant(
          label: 'Standard (Oct + 1-2-3 | 4-5-6)',
          pressedKeys: {SaxKeyId.oct, ..._fullStack},
          tip: 'First note over the break; tends ~10¢ sharp—drop jaw slightly and voice warm.',
        ),
      ],
    ),
    SaxFingeringEntry(
      writtenNote: 'Eb5',
      enharmonicLabel: 'D#5',
      midiNote: 75,
      register: 'Middle',
      tendencyCents: 8,
      practiceDrill: 'Eb5 long tones with concert drone.',
      variants: [
        SaxFingeringVariant(
          label: 'Standard (Oct + 1-2-3 | 4-5-6 + Eb)',
          pressedKeys: {SaxKeyId.oct, ..._fullStack, SaxKeyId.lowEb},
          tip: 'Keep throat open over the octave break.',
        ),
      ],
    ),
    SaxFingeringEntry(
      writtenNote: 'E5',
      enharmonicLabel: '',
      midiNote: 76,
      register: 'Middle',
      tendencyCents: 5,
      practiceDrill: 'E5 -> F#5 -> G#5 lyrical legato study.',
      variants: [
        SaxFingeringVariant(
          label: 'Standard (Oct + 1-2-3 | 4-5)',
          pressedKeys: {SaxKeyId.oct, ..._lhStack, SaxKeyId.rh4, SaxKeyId.rh5},
          tip: 'Upper-stack octave vent engages cleanly above G#5.',
        ),
      ],
    ),
    SaxFingeringEntry(
      writtenNote: 'F5',
      enharmonicLabel: '',
      midiNote: 77,
      register: 'Middle',
      tendencyCents: 3,
      practiceDrill: 'Concert Ab4 (on Alto) / Eb4 (on Tenor) band tuning note.',
      variants: [
        SaxFingeringVariant(
          label: 'Standard (Oct + 1-2-3 | 4)',
          pressedKeys: {SaxKeyId.oct, ..._lhStack, SaxKeyId.rh4},
          tip: 'Standard wind ensemble tuning pitch for Alto (Concert Ab) & Tenor (Concert Eb).',
        ),
      ],
    ),
    SaxFingeringEntry(
      writtenNote: 'F#5',
      enharmonicLabel: 'Gb5',
      midiNote: 78,
      register: 'Middle',
      tendencyCents: 4,
      practiceDrill: 'Concert A4 (440 Hz) tuning reference for Eb Alto & Baritone Sax.',
      variants: [
        SaxFingeringVariant(
          label: 'Primary (Oct + 1-2-3 | 5)',
          pressedKeys: {SaxKeyId.oct, ..._lhStack, SaxKeyId.rh5},
          tip: 'On Alto Sax, written F#5 is Concert A4 (440 Hz).',
        ),
        SaxFingeringVariant(
          label: 'Fork F# (Oct + 1-2-3 | 4 + Tf#)',
          pressedKeys: {
            SaxKeyId.oct,
            ..._lhStack,
            SaxKeyId.rh4,
            SaxKeyId.sideFSharp,
          },
          tip: 'Chromatic F5 <-> F#5 alternate.',
        ),
      ],
    ),
    SaxFingeringEntry(
      writtenNote: 'G5',
      enharmonicLabel: '',
      midiNote: 79,
      register: 'High',
      tendencyCents: 2,
      practiceDrill: 'Slur G5 -> A5 -> B5 listening for the neck octave pip transition.',
      variants: [
        SaxFingeringVariant(
          label: 'Standard (Oct + 1-2-3)',
          pressedKeys: {SaxKeyId.oct, ..._lhStack},
          tip: 'Highest note using the lower body octave vent before the neck pip opens at A5.',
        ),
      ],
    ),
    SaxFingeringEntry(
      writtenNote: 'G#5',
      enharmonicLabel: 'Ab5',
      midiNote: 80,
      register: 'High',
      tendencyCents: 4,
      practiceDrill: 'G#5 -> A5 -> B5 upper-register connection.',
      variants: [
        SaxFingeringVariant(
          label: 'Standard (Oct + 1-2-3 + G#)',
          pressedKeys: {SaxKeyId.oct, ..._lhStack, SaxKeyId.gSharp},
          tip: 'Keep air speed fast and steady across the G#5 -> A5 neck vent switch.',
        ),
      ],
    ),
    SaxFingeringEntry(
      writtenNote: 'A5',
      enharmonicLabel: '',
      midiNote: 81,
      register: 'High',
      tendencyCents: 6,
      practiceDrill: 'A5 long tone: prevent thin/pinched embouchure.',
      variants: [
        SaxFingeringVariant(
          label: 'Standard (Oct + 1-2)',
          pressedKeys: {SaxKeyId.oct, SaxKeyId.lh1, SaxKeyId.lh2},
          tip: 'Neck octave pip opens here; avoid biting so the tone stays round.',
        ),
      ],
    ),
    SaxFingeringEntry(
      writtenNote: 'Bb5',
      enharmonicLabel: 'A#5',
      midiNote: 82,
      register: 'High',
      tendencyCents: 6,
      practiceDrill: 'Practice Bis Bb5 and Side Bb5 in upper-register bebop lines.',
      variants: [
        SaxFingeringVariant(
          label: 'Bis Bb (Oct + 1 + Bis)',
          pressedKeys: {SaxKeyId.oct, SaxKeyId.lh1, SaxKeyId.bis},
          tip: 'Fastest fingering for flat-key runs.',
        ),
        SaxFingeringVariant(
          label: 'Side Bb (Oct + 1-2 + Ta)',
          pressedKeys: {
            SaxKeyId.oct,
            SaxKeyId.lh1,
            SaxKeyId.lh2,
            SaxKeyId.sideTa,
          },
          tip: 'Best for chromatic A5 <-> Bb5.',
        ),
      ],
    ),
    SaxFingeringEntry(
      writtenNote: 'B5',
      enharmonicLabel: '',
      midiNote: 83,
      register: 'High',
      tendencyCents: 5,
      practiceDrill: 'B5 -> C6 -> D6 palm key transition drill.',
      variants: [
        SaxFingeringVariant(
          label: 'Standard (Oct + 1)',
          pressedKeys: {SaxKeyId.oct, SaxKeyId.lh1},
          tip: 'On Tenor/Soprano Sax, written B5 is Concert A4 (440 Hz).',
        ),
      ],
    ),
    SaxFingeringEntry(
      writtenNote: 'C6',
      enharmonicLabel: '',
      midiNote: 84,
      register: 'High',
      tendencyCents: 6,
      practiceDrill: 'Compare Standard C6 (Oct + 2) vs Side C6 (Oct + 1 + Tc).',
      variants: [
        SaxFingeringVariant(
          label: 'Standard (Oct + 2)',
          pressedKeys: {SaxKeyId.oct, SaxKeyId.lh2},
          tip: 'Standard high C.',
        ),
        SaxFingeringVariant(
          label: 'Side C (Oct + 1 + Tc)',
          pressedKeys: {SaxKeyId.oct, SaxKeyId.lh1, SaxKeyId.sideTc},
          tip: 'Often fuller and better in tune when approaching from B5.',
        ),
      ],
    ),
    SaxFingeringEntry(
      writtenNote: 'C#6',
      enharmonicLabel: 'Db6',
      midiNote: 85,
      register: 'High',
      tendencyCents: 12,
      practiceDrill: 'Stabilize C#6 pitch by adding right-hand 4-5 or Low Bb.',
      variants: [
        SaxFingeringVariant(
          label: 'Standard (Oct only)',
          pressedKeys: {SaxKeyId.oct},
          tip: 'Tends sharp on many horns; add RH 5-6 if needed to shade pitch down.',
        ),
      ],
    ),
    SaxFingeringEntry(
      writtenNote: 'D6',
      enharmonicLabel: '',
      midiNote: 86,
      register: 'Palm',
      tendencyCents: 8,
      practiceDrill: 'Palm key scale: D6 - E6 - F6 - F#6.',
      variants: [
        SaxFingeringVariant(
          label: 'Palm D (Oct + Palm D)',
          pressedKeys: {SaxKeyId.oct, SaxKeyId.palmD},
          tip: 'Open palm D with base of left index finger while keeping fingers 1-2-3 poised over pearls.',
        ),
      ],
    ),
    SaxFingeringEntry(
      writtenNote: 'Eb6',
      enharmonicLabel: 'D#6',
      midiNote: 87,
      register: 'Palm',
      tendencyCents: 8,
      practiceDrill: 'Palm D -> Palm Eb chromatic articulation.',
      variants: [
        SaxFingeringVariant(
          label: 'Palm D + Eb (Oct + Palm D + Palm Eb)',
          pressedKeys: {SaxKeyId.oct, SaxKeyId.palmD, SaxKeyId.palmEb},
          tip: 'Depress both Palm D and Palm Eb together.',
        ),
      ],
    ),
    SaxFingeringEntry(
      writtenNote: 'E6',
      enharmonicLabel: '',
      midiNote: 88,
      register: 'Palm',
      tendencyCents: 10,
      practiceDrill: 'Practice both Palm E6 and Front E6 for smooth approaches.',
      variants: [
        SaxFingeringVariant(
          label: 'Palm E (Oct + Palm D + Palm Eb + Side Te)',
          pressedKeys: {
            SaxKeyId.oct,
            SaxKeyId.palmD,
            SaxKeyId.palmEb,
            SaxKeyId.sideTe,
          },
          tip: 'Standard full-projection High E.',
        ),
        SaxFingeringVariant(
          label: 'Front E (Oct + Front F + 2 + 3)',
          pressedKeys: {
            SaxKeyId.oct,
            SaxKeyId.frontF,
            SaxKeyId.lh2,
            SaxKeyId.lh3,
          },
          tip: 'Keeps fingers on the main stack when leaping from A5/B5/C6.',
        ),
      ],
    ),
    SaxFingeringEntry(
      writtenNote: 'F6',
      enharmonicLabel: '',
      midiNote: 89,
      register: 'Palm',
      tendencyCents: 10,
      practiceDrill: 'Alternate Front F6 and Palm F6 in high arpeggios.',
      variants: [
        SaxFingeringVariant(
          label: 'Front F (Oct + Front F + 2)',
          pressedKeys: {SaxKeyId.oct, SaxKeyId.frontF, SaxKeyId.lh2},
          tip: 'Roll left index up to Front F spatula + middle finger (2); slightly darker & better in tune.',
        ),
        SaxFingeringVariant(
          label: 'Palm F (Oct + Palm D + Eb + F + Te)',
          pressedKeys: {
            SaxKeyId.oct,
            SaxKeyId.palmD,
            SaxKeyId.palmEb,
            SaxKeyId.palmF,
            SaxKeyId.sideTe,
          },
          tip: 'All three left palm keys + right high E (Te).',
        ),
      ],
    ),
    SaxFingeringEntry(
      writtenNote: 'F#6',
      enharmonicLabel: 'Gb6',
      midiNote: 90,
      register: 'Palm',
      tendencyCents: 12,
      practiceDrill: 'Approach F#6 from Front F6 using Side Ta.',
      variants: [
        SaxFingeringVariant(
          label: 'Front F# (Oct + Front F + 2 + Ta)',
          pressedKeys: {
            SaxKeyId.oct,
            SaxKeyId.frontF,
            SaxKeyId.lh2,
            SaxKeyId.sideTa,
          },
          tip: 'Works on both vintage (Mark VI) and modern horns; gateways into Altissimo G6.',
        ),
        SaxFingeringVariant(
          label: 'High F# Key (Oct + Palm D/Eb/F + Te + High F#)',
          pressedKeys: {
            SaxKeyId.oct,
            SaxKeyId.palmD,
            SaxKeyId.palmEb,
            SaxKeyId.palmF,
            SaxKeyId.sideTe,
            SaxKeyId.highFSharp,
          },
          tip: 'Uses dedicated right-hand High F# key on modern saxophones.',
        ),
      ],
    ),
    SaxFingeringEntry(
      writtenNote: 'G6',
      enharmonicLabel: 'Altissimo G',
      midiNote: 91,
      register: 'Altissimo',
      tendencyCents: -4,
      practiceDrill: 'Voice the 4th overtone of Low Bb3 before fingering Altissimo G6.',
      variants: [
        SaxFingeringVariant(
          label: 'Front Altissimo G (Oct + Front F + 4 + Ta)',
          pressedKeys: {
            SaxKeyId.oct,
            SaxKeyId.frontF,
            SaxKeyId.rh4,
            SaxKeyId.sideTa,
          },
          tip: 'Arch back of tongue ("ee-yah") without biting; air speed + larynx position lock the harmonic.',
        ),
        SaxFingeringVariant(
          label: '1 + 3 + 4 + Tc Altissimo G',
          pressedKeys: {
            SaxKeyId.oct,
            SaxKeyId.lh1,
            SaxKeyId.lh3,
            SaxKeyId.rh4,
            SaxKeyId.sideTc,
          },
          tip: 'Stable long-tone Altissimo G on Alto & Tenor.',
        ),
      ],
    ),
    SaxFingeringEntry(
      writtenNote: 'G#6',
      enharmonicLabel: 'Altissimo Ab',
      midiNote: 92,
      register: 'Altissimo',
      tendencyCents: 0,
      practiceDrill: 'Slur F#6 -> G6 -> G#6 -> A6 slowly.',
      variants: [
        SaxFingeringVariant(
          label: '2 + 3 + 4 + Tc (Oct + 2-3 | 4 + Tc)',
          pressedKeys: {
            SaxKeyId.oct,
            SaxKeyId.lh2,
            SaxKeyId.lh3,
            SaxKeyId.rh4,
            SaxKeyId.sideTc,
          },
          tip: 'Smooth transition into Altissimo A6 by lifting RH 4.',
        ),
      ],
    ),
    SaxFingeringEntry(
      writtenNote: 'A6',
      enharmonicLabel: 'Altissimo A',
      midiNote: 93,
      register: 'Altissimo',
      tendencyCents: 2,
      practiceDrill: 'Match pitch with A5 one octave below.',
      variants: [
        SaxFingeringVariant(
          label: '2 + 3 (Oct + 2-3)',
          pressedKeys: {SaxKeyId.oct, SaxKeyId.lh2, SaxKeyId.lh3},
          tip: 'One of the freest-speaking altissimo notes; add RH 4-5-6 + Low Eb for extra core.',
        ),
      ],
    ),
    SaxFingeringEntry(
      writtenNote: 'Bb6',
      enharmonicLabel: 'Altissimo A#',
      midiNote: 94,
      register: 'Altissimo',
      tendencyCents: 4,
      practiceDrill: 'Bb4 -> Bb5 -> Bb6 three-octave arpeggio top note.',
      variants: [
        SaxFingeringVariant(
          label: '3 + Ta (Oct + 3 + Side Ta)',
          pressedKeys: {SaxKeyId.oct, SaxKeyId.lh3, SaxKeyId.sideTa},
          tip: 'Keep oral cavity focused ("hee") and support with fast air.',
        ),
      ],
    ),
    SaxFingeringEntry(
      writtenNote: 'B6',
      enharmonicLabel: 'Altissimo B',
      midiNote: 95,
      register: 'Altissimo',
      tendencyCents: 5,
      practiceDrill: 'Overblow High D6 palm key harmonic.',
      variants: [
        SaxFingeringVariant(
          label: 'Oct + 1 + 3 + Palm D',
          pressedKeys: {
            SaxKeyId.oct,
            SaxKeyId.lh1,
            SaxKeyId.lh3,
            SaxKeyId.palmD,
          },
          tip: 'Responsive altissimo B6 on both Alto and Tenor.',
        ),
      ],
    ),
    SaxFingeringEntry(
      writtenNote: 'C7',
      enharmonicLabel: 'Altissimo C',
      midiNote: 96,
      register: 'Altissimo',
      tendencyCents: 6,
      practiceDrill: 'Three-octave C Major scale pinnacle.',
      variants: [
        SaxFingeringVariant(
          label: 'Oct + 1 + Palm D + Palm Eb',
          pressedKeys: {
            SaxKeyId.oct,
            SaxKeyId.lh1,
            SaxKeyId.palmD,
            SaxKeyId.palmEb,
          },
          tip: 'High harmonic node—use focused air stream without pinching reed shut.',
        ),
      ],
    ),
  ];

  /// Finds the primary middle-register fingering entry matching a pitch class name (`C`, `Db`, `F#`, etc.).
  static SaxFingeringEntry fingeringForPitchClass(String noteName) {
    final targetPc = HornTransposer.pitchClassIndex(noteName);
    return fingerings.firstWhere(
      (f) => f.midiNote >= 60 && (f.midiNote % 12) == targetPc,
      orElse: () => fingerings.first,
    );
  }

  /// Complete scale, mode, bebop, arpeggio, and jazz vocabulary definitions.
  static const List<SaxScaleDefinition> scales = <SaxScaleDefinition>[
    SaxScaleDefinition(
      id: 'major',
      name: 'Major (Ionian)',
      category: 'Fundamental',
      semitoneIntervals: [0, 2, 4, 5, 7, 9, 11],
      degreeFormula: '1 - 2 - 3 - 4 - 5 - 6 - 7',
      chordSymbolSuffix: 'Maj7',
      improvisationTip: 'Practice full-range (Low Bb to High F#) in eighth notes and diatonic 3rds.',
    ),
    SaxScaleDefinition(
      id: 'dorian',
      name: 'Dorian Mode (ii-7)',
      category: 'Jazz Modes',
      semitoneIntervals: [0, 2, 3, 5, 7, 9, 10],
      degreeFormula: '1 - 2 - b3 - 4 - 5 - 6 - b7',
      chordSymbolSuffix: 'm7',
      improvisationTip: 'Primary minor jazz mode (So What, Impressions, ii chord in ii-V-I). Emphasize the natural 6th.',
    ),
    SaxScaleDefinition(
      id: 'mixolydian',
      name: 'Mixolydian Mode (V7)',
      category: 'Jazz Modes',
      semitoneIntervals: [0, 2, 4, 5, 7, 9, 10],
      degreeFormula: '1 - 2 - 3 - 4 - 5 - 6 - b7',
      chordSymbolSuffix: '7',
      improvisationTip: 'Dominant 7th sound; resolve the 4th to the 3rd and b7 to the 3rd of the I chord.',
    ),
    SaxScaleDefinition(
      id: 'blues',
      name: 'Jazz & Soul Blues Scale',
      category: 'Bebop & Blues',
      semitoneIntervals: [0, 3, 5, 6, 7, 10],
      degreeFormula: '1 - b3 - 4 - #4/b5 - 5 - b7',
      chordSymbolSuffix: '7',
      improvisationTip: 'Scoop into the b3 and blue note (b5) with vocal inflection and side/bis fingerings.',
    ),
    SaxScaleDefinition(
      id: 'bebop_dominant',
      name: 'Bebop Dominant (8-Note)',
      category: 'Bebop & Blues',
      semitoneIntervals: [0, 2, 4, 5, 7, 9, 10, 11],
      degreeFormula: '1 - 2 - 3 - 4 - 5 - 6 - b7 - 7',
      chordSymbolSuffix: '7',
      improvisationTip: 'Passing major 7th keeps chord tones (1, 3, 5, b7) aligned on strong downbeats in 4/4.',
    ),
    SaxScaleDefinition(
      id: 'minor_pentatonic',
      name: 'Minor Pentatonic',
      category: 'Bebop & Blues',
      semitoneIntervals: [0, 3, 5, 7, 10],
      degreeFormula: '1 - b3 - 4 - 5 - b7',
      chordSymbolSuffix: 'm7',
      improvisationTip: 'Play in 4-note groups across the horn for modern Coltrane/Brecker angular lines.',
    ),
    SaxScaleDefinition(
      id: 'major_pentatonic',
      name: 'Major Pentatonic',
      category: 'Bebop & Blues',
      semitoneIntervals: [0, 2, 4, 7, 9],
      degreeFormula: '1 - 2 - 3 - 5 - 6',
      chordSymbolSuffix: '6/9',
      improvisationTip: 'Superimpose from the 5th of a Maj7 chord (e.g., G Maj Pentatonic over CMaj7 for Lydian color).',
    ),
    SaxScaleDefinition(
      id: 'natural_minor',
      name: 'Natural Minor (Aeolian)',
      category: 'Fundamental',
      semitoneIntervals: [0, 2, 3, 5, 7, 8, 10],
      degreeFormula: '1 - 2 - b3 - 4 - 5 - b6 - b7',
      chordSymbolSuffix: 'm7(b6)',
      improvisationTip: 'Pure relative minor; focus on clean left-pinky G#/Ab table coordination.',
    ),
    SaxScaleDefinition(
      id: 'harmonic_minor',
      name: 'Harmonic Minor',
      category: 'Fundamental',
      semitoneIntervals: [0, 2, 3, 5, 7, 8, 11],
      degreeFormula: '1 - 2 - b3 - 4 - 5 - b6 - 7',
      chordSymbolSuffix: 'm(Maj7)',
      improvisationTip: 'Use over minor ii-V-i cadences (5th mode Phrygian Dominant over V7b9).',
    ),
    SaxScaleDefinition(
      id: 'melodic_minor',
      name: 'Jazz Melodic Minor',
      category: 'Jazz Modes',
      semitoneIntervals: [0, 2, 3, 5, 7, 9, 11],
      degreeFormula: '1 - 2 - b3 - 4 - 5 - 6 - 7',
      chordSymbolSuffix: 'm(Maj7)',
      improvisationTip: 'Play a half-step above a Dominant 7alt chord (e.g., Ab Melodic Minor over G7alt).',
    ),
    SaxScaleDefinition(
      id: 'whole_tone',
      name: 'Whole Tone (6-Note)',
      category: 'Jazz Modes',
      semitoneIntervals: [0, 2, 4, 6, 8, 10],
      degreeFormula: '1 - 2 - 3 - #4 - #5 - b7',
      chordSymbolSuffix: '7#5',
      improvisationTip: 'Symmetrical augmented dominant color (Monk / Wayne Shorter vocabulary).',
    ),
    SaxScaleDefinition(
      id: 'diminished_hw',
      name: 'Diminished Half-Whole (8-Note)',
      category: 'Jazz Modes',
      semitoneIntervals: [0, 1, 3, 4, 6, 7, 9, 10],
      degreeFormula: '1 - b9 - #9 - 3 - #11 - 5 - 13 - b7',
      chordSymbolSuffix: '7(b9,13)',
      improvisationTip: 'Symmetrical dominant scale for V7b9 chords resolving to Major or Minor.',
    ),
    SaxScaleDefinition(
      id: 'arp_maj7',
      name: 'Major 7th Arpeggio & 9th',
      category: 'Arpeggios & Patterns',
      semitoneIntervals: [0, 4, 7, 11, 14],
      degreeFormula: '1 - 3 - 5 - 7 - 9',
      chordSymbolSuffix: 'Maj9',
      improvisationTip: 'Loop in inversions (1-3-5-7, 3-5-7-9) over the entire range of the horn.',
    ),
    SaxScaleDefinition(
      id: 'arp_m7',
      name: 'Minor 7th Arpeggio & 9th',
      category: 'Arpeggios & Patterns',
      semitoneIntervals: [0, 3, 7, 10, 14],
      degreeFormula: '1 - b3 - 5 - b7 - 9',
      chordSymbolSuffix: 'm9',
      improvisationTip: 'Essential ii-7 chord outline; practice connecting into V7 third one half-step below.',
    ),
    SaxScaleDefinition(
      id: 'pattern_1235',
      name: 'Coltrane 1-2-3-5 Digital Pattern',
      category: 'Arpeggios & Patterns',
      semitoneIntervals: [0, 2, 4, 7],
      degreeFormula: '1 - 2 - 3 - 5',
      chordSymbolSuffix: 'Maj7 / 7',
      improvisationTip: 'Take 1-2-3-5 through the Circle of Fourths at 120–200 BPM.',
    ),
  ];
}
