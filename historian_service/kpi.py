"""KPI calculations for timestamped MHMC telemetry."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from statistics import mean

from .telemetry import TelemetrySample


TOTAL_NODE = "KPIs.ThroughputTotal"
JAM_NODE = "KPIs.TotalJams"
HEARTBEAT_NODE = "ControlState.Heartbeat"


@dataclass(frozen=True)
class KpiSummary:
    window_s: float
    throughput_per_min: float
    mean_time_between_jams_s: float | None
    average_cycle_time_s: float | None
    total_packages_delta: int
    jam_delta: int
    first_timestamp: datetime | None
    last_timestamp: datetime | None

    def as_dict(self) -> dict[str, object]:
        return {
            "window_s": self.window_s,
            "throughput_per_min": self.throughput_per_min,
            "mean_time_between_jams_s": self.mean_time_between_jams_s,
            "average_cycle_time_s": self.average_cycle_time_s,
            "total_packages_delta": self.total_packages_delta,
            "jam_delta": self.jam_delta,
            "first_timestamp": self.first_timestamp.isoformat() if self.first_timestamp else None,
            "last_timestamp": self.last_timestamp.isoformat() if self.last_timestamp else None,
        }


def compute_kpis(samples: list[TelemetrySample]) -> KpiSummary:
    ordered = sorted(samples, key=lambda sample: sample.timestamp)
    if len(ordered) < 2:
        return KpiSummary(0.0, 0.0, None, None, 0, 0, ordered[0].timestamp if ordered else None, ordered[0].timestamp if ordered else None)

    first = ordered[0]
    last = ordered[-1]
    window_s = max((last.timestamp - first.timestamp).total_seconds(), 0.0)
    total_delta = _counter_delta(first.value(TOTAL_NODE, 0), last.value(TOTAL_NODE, 0))
    jam_delta = _counter_delta(first.value(JAM_NODE, 0), last.value(JAM_NODE, 0))

    throughput_per_min = (total_delta / (window_s / 60.0)) if window_s > 0.0 else 0.0
    completion_times = _counter_increment_times(ordered, TOTAL_NODE)
    jam_times = _counter_increment_times(ordered, JAM_NODE)
    average_cycle_time_s = _average_delta_seconds(completion_times)
    mean_time_between_jams_s = _average_delta_seconds(jam_times)

    # If only one package completed in the window, use the window-normalized
    # cycle estimate rather than returning no signal for dashboards.
    if average_cycle_time_s is None and total_delta > 0 and window_s > 0.0:
        average_cycle_time_s = window_s / total_delta

    return KpiSummary(
        window_s=window_s,
        throughput_per_min=throughput_per_min,
        mean_time_between_jams_s=mean_time_between_jams_s,
        average_cycle_time_s=average_cycle_time_s,
        total_packages_delta=total_delta,
        jam_delta=jam_delta,
        first_timestamp=first.timestamp,
        last_timestamp=last.timestamp,
    )


def _counter_delta(first: object, last: object) -> int:
    try:
        delta = int(last) - int(first)
    except (TypeError, ValueError):
        return 0
    return max(delta, 0)


def _counter_increment_times(samples: list[TelemetrySample], node_id: str) -> list[datetime]:
    increments: list[datetime] = []
    previous = _to_int(samples[0].value(node_id, 0))
    for sample in samples[1:]:
        current = _to_int(sample.value(node_id, previous))
        if current > previous:
            increments.extend([sample.timestamp] * (current - previous))
        previous = current
    return increments


def _average_delta_seconds(timestamps: list[datetime]) -> float | None:
    if len(timestamps) < 2:
        return None
    deltas = [(right - left).total_seconds() for left, right in zip(timestamps, timestamps[1:])]
    return mean(deltas) if deltas else None


def _to_int(value: object) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0
