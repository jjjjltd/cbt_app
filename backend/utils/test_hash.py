from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

password = "secret"
stored_hash = "$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW"

print(f"Password: {password}")
print(f"Hash: {stored_hash}")
print(f"Hash length: {len(stored_hash)}")

try:
    result = pwd_context.verify(password, stored_hash)
    print(f"✓ Verification result: {result}")
except Exception as e:
    print(f"✗ Error: {e}")