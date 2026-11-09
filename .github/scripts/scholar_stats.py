"""Fetch citation stats from a Google Scholar profile and write them to a JSON file.

The file is only overwritten when the fetch succeeds, so a blocked run leaves the
previous numbers in place.
"""
import datetime
import json
import sys

from scholarly import scholarly

SCHOLAR_ID = "5IuyFpYAAAAJ"
OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/json/scholar.json"


def main():
    author = scholarly.fill(scholarly.search_author_id(SCHOLAR_ID), sections=["basics", "indices", "counts"])
    citations = author.get("citedby")
    if not citations:
        sys.exit("No citation count in the Scholar response; keeping the previous file.")
    stats = {
        "citations": citations,
        "h_index": author.get("hindex"),
        "i10_index": author.get("i10index"),
        "cites_per_year": {str(y): n for y, n in sorted(author.get("cites_per_year", {}).items())},
        "profile": f"https://scholar.google.com/citations?user={SCHOLAR_ID}",
        "updated": datetime.date.today().isoformat(),
    }
    with open(OUT, "w") as f:
        json.dump(stats, f, indent=2)
        f.write("\n")
    print(json.dumps(stats))


if __name__ == "__main__":
    main()
