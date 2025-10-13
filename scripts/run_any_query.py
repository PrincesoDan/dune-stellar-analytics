"""
Run any query from the DeFindex dashboard and display results.
Usage: python scripts/run_any_query.py [query_id]
If no query_id is provided, shows a menu to select from available queries.
"""

from dune_client.client import DuneClient
import os
import sys
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

# Query descriptions
QUERY_NAMES = {
    5268612: "DeFindex Vaults",
    5782251: "DeFindex Vaults with More Info",
    5906479: "DeFindex Vaults TVL (Filled Days)",
    5926821: "DeFindex Latest Vaults Data",
    5926839: "DeFindex Latest USD TVL",
    5901637: "DeFindex TVL (Hours with Events)",
    5900680: "DeFindex Vaults Events",
    5576346: "DeFindex Aggregated Stats"
}

def show_menu():
    """Display menu of available queries."""
    query_ids = config.get('queries', [])

    print("\n╔════════════════════════════════════════════════════════════╗")
    print("║           DeFindex Dashboard - Query Runner            ║")
    print("╚════════════════════════════════════════════════════════════╝\n")
    print("Available Queries:\n")

    for idx, query_id in enumerate(query_ids, 1):
        query_name = QUERY_NAMES.get(query_id, f"Query {query_id}")
        print(f"  {idx}. [{query_id}] {query_name}")

    print("\n  0. Exit")
    print()

def run_query(query_id, limit=10):
    """Execute a query and display results."""
    query_name = QUERY_NAMES.get(query_id, f"Query {query_id}")

    print(f"\n{'='*60}")
    print(f"Running: {query_name} (ID: {query_id})")
    print(f"{'='*60}\n")

    try:
        result = dune.get_latest_result(query_id)

        if not result.result.rows:
            print("No results found.")
            return

        total_rows = len(result.result.rows)
        print(f"Total rows: {total_rows}")
        print(f"Showing first {min(limit, total_rows)} rows:\n")

        # Display results
        for idx, row in enumerate(result.result.rows[:limit], 1):
            print(f"Row {idx}:")
            for key, value in row.items():
                print(f"  {key}: {value}")
            print()

        if total_rows > limit:
            print(f"... and {total_rows - limit} more rows.")

        print(f"\nView full results: https://dune.com/queries/{query_id}\n")

    except Exception as e:
        print(f"Error running query: {str(e)}\n")

def main():
    """Main function."""
    query_ids = config.get('queries', [])

    # If query ID provided as argument
    if len(sys.argv) > 1:
        try:
            query_id = int(sys.argv[1])
            if query_id not in query_ids:
                print(f"Error: Query ID {query_id} not found in queries.yml")
                return

            limit = int(sys.argv[2]) if len(sys.argv) > 2 else 10
            run_query(query_id, limit)
            return
        except ValueError:
            print("Error: Invalid query ID. Must be a number.")
            return

    # Interactive menu
    while True:
        show_menu()

        try:
            choice = input("Select a query (0 to exit): ").strip()

            if choice == '0':
                print("\nGoodbye!\n")
                break

            choice_idx = int(choice) - 1

            if choice_idx < 0 or choice_idx >= len(query_ids):
                print("\n⚠ Invalid selection. Please try again.\n")
                continue

            query_id = query_ids[choice_idx]

            # Ask for limit
            limit_input = input(f"\nHow many rows to display? (default: 10): ").strip()
            limit = int(limit_input) if limit_input else 10

            run_query(query_id, limit)

            input("\nPress Enter to continue...")

        except ValueError:
            print("\n⚠ Invalid input. Please enter a number.\n")
            input("Press Enter to continue...")
        except KeyboardInterrupt:
            print("\n\nGoodbye!\n")
            break

if __name__ == "__main__":
    main()
