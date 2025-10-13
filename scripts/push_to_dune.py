"""
Push queries from local repository to Dune Analytics.
Uploads SQL queries from the queries/ directory to Dune.
"""

from dune_client.client import DuneClient
import os
import yaml
from dotenv import load_dotenv
from pathlib import Path
import re

# Load environment variables
env_path = Path(__file__).parent.parent / "configs" / ".env"
load_dotenv(env_path)
API_KEY = os.getenv("DUNE_API_KEY")

# Load queries configuration
config_path = Path(__file__).parent.parent / "configs" / "queries.yml"
with open(config_path, 'r') as f:
    config = yaml.safe_load(f)

# Initialize Dune client
dune = DuneClient(api_key=API_KEY)

# Queries directory
queries_dir = Path(__file__).parent.parent / "queries"

def extract_query_id_from_filename(filename):
    """Extract query ID from filename format: {id}_{name}.sql"""
    match = re.match(r'^(\d+)_.*\.sql$', filename)
    if match:
        return int(match.group(1))
    return None

def remove_header_comments(sql):
    """Remove header comments added by pull script."""
    lines = sql.split('\n')
    cleaned_lines = []
    skip_header = True

    for line in lines:
        # Skip header comments
        if skip_header and (line.startswith('--') or line.strip() == ''):
            if 'already part of a query repo' in line:
                continue
            continue
        else:
            skip_header = False
            cleaned_lines.append(line)

    return '\n'.join(cleaned_lines).strip()

def push_query(query_id, filepath):
    """Push a single query to Dune."""
    try:
        print(f"Pushing query {query_id} from {filepath.name}...")

        # Read SQL file
        with open(filepath, 'r', encoding='utf-8') as f:
            sql_content = f.read()

        # Remove header comments
        sql_content = remove_header_comments(sql_content)

        # Update query on Dune
        dune.update_query(query_id, query_sql=sql_content)

        print(f"✓ Successfully updated query {query_id}")
        print(f"  View at: https://dune.com/queries/{query_id}")

    except Exception as e:
        print(f"✗ Error pushing query {query_id}: {str(e)}")

def main():
    """Push all queries from queries/ directory to Dune."""
    query_ids = config.get('queries', [])

    if not query_ids:
        print("No queries found in configs/queries.yml")
        return

    # Get all SQL files in queries directory
    sql_files = list(queries_dir.glob("*.sql"))

    if not sql_files:
        print("No SQL files found in queries/ directory")
        return

    print(f"Found {len(sql_files)} SQL files\n")

    # Push each query
    pushed_count = 0
    for filepath in sql_files:
        query_id = extract_query_id_from_filename(filepath.name)

        if query_id is None:
            print(f"⚠ Skipping {filepath.name} - invalid filename format")
            continue

        if query_id not in query_ids:
            print(f"⚠ Skipping query {query_id} - not in queries.yml")
            continue

        push_query(query_id, filepath)
        pushed_count += 1
        print()

    print(f"Done! Pushed {pushed_count} queries to Dune.")

if __name__ == "__main__":
    main()
