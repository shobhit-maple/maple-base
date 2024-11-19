import psycopg2
import bcrypt
import uuid  # Import for generating UUIDs
import os

# Database connection configurations
DB_CONFIGS = {
  "organization_db": {
    "dbname": "maple-organization",
    "user": "postgres",
    "password": "postgres",
    "host": "localhost",
    "port": 5402
  },
  "useraccount_db": {
    "dbname": "maple-user-account",
    "user": "postgres",
    "password": "postgres",
    "host": "localhost",
    "port": 5404
  },
  "userlogin_db": {
    "dbname": "maple-user-auth",
    "user": "postgres",
    "password": "postgres",
    "host": "localhost",
    "port": 5401
  }
}

def generate_uuid():
  """Generate a random UUID."""
  return str(uuid.uuid4())

def connect_to_db(config):
  """Create a database connection."""
  return psycopg2.connect(**config)

def insert_organization(conn):
  """Insert into the organization database and return the generated ID."""
  org_id = generate_uuid()
  with conn.cursor() as cursor:
    cursor.execute("""
            INSERT INTO organization 
            VALUES (%s, %s, %s, %s, %s, %s) 
            RETURNING id;
        """, (org_id, "Maple", "Innovating dev tools", "0700282013", "nitw.shobhit@gmail.com", "Långrevsgatan 41, 133 43 Saltsjöbaden"))
  conn.commit()
  return org_id

def insert_user_account(conn, org_id):
  """Insert into the user account database and return the generated ID."""
  user_account_id = generate_uuid()
  with conn.cursor() as cursor:
    cursor.execute("""
            INSERT INTO user_account
            VALUES (%s, %s, %s, %s, %s)   
            RETURNING id;
        """, (user_account_id, org_id, "Shobhit", "Tyagi", "10-11-1987"))
  conn.commit()
  return user_account_id

def insert_user_login(conn, org_id, user_account_id, password):
  """Insert into the user login database."""
  user_login_id = generate_uuid()
  hashed_password = bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")
  with conn.cursor() as cursor:
    cursor.execute("""
            INSERT INTO user_login
            VALUES (%s, %s, %s, %s, %s);
        """, (user_login_id, org_id, user_account_id, "nitw.shobhit@gmail.com", hashed_password))
  conn.commit()

if __name__ == "__main__":
  try:
    # Connect to the organization DB
    org_conn = connect_to_db(DB_CONFIGS["organization_db"])
    print("Connected to Organization DB")
    org_id = insert_organization(org_conn)
    print(f"Inserted Organization with ID: {org_id}")

    # Connect to the user account DB
    useraccount_conn = connect_to_db(DB_CONFIGS["useraccount_db"])
    print("Connected to User Account DB")
    user_account_id = insert_user_account(useraccount_conn, org_id)
    print(f"Inserted User Account with ID: {user_account_id}")

    # Connect to the user login DB
    userlogin_conn = connect_to_db(DB_CONFIGS["userlogin_db"])
    print("Connected to User Login DB")
    password = input("Enter password for the superuser: ")
    insert_user_login(userlogin_conn, org_id, user_account_id, password)
    print("Inserted User Login")

  except Exception as e:
    print(f"Error: {e}")
  finally:
    # Close all connections
    org_conn.close()
    useraccount_conn.close()
    userlogin_conn.close()
    print("Connections closed")
