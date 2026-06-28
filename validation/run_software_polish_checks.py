"""Validate portfolio-polish assets for the MHMC software package.

This runner focuses on the non-PLC polish layer: visual twin assets,
one-command demo tooling, evidence packaging, and secure OPC UA connectivity.
It writes a markdown report so the portfolio can show repeatable software
evidence without relying on verbal claims.
"""

from __future__ import annotations

import asyncio
import json
import sys
import tempfile
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Callable

ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / "validation" / "results"
sys.path.insert(0, str(ROOT))

from opcua_server.generate_cert import build_certificate
from opcua_server.server import MHMCOpcUaServer, Server


@dataclass
class CheckResult:
    suite: str
    check: str
    passed: bool
    detail: str = ""


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def file_exists(path: str) -> Callable[[], tuple[bool, str]]:
    def check() -> tuple[bool, str]:
        target = ROOT / path
        return target.exists(), str(target)

    return check


def text_contains(path: str, *needles: str) -> Callable[[], tuple[bool, str]]:
    def check() -> tuple[bool, str]:
        target = ROOT / path
        text = read_text(target)
        missing = [needle for needle in needles if needle not in text]
        return not missing, f"missing={missing}" if missing else "all expected text present"

    return check


def powershell_has_cmdlet_binding(path: str) -> Callable[[], tuple[bool, str]]:
    return text_contains(path, "[CmdletBinding()]", "$ErrorActionPreference = \"Stop\"")


async def secure_opcua_smoke() -> tuple[bool, str]:
    if Server is None:
        return False, "asyncua is not installed"

    try:
        from asyncua import Client, ua
        from asyncua.crypto.security_policies import SecurityPolicyBasic256Sha256
    except ModuleNotFoundError as exc:
        return False, f"asyncua client dependency missing: {exc}"

    with tempfile.TemporaryDirectory() as temp_dir:
        temp = Path(temp_dir)
        cert_der, key_pem = build_certificate("127.0.0.1", "Antigravity Automation Test", 30)
        cert_path = temp / "secure-smoke.der"
        key_path = temp / "secure-smoke-key.pem"
        cert_path.write_bytes(cert_der)
        key_path.write_bytes(key_pem)

        server = MHMCOpcUaServer(
            endpoint="opc.tcp://127.0.0.1:48512/mhmc/secure-polish/",
            certificate=cert_path,
            private_key=key_path,
        )
        await server.init()
        await server.server.start()
        client = Client(server.endpoint)
        try:
            # Match the generated demo certificate URI to avoid certificate
            # validator warnings and exercise the same secure-channel contract
            # used by the runtime demo script.
            client.application_uri = "urn:antigravity:automation:mhmc:opcua-server"
            await client.set_security(
                SecurityPolicyBasic256Sha256,
                certificate=cert_path,
                private_key=key_path,
                mode=ua.MessageSecurityMode.SignAndEncrypt,
            )
            await client.connect()
            node = client.get_node(f"ns={server.namespace_index};s=ControlState.CurrentState")
            value = await node.read_value()
            if value != 9:
                return False, f"unexpected ControlState.CurrentState={value}"
            return True, "secure Basic256Sha256 SignAndEncrypt client read succeeded"
        finally:
            try:
                await client.disconnect()
            finally:
                await server.server.stop()


