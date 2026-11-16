"""Fetch citation stats from a Google Scholar profile and write them to a JSON file.

The file is only rewritten when the numbers changed, so "updated" is the date of the
last change and unchanged weeks produce no commit. A failed or blocked fetch leaves
the previous file in place.
"""
import datetime
import json
import os
import sys

from scholarly import scholarly

SCHOLAR_ID = "5IuyFpYAAAAJ"
OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/json/scholar.json"


def main():
    try:
        author = scholarly.fill(scholarly.search_author_id(SCHOLAR_ID), sections=["basics", "indices", "counts"])
    except Exception as e:
        sys.exit(f"Google Scholar did not answer ({type(e).__name__}); keeping the previous numbers.")
    citations = author.get("citedby")
    if not citations:
        sys.exit("No citation count in the Scholar response; keeping the previous numbers.")
    stats = {
        "citations": citations,
        "h_index": author.get("hindex"),
        "i10_index": author.get("i10index"),
        "cites_per_year": {str(y): n for y, n in sorted(author.get("cites_per_year", {}).items())},
        "profile": f"https://scholar.google.com/citations?user={SCHOLAR_ID}",
    }
    if os.path.exists(OUT):
        with open(OUT) as f:
            old = json.load(f)
        if {k: v for k, v in old.items() if k != "updated"} == stats:
            print("Stats unchanged:", json.dumps(stats))
            return
    stats["updated"] = datetime.date.today().isoformat()
    with open(OUT, "w") as f:
        json.dump(stats, f, indent=2)
        f.write("\n")
    print("Stats updated:", json.dumps(stats))


if __name__ == "__main__":
    main()
