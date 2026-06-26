import unittest
from datetime import UTC, datetime, timedelta

from historian_service.kpi import compute_kpis
from historian_service.telemetry import TelemetrySample


class KpiTests(unittest.TestCase):
    def test_throughput_cycle_time_and_jam_metrics(self):
        start = datetime(2026, 1, 1, tzinfo=UTC)
        samples = [
            TelemetrySample(start, {"KPIs.ThroughputTotal": 10, "KPIs.TotalJams": 1}),
            TelemetrySample(start + timedelta(seconds=10), {"KPIs.ThroughputTotal": 11, "KPIs.TotalJams": 1}),
            TelemetrySample(start + timedelta(seconds=20), {"KPIs.ThroughputTotal": 12, "KPIs.TotalJams": 2}),
            TelemetrySample(start + timedelta(seconds=30), {"KPIs.ThroughputTotal": 13, "KPIs.TotalJams": 3}),
        ]

        summary = compute_kpis(samples)

        self.assertAlmostEqual(summary.throughput_per_min, 6.0)
        self.assertAlmostEqual(summary.average_cycle_time_s or 0.0, 10.0)
        self.assertAlmostEqual(summary.mean_time_between_jams_s or 0.0, 10.0)
        self.assertEqual(summary.total_packages_delta, 3)
        self.assertEqual(summary.jam_delta, 2)

    def test_single_completion_uses_window_normalized_cycle_time(self):
        start = datetime(2026, 1, 1, tzinfo=UTC)
        samples = [
            TelemetrySample(start, {"KPIs.ThroughputTotal": 1, "KPIs.TotalJams": 0}),
            TelemetrySample(start + timedelta(seconds=30), {"KPIs.ThroughputTotal": 2, "KPIs.TotalJams": 0}),
        ]

        summary = compute_kpis(samples)

        self.assertAlmostEqual(summary.average_cycle_time_s or 0.0, 30.0)
        self.assertIsNone(summary.mean_time_between_jams_s)


if __name__ == "__main__":
    unittest.main()
