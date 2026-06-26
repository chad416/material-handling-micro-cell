import asyncio
import unittest

from opcua_server.data_provider import InMemoryCellDataProvider, build_plc_fieldbus_mapping
from opcua_server.model import NODE_SPECS, REQUIRED_NODE_IDS, NodeAccess, default_values, nodes_by_id, specs_for_category


class OpcUaModelTests(unittest.TestCase):
    def test_required_namespace_nodes_are_present(self):
        node_ids = set(nodes_by_id())
        self.assertTrue(REQUIRED_NODE_IDS.issubset(node_ids))

    def test_nodes_are_semantic_not_raw_tags(self):
        for spec in NODE_SPECS:
            self.assertNotIn("%I", spec.plc_symbol)
            self.assertNotIn("%Q", spec.plc_symbol)
            self.assertIn(".", spec.node_id)
            self.assertTrue(spec.description)

    def test_access_levels_are_explicit(self):
        writable = {spec.node_id for spec in NODE_SPECS if spec.access == NodeAccess.READ_WRITE}
        self.assertIn("DeviceSet.Conveyor_1.SpeedSetpoint", writable)
        self.assertIn("ControlState.CurrentMode", writable)
        self.assertIn("Recipes.TargetSpeed", writable)
        self.assertIn("Alarms.Acknowledge", writable)

    def test_coverage_by_category(self):
        for category in ["machine", "state", "kpi", "alarm", "maintenance", "recipe", "event", "integration"]:
            self.assertGreater(len(specs_for_category(category)), 0, category)

    def test_default_snapshot_has_every_node(self):
        values = default_values()
        self.assertEqual(set(values), set(nodes_by_id()))

    def test_fieldbus_mapping_is_complete(self):
        mapping = build_plc_fieldbus_mapping()
        self.assertEqual(len(mapping), len(NODE_SPECS))
        self.assertTrue(all(row["plc_symbol"].startswith("Main.") for row in mapping))


class InMemoryProviderTests(unittest.IsolatedAsyncioTestCase):
    async def test_writable_values_are_coerced(self):
        provider = InMemoryCellDataProvider()
        await provider.write_value("DeviceSet.Conveyor_1.SpeedSetpoint", "0.75")
        snapshot = await provider.read_snapshot()
        self.assertEqual(snapshot["DeviceSet.Conveyor_1.SpeedSetpoint"], 0.75)

    async def test_read_only_write_is_rejected(self):
        provider = InMemoryCellDataProvider()
        with self.assertRaises(PermissionError):
            await provider.write_value("KPIs.OEE", 10.0)

    async def test_load_recipe_status_codes(self):
        provider = InMemoryCellDataProvider()
        self.assertEqual(await provider.load_recipe(1, 0.5), 0)
        self.assertEqual(await provider.load_recipe(1, 9.0), -1)
        self.assertEqual(await provider.load_recipe(999, 0.5), -2)

    async def test_command_pulses_update_state(self):
        provider = InMemoryCellDataProvider()
        self.assertTrue(await provider.pulse_command("StartCell"))
        snapshot = await provider.read_snapshot()
        self.assertEqual(snapshot["ControlState.CurrentState"], 1)
        self.assertTrue(provider.commands.xRemoteStart)


if __name__ == "__main__":
    unittest.main()
