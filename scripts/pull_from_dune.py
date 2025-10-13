"""
Pull queries from Dune Analytics to local repository.
Downloads SQL queries specified in configs/queries.yml and saves them to the queries/ directory.
"""

from dune_client.client import DuneClient
import os
import yaml
from dotenv import load_dotenv
from pathlib import Path

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
queries_dir.mkdir(exist_ok=True)

def sanitize_filename(name):
    """Sanitize query name for use in filename."""
    return name.lower().replace(' ', '_').replace('-', '_')

def pull_query(query_id):
    """Pull a single query from Dune."""
    try:
        print(f"Pulling query {query_id}...")

        # Get query metadata
        query = dune.get_query(query_id)
        query_name = sanitize_filename(query.base.name)
        query_sql = query.sql

        # Create filename
        filename = f"{query_id}_{query_name}.sql"
        filepath = queries_dir / filename

        # Add comment indicating it's part of a query repo
        header = f"-- Query: {query.base.name}\n"
        header += f"-- Description: {query.meta.description if query.meta.description else 'N/A'}\n"
        header += f"-- Source: https://dune.com/queries/{query_id}\n"
        header += f"-- already part of a query repo\n\n"

        # Write to file
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(header + query_sql)

        print(f"✓ Saved to {filepath}")

    except Exception as e:
        print(f"✗ Error pulling query {query_id}: {str(e)}")

def main():
    """Pull all queries specified in queries.yml."""
    query_ids = config.get('queries', [])

    if not query_ids:
        print("No queries found in configs/queries.yml")
        return

    print(f"Pulling {len(query_ids)} queries from Dune...\n")

    for query_id in query_ids:
        pull_query(query_id)
        print()

    print("Done!")

if __name__ == "__main__":
    main()
