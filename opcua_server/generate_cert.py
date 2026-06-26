"""Generate a self-signed OPC UA application instance certificate."""

from __future__ import annotations

import argparse
import datetime as dt
import socket
from ipaddress import ip_address
from pathlib import Path

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import ExtendedKeyUsageOID, NameOID

from .model import APPLICATION_URI


def build_certificate(hostname: str, organization: str, valid_days: int) -> tuple[bytes, bytes]:
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    subject = issuer = x509.Name(
        [
            x509.NameAttribute(NameOID.ORGANIZATION_NAME, organization),
            x509.NameAttribute(NameOID.COMMON_NAME, f"MHMC OPC UA Server - {hostname}"),
        ]
    )

    alt_names: list[x509.GeneralName] = [x509.UniformResourceIdentifier(APPLICATION_URI)]
    for candidate in {hostname, "localhost", "127.0.0.1", socket.gethostname()}:
        if not candidate:
            continue
        try:
            alt_names.append(x509.IPAddress(ip_address(candidate)))
        except ValueError:
            alt_names.append(x509.DNSName(candidate))

    cert = (
        x509.CertificateBuilder()
        .subject_name(subject)
        .issuer_name(issuer)
        .public_key(key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(dt.datetime.now(dt.UTC) - dt.timedelta(minutes=5))
        .not_valid_after(dt.datetime.now(dt.UTC) + dt.timedelta(days=valid_days))
        .add_extension(x509.SubjectAlternativeName(alt_names), critical=False)
        .add_extension(x509.BasicConstraints(ca=False, path_length=None), critical=True)
        .add_extension(x509.KeyUsage(digital_signature=True, key_encipherment=True, content_commitment=True, data_encipherment=True, key_agreement=False, key_cert_sign=False, crl_sign=False, encipher_only=False, decipher_only=False), critical=True)
        .add_extension(x509.ExtendedKeyUsage([ExtendedKeyUsageOID.SERVER_AUTH, ExtendedKeyUsageOID.CLIENT_AUTH]), critical=False)
        .sign(key, hashes.SHA256())
    )

    cert_der = cert.public_bytes(serialization.Encoding.DER)
    key_pem = key.private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.TraditionalOpenSSL,
        serialization.NoEncryption(),
    )
    return cert_der, key_pem


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate MHMC OPC UA server certificate material")
    parser.add_argument("--out-dir", type=Path, default=Path("opcua_server/certs"))
    parser.add_argument("--hostname", default="localhost")
    parser.add_argument("--organization", default="Antigravity Automation")
    parser.add_argument("--valid-days", type=int, default=825)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    args.out_dir.mkdir(parents=True, exist_ok=True)
    cert_der, key_pem = build_certificate(args.hostname, args.organization, args.valid_days)
    cert_path = args.out_dir / "mhmc-server.der"
    key_path = args.out_dir / "mhmc-server-key.pem"
    cert_path.write_bytes(cert_der)
    key_path.write_bytes(key_pem)
    print(f"Wrote {cert_path}")
    print(f"Wrote {key_path}")


if __name__ == "__main__":
    main()