def run_sync_checks() -> list[CheckResult]:
    specs: list[tuple[str, str, Callable[[], tuple[bool, str]]]] = [
        ("VisualTwin", "visual demo README exists", file_exists("digital_twin/visual_demo/README.md")),
        ("VisualTwin", "visual demo HTML exists", file_exists("digital_twin/visual_demo/index.html")),
        ("VisualTwin", "visual demo CSS exists", file_exists("digital_twin/visual_demo/style.css")),
        ("VisualTwin", "visual demo JS exists", file_exists("digital_twin/visual_demo/app.js")),
        (
            "VisualTwin",
            "visual demo exposes expected scenarios",
            text_contains(
                "digital_twin/visual_demo/app.js",
                "jam_pe3",
                "bad_scan",
                "slow_throughput",
            ),
        ),
        ("VisualTwin", "visual demo renders event timeline panel", text_contains("digital_twin/visual_demo/index.html", "Event Timeline")),
        ("DemoRuntime", "start script exists", file_exists("tools/start-software-demo.ps1")),
        ("DemoRuntime", "stop script exists", file_exists("tools/stop-software-demo.ps1")),
        ("DemoRuntime", "start script uses strict PowerShell pattern", powershell_has_cmdlet_binding("tools/start-software-demo.ps1")),
        ("DemoRuntime", "stop script uses strict PowerShell pattern", powershell_has_cmdlet_binding("tools/stop-software-demo.ps1")),
        (
            "DemoRuntime",
            "start script defaults to secure OPC UA",
            text_contains(
                "tools/start-software-demo.ps1",
                "Basic256Sha256",
                "SignAndEncrypt",
                "opcua_server.generate_cert",
            ),
        ),
        ("EvidencePack", "evidence generator exists", file_exists("tools/new-portfolio-evidence-pack.ps1")),
        ("EvidencePack", "evidence README exists", file_exists("portfolio_evidence/README.md")),
        (
            "EvidencePack",
            "evidence generator defines screenshot capture slots",
            text_contains(
                "tools/new-portfolio-evidence-pack.ps1",
                "01-twincat-rebuild-success.png",
                "04-visual-digital-twin.png",
                "05-grafana-kpi-dashboard.png",
            ),
        ),
        ("Docs", "portfolio demo narrative exists", file_exists("docs/portfolio_demo_narrative.md")),
        (
            "Docs",
            "demo narrative has both walkthrough scripts",
            text_contains(
                "docs/portfolio_demo_narrative.md",
                "90-second executive demo",
                "6-minute engineering walkthrough",
                "Only hardware remains",
            ),
        ),
        (
            "Docs",
            "README documents software demo workflow",
            text_contains(
                "README.md",
                "Software Demo Stack",
                "Visual digital twin",
                "Portfolio evidence pack",
            ),
        ),
    ]

    results: list[CheckResult] = []
    for suite, check_name, func in specs:
        try:
            passed, detail = func()
        except Exception as exc:  # pragma: no cover - defensive reporting.
            passed, detail = False, str(exc)
        results.append(CheckResult(suite, check_name, passed, detail))
    return results


def write_reports(results: list[CheckResult]) -> None:
    RESULTS.mkdir(parents=True, exist_ok=True)
    passed = sum(1 for result in results if result.passed)
    failed = len(results) - passed
    generated = datetime.now().astimezone().isoformat(timespec="seconds")

    payload = {
        "generated": generated,
        "passed": passed,
        "failed": failed,
        "total": len(results),
        "results": [result.__dict__ for result in results],
    }
    (RESULTS / "software-polish-summary.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")

    lines = [
        "# MHMC Software Polish Validation Report",
        "",
        f"- Generated: {generated}",
        f"- Passed: {passed}",
        f"- Failed: {failed}",
        f"- Total checks: {len(results)}",
        "",
        "## Results",
        "",
        "| Suite | Check | Result | Detail |",
        "| --- | --- | --- | --- |",
    ]
    for result in results:
        verdict = "PASS" if result.passed else "FAIL"
        detail = result.detail.replace("|", "\\|")
        lines.append(f"| {result.suite} | {result.check} | {verdict} | {detail} |")

    if failed == 0:
        lines.extend(
            [
                "",
                "## Conclusion",
                "",
                "The software-side polish layer is present and validated. Remaining work is hardware-only commissioning and production release evidence.",
            ]
        )
    (RESULTS / "software-polish-report.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


async def amain() -> int:
    results = run_sync_checks()
    passed, detail = await secure_opcua_smoke()
    results.append(CheckResult("SecureOpcUa", "secure client reads semantic node", passed, detail))
    write_reports(results)
    return 0 if all(result.passed for result in results) else 1


def main() -> None:
    raise SystemExit(asyncio.run(amain()))


if __name__ == "__main__":
    main()
