from dune_client.client import DuneClient
import os
from dotenv import load_dotenv
from pathlib import Path

# Load .env from configs directory
env_path = Path(__file__).parent.parent / "configs" / ".env"
load_dotenv(env_path)
API_KEY = os.getenv("DUNE_API_KEY")
QUERY_ID = 5268612

dune = DuneClient(api_key=API_KEY)
result = dune.get_latest_result(QUERY_ID)

for row in result.result.rows:
    print(row)
