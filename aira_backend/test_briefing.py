"""Test script to generate live morning and night briefings into Supabase."""

import asyncio
import sys
import os

# Fix Windows console UTF-8 encoding
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from dotenv import load_dotenv
load_dotenv()

from app.jobs.daily_brief import generate_daily_brief
from app.jobs.night_brief import generate_night_brief

async def main():
    print("[1/2] Generating Morning Briefing test...")
    try:
        await generate_daily_brief()
        print("SUCCESS: Morning brief generated and saved to Supabase!")
    except Exception as e:
        print(f"FAILED: Morning brief error: {e}")

    print("\n[2/2] Generating Night Briefing test...")
    try:
        await generate_night_brief()
        print("SUCCESS: Night brief generated and saved to Supabase!")
    except Exception as e:
        print(f"FAILED: Night brief error: {e}")

if __name__ == "__main__":
    asyncio.run(main())
