#!/usr/bin/env python3
"""Check media comparisons across FFprobe's optional packet duration output."""

from copy import deepcopy
import sys
import unittest

sys.dont_write_bytecode = True
from verify_fmp4 import packets_for


class MediaProbeTests(unittest.TestCase):
    def setUp(self):
        self.original = {
            'streams': [{'index': 0, 'codec_type': 'audio', 'sample_rate': '48000', 'time_base': '1/48000',
                         'decoded_frames': [{'pts': 0, 'nb_samples': 1024}, {'pts': 1600, 'nb_samples': 1024}]}],
            'packets': [
                {'stream_index': 0, 'pts': 0, 'dts': 0, 'duration': 1024, 'size': '280', 'data_hash': 'first'},
                {'stream_index': 0, 'pts': 1600, 'dts': 1600, 'duration': 1024, 'size': '290', 'data_hash': 'second'},
            ],
        }
        self.omitted = deepcopy(self.original)
        del self.omitted['packets'][0]['duration']

    def test_missing_duration_uses_decoded_samples_despite_timestamp_gap(self):
        self.assertEqual(packets_for(self.original, 'audio'), packets_for(self.omitted, 'audio'))
        self.assertNotIn('duration', self.omitted['packets'][0])

    def test_changed_payload_timestamps_size_or_explicit_duration_still_differ(self):
        for field, value in [('data_hash', 'corrupt'), ('pts', 1), ('dts', 1), ('size', '281'), ('duration', 512)]:
            with self.subTest(field=field):
                changed = deepcopy(self.original)
                changed['packets'][0][field] = value
                self.assertNotEqual(packets_for(self.original, 'audio'), packets_for(changed, 'audio'))

    def test_missing_duration_requires_one_decoded_frame_at_the_packet_timestamp(self):
        for frames in [[], [{'pts': 1, 'nb_samples': 1024}], [{'pts': 0, 'nb_samples': 0}],
                       [{'pts': 0, 'nb_samples': 1024}] * 2]:
            with self.subTest(frames=frames):
                self.omitted['streams'][0]['decoded_frames'] = frames
                with self.assertRaisesRegex(AssertionError, 'Cannot determine audio packet 0 duration'):
                    packets_for(self.omitted, 'audio')

    def test_decoded_duration_is_converted_to_the_packet_time_base_exactly(self):
        self.omitted['streams'][0]['time_base'] = '1/24000'
        self.assertEqual(packets_for(self.omitted, 'audio')[0]['duration'], 512)
        self.omitted['streams'][0]['time_base'] = '1/1000'
        with self.assertRaisesRegex(AssertionError, 'Non-integral audio packet 0 duration'):
            packets_for(self.omitted, 'audio')


if __name__ == '__main__':
    unittest.main()
