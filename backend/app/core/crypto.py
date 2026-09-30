from __future__ import annotations

import base64
import hashlib
from dataclasses import dataclass

from cryptography.hazmat.primitives.ciphers.aead import AESGCM


def _key_from_secret(secret: str) -> bytes:
    # Derive a stable 32-byte key from APP_SECRET.
    return hashlib.sha256(secret.encode("utf-8")).digest()


@dataclass(frozen=True)
class Crypto:
    key: bytes

    @classmethod
    def from_secret(cls, secret: str) -> "Crypto":
        return cls(key=_key_from_secret(secret))

    def encrypt_to_b64(self, plaintext: bytes, aad: bytes = b"") -> str:
        aes = AESGCM(self.key)
        nonce = hashlib.sha256(plaintext).digest()[:12]
        ct = aes.encrypt(nonce, plaintext, aad or None)
        return base64.b64encode(nonce + ct).decode("utf-8")

    def decrypt_from_b64(self, b64: str, aad: bytes = b"") -> bytes:
        raw = base64.b64decode(b64.encode("utf-8"))
        nonce, ct = raw[:12], raw[12:]
        aes = AESGCM(self.key)
        return aes.decrypt(nonce, ct, aad or None)

