import os
import unittest
from datetime import UTC, datetime
from unittest.mock import patch

from historian_service.config import HistorianConfig
from historian_service.kpi import KpiSummary
from historian_service.telemetry import MemoryLineWriter, SensorEdgeCounter, TelemetryBuffer, TelemetrySample, kpi_summary_to_line_protocol, sample_to_line_protocol
from opcua_server.model import nodes_by_id


class TelemetryTests(unittest.TestCase):
    def test_line_protocol_contains_timestamp_tags_and_fields(self):
        spec = nodes_by_id()["KPIs.ThroughputTotal"]
        sample = TelemetrySample(
            timestamp=datetime(2026, 1, 1, tzinfo=UTC),
            values={"KPIs.ThroughputTotal": 42},
            cell_id="cell A",
        )

        lines = sample_to_line_protocol(sample, specs=[spec])

        self.assertEqual(len(lines), 1)
        self.assertIn("cell_id=cell\\ A", lines[0])
        self.assertIn("throughput_total=42i", lines[0])

    def test_buffer_tracks_dropped_records(self):
        buffer = TelemetryBuffer(max_size=2)
        buffer.append_many(["a", "b", "c"])

        self.assertEqual(len(buffer), 2)
        self.assertEqual(buffer.dropped_records, 1)
        self.assertEqual(buffer.pop_batch(10), ["b", "c"])

    def test_config_requires_secret_and_redacts_it(self):
        env = {
            "MHMC_INFLUX_TOKEN": "secret-token",
        }
        with patch.dict(os.environ, env, clear=True):
            config = HistorianConfig.from_env()

        self.assertEqual(config.influx_token, "secret-token")
        self.assertEqual(config.redacted()["influx_token"], "***")

    def test_kpi_line_protocol_omits_none_fields(self):
        summary = KpiSummary(
            window_s=60.0,
            throughput_per_min=1.0,
            mean_time_between_jams_s=None,
            average_cycle_time_s=None,
            total_packages_delta=1,
            jam_delta=0,
            first_timestamp=None,
            last_timestamp=None,
        )

        line = kpi_summary_to_line_protocol(summary, "mhmc_01", datetime(2026, 1, 1, tzinfo=UTC))

        self.assertIn("throughput_per_min=1.0", line)
        self.assertNotIn("None", line)
        self.assertNotIn("mean_time_between_jams_s", line)

    def test_sensor_edge_counter_counts_rising_edges(self):
        counter = SensorEdgeCounter()
        timestamp = datetime(2026, 1, 1, tzinfo=UTC)

        self.assertIsNone(counter.update(TelemetrySample(timestamp, {"DeviceSet.Conveyor_1.PE1_Blocked": False})))
        first = counter.update(TelemetrySample(timestamp, {"DeviceSet.Conveyor_1.PE1_Blocked": True}))
        held = counter.update(TelemetrySample(timestamp, {"DeviceSet.Conveyor_1.PE1_Blocked": True}))
        counter.update(TelemetrySample(timestamp, {"DeviceSet.Conveyor_1.PE1_Blocked": False}))
        second = counter.update(TelemetrySample(timestamp, {"DeviceSet.Conveyor_1.PE1_Blocked": True}))

        self.assertIn("pe1_infeed_count=1i", first or "")
        self.assertIsNone(held)
        self.assertIn("pe1_infeed_count=2i", second or "")


class MemoryWriterTests(unittest.TestCase):
    def test_memory_writer_records_batches(self):
        writer = MemoryLineWriter()
        writer.write_lines(["a", "b"])
        self.assertEqual(writer.lines, ["a", "b"])


if __name__ == "__main__":
    unittest.main()
