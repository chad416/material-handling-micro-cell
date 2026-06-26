import tempfile
import unittest
from pathlib import Path

from opcua_server.generate_cert import build_certificate
from opcua_server.server import MHMCOpcUaServer, Server


@unittest.skipIf(Server is None, "asyncua runtime dependency is not installed")
class OpcUaRuntimeTests(unittest.IsolatedAsyncioTestCase):
    async def test_namespace_initializes_with_insecure_local_mode(self):
        server = MHMCOpcUaServer(
            endpoint="opc.tcp://127.0.0.1:48410/mhmc/test/",
            allow_insecure=True,
        )
        await server.init()
        self.assertEqual(len(server.nodes_by_id), 59)
        self.assertGreater(server.namespace_index, 0)
        await server.server.start()
        try:
            await server._publish_alarm_event_if_needed(
                {
                    "EventTimeline.LastSequence": 1,
                    "EventTimeline.LastSeverity": 800,
                    "EventTimeline.LastMessage": "Runtime smoke alarm event",
                }
            )
            self.assertEqual(server.last_alarm_sequence, 1)
        finally:
            await server.server.stop()

    async def test_namespace_initializes_with_certificate_security(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            cert_der, key_pem = build_certificate("localhost", "Antigravity Automation Test", 30)
            cert_path = Path(temp_dir) / "server.der"
            key_path = Path(temp_dir) / "server-key.pem"
            cert_path.write_bytes(cert_der)
            key_path.write_bytes(key_pem)

            server = MHMCOpcUaServer(
                endpoint="opc.tcp://127.0.0.1:48411/mhmc/test-secure/",
                certificate=cert_path,
                private_key=key_path,
            )
            await server.init()
            self.assertEqual(len(server.nodes_by_id), 59)
            self.assertGreater(server.namespace_index, 0)
            await server.server.start()
            await server.server.stop()


if __name__ == "__main__":
    unittest.main()
