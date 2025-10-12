import sqlite3

conn = sqlite3.connect('training.db')
c = conn.cursor()

# Delete old admin
c.execute("DELETE FROM users WHERE email = 'admin@example.com'")

# Insert new admin with working hash
# Password is: secret
c.execute("""INSERT INTO users 
             (company_id, name, email, password_hash, is_admin, is_instructor, status) 
             VALUES (?, ?, ?, ?, ?, ?, ?)""",
          (1, 'System Administrator', 'admin@example.com',
           '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW',
           1, 0, 'ACTIVE'))

conn.commit()
print(f"✓ Admin user updated. Email: admin@example.com, Password: secret")

# Verify it exists
c.execute("SELECT name, email, is_admin FROM users WHERE email = ?", ('admin@example.com',))
user = c.fetchone()
if user:
    print(f"✓ Found user: {user[0]} ({user[1]}), Admin: {user[2]}")
else:
    print("✗ User not found!")

conn.close()
