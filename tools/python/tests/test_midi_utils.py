import unittest
import mido

from tools.python.midi_to_ass import collect_note_pairs, seconds_from_ticks


class MidiUtilsTests(unittest.TestCase):
    def test_collect_note_pairs_handles_overlapping_notes(self):
        track = mido.MidiTrack()
        track.append(mido.Message("note_on", note=60, velocity=64, time=0))
        track.append(mido.Message("note_on", note=60, velocity=64, time=10))
        track.append(mido.Message("note_off", note=60, velocity=0, time=20))
        track.append(mido.Message("note_off", note=60, velocity=0, time=10))

        pairs = collect_note_pairs(track)

        self.assertEqual(pairs, [(0, 10), (10, 30)])

    def test_seconds_from_ticks_uses_tempo_events(self):
        tempo_events = [(0, 500000), (480, 250000)]

        self.assertAlmostEqual(seconds_from_ticks(480, 480, tempo_events), 0.5)
        self.assertAlmostEqual(seconds_from_ticks(960, 480, tempo_events), 0.75)


if __name__ == "__main__":
    unittest.main()
