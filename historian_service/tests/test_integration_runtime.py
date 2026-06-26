import asyncio
import unittest
from datetime import UTC, datetime, timedelta

from historian_service.collector import HistorianService
from historian_service.config import HistorianConfig
from historian_service.telemetry import MemoryLineWriter, TelemetrySample
from opcua_server.data_provider import InMemoryCellDataProvider
from opcua_server.model import default_values
from opcua_server.server import MHMCOpcUaServer, Server

try:
    from asyncua import Client
except ModuleNotFoundError:  # pragma: no cover - exercised when runtime deps are absent.
    Client = None


class DataChangeRecorder:
    def __init__(self) -> None:
        self.queue: asyncio.Queue[tuple[str, object]] = asyncio.Queue()
        self.seen: list[tuple[str, object]] = []

    def datachange_notification(self, node, value, data) -> None:
        item = (str(node.nodeid.Identifier), value)
        self.seen.append(item)
        self.queue.put_nowait(item)

    async def wait_for_value(self, node_id: str, expected: object, timeout_s: float = 3.0) -> None:
        deadline = asyncio.get_running_loop().time() + timeout_s
        if (node_id, expected) in self.seen:
            return
        while asyncio.get_running_loop().time() < deadline:
            remaining = max(0.05, deadline - asyncio.get_running_loop().time())
            item = await asyncio.wait_for(self.queue.get(), timeout=remaining)
            if item == (node_id, expected):
                return
        raise AssertionError(f"Did not receive {node_id}={expected}; seen={self.seen}")


@unittest.skipIf(Server is None or Client is None, "asyncua runtime dependency is not installed")
class OpcUaHistorianRuntimeIntegrationTests(unittest.IsolatedAsyncioTestCase):
    async def test_concurrent_clients_receive_state_counter_alarm_and_kpi_updates(self):
        provider = InMemoryCellDataProvider()
        server = MHMCOpcUaServer(
            provider=provider,
            endpoint="opc.tcp://127.0.0.1:48412/mhmc/concurrent-test/",
            allow_insecure=True,
        )
        await server.init()
        await server.server.start()

        scada = Client(server.endpoint)
        twin = Client(server.endpoint)
        scada_sub = None
        twin_sub = None
        try:
            await scada.connect()
            await twin.connect()

            scada_recorder = DataChangeRecorder()
            twin_recorder = DataChangeRecorder()
            scada_sub = await scada.create_subscription(25, scada_recorder)
            twin_sub = await twin.create_subscription(25, twin_recorder)

            node_ids = [
                "ControlState.CurrentState",
                "KPIs.ThroughputTotal",
                "Alarms.GeneralJamAlarm",
                "KPIs.OEE",
            ]
            scada_nodes = [scada.get_node(f"ns={server.namespace_index};s={node_id}") for node_id in node_ids]
            twin_nodes = [twin.get_node(f"ns={server.namespace_index};s={node_id}") for node_id in node_ids]
            await scada_sub.subscribe_data_change(scada_nodes)
            await twin_sub.subscribe_data_change(twin_nodes)
            await asyncio.sleep(0.1)

            snapshot = default_values()
            snapshot.update(
                {
                    "ControlState.CurrentState": 2,
                    "KPIs.ThroughputTotal": 7,
                    "Alarms.GeneralJamAlarm": True,
                    "KPIs.OEE": 88.5,
                }
            )
            await server._publish_snapshot(snapshot)

            for recorder in (scada_recorder, twin_recorder):
                await recorder.wait_for_value("ControlState.CurrentState", 2)
                await recorder.wait_for_value("KPIs.ThroughputTotal", 7)
                await recorder.wait_for_value("Alarms.GeneralJamAlarm", True)
                await recorder.wait_for_value("KPIs.OEE", 88.5)
        finally:
            if scada_sub is not None:
                await scada_sub.delete()
            if twin_sub is not None:
                await twin_sub.delete()
            await scada.disconnect()
            await twin.disconnect()
            await server.server.stop()


class HistorianInfluxEntryTests(unittest.TestCase):
    def test_historian_writes_timestamped_values_sensor_counts_and_kpi_rollup(self):
        writer = MemoryLineWriter()
        config = HistorianConfig(
            opcua_endpoint="opc.tcp://127.0.0.1:48412/mhmc/concurrent-test/",
            opcua_namespace_index=2,
            opcua_security_policy="None",
            opcua_security_mode="None",
            opcua_client_certificate=None,
            opcua_client_private_key=None,
            influx_url="http://localhost:8086",
            influx_org="AntigravityAutomation",
            influx_bucket="mhmc_telemetry",
            influx_token="test-token",
            cell_id="mhmc_01",
            sample_period_s=0.1,
            flush_interval_s=0.5,
            max_batch_size=1000,
            max_buffer_size=10000,
            kpi_window_s=300.0,
        )
        service = HistorianService(config, writer=writer)

        t0 = datetime(2026, 1, 1, tzinfo=UTC)
        baseline = default_values()
        baseline.update(
            {
                "KPIs.ThroughputTotal": 10,
                "KPIs.TotalJams": 1,
                "DeviceSet.Conveyor_1.PE1_Blocked": False,
            }
        )
        active = dict(baseline)
        active.update(
            {
                "ControlState.CurrentState": 2,
                "DeviceSet.Conveyor_1.SpeedFeedback": 0.42,
                "DeviceSet.Conveyor_1.PE1_Blocked": True,
                "KPIs.ThroughputTotal": 12,
                "KPIs.TotalJams": 2,
                "KPIs.OEE": 90.0,
                "Alarms.GeneralJamAlarm": True,
                "EventTimeline.LastSequence": 44,
                "EventTimeline.LastMessage": "Package jam detected on main conveyor",
            }
        )

        service.ingest(TelemetrySample(t0, baseline, "mhmc_01"))
        service.ingest(TelemetrySample(t0 + timedelta(seconds=30), active, "mhmc_01"))
        service.flush()

        joined = "\n".join(writer.lines)
        timestamp_ns = str(int((t0 + timedelta(seconds=30)).timestamp() * 1_000_000_000))

        self.assertIn("conveyor_telemetry", joined)
        self.assertIn("speed_feedback=0.42", joined)
        self.assertIn(f"throughput_total=12i {timestamp_ns}", joined)
        self.assertIn(f"general_jam_alarm=true {timestamp_ns}", joined)
        self.assertIn(f"last_sequence=44i {timestamp_ns}", joined)
        self.assertIn(f"pe1_infeed_count=1i", joined)
        self.assertIn("computed_kpis", joined)
        self.assertIn("throughput_per_min=4.0", joined)
        self.assertIn("jam_delta=1i", joined)


if __name__ == "__main__":
    unittest.main()
