"""Download Brazilian political party logos from Wikipedia/Wikimedia Commons."""

import json
import os
import re
import time
import urllib.request
import urllib.parse
import urllib.error
from pathlib import Path

BASE_DIR = Path("D:/Projetos/Mackenzie/voting-advice-brazil/data/logos/partidos")
BASE_DIR.mkdir(parents=True, exist_ok=True)

HEADERS = {"User-Agent": "FarolPolitico/1.0 (academic project; contact: brunomo-cw)"}

# All 30 parties registered at TSE (March 2026)
# Format: (sigla_for_filename, wikipedia_page_title)
PARTIES = [
    ("MDB", "Movimento Democrático Brasileiro (1980)"),
    ("PT", "Partido dos Trabalhadores"),
    ("PP", "Progressistas"),
    ("PRD", "Partido Renovação Democrática"),
    ("PSDB", "Partido da Social Democracia Brasileira"),
    ("PDT", "Partido Democrático Trabalhista"),
    ("UNIAO", "União Brasil"),
    ("PL", "Partido Liberal (2006)"),
    ("PODE", "Podemos (Brasil)"),
    ("PSB", "Partido Socialista Brasileiro (1985)"),
    ("REPUBLICANOS", "Republicanos (partido político)"),
    ("PSD", "Partido Social Democrático (2011)"),
    ("CIDADANIA", "Cidadania (partido político)"),
    ("PCdoB", "Partido Comunista do Brasil"),
    ("SOLIDARIEDADE", "Solidariedade (partido político)"),
    ("PV", "Partido Verde (Brasil)"),
    ("PSOL", "Partido Socialismo e Liberdade"),
    ("AVANTE", "Avante"),
    ("MOBILIZA", "Mobilização Nacional"),
    ("AGIR", "Agir (Brasil)"),
    ("DC", "Democracia Cristã (Brasil)"),
    ("PRTB", "Partido Renovador Trabalhista Brasileiro"),
    ("NOVO", "Partido Novo"),
    ("REDE", "Rede Sustentabilidade"),
    ("DEMOCRATA", "Democrata (Brasil)"),
    ("PSTU", "Partido Socialista dos Trabalhadores Unificado"),
    ("UP", "Unidade Popular (Brasil)"),
    ("MISSAO", "Partido Missão"),
    ("PCB", "Partido Comunista Brasileiro"),
    ("PCO", "Partido da Causa Operária"),
]


def api_get(url: str) -> dict:
    """Fetch JSON from URL with proper headers."""
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode("utf-8"))


def get_logo_filename(page_title: str) -> str | None:
    """Get the logo image filename from a party's Wikipedia infobox."""
    encoded = urllib.parse.quote(page_title, safe="")
    url = (
        f"https://pt.wikipedia.org/w/api.php?action=parse&page={encoded}"
        f"&prop=wikitext&format=json&section=0"
    )
    try:
        data = api_get(url)
    except Exception as e:
        print(f"  ERROR fetching page: {e}")
        return None

    wikitext = data.get("parse", {}).get("wikitext", {}).get("*", "")

    # Look for logo patterns in infobox (priority order):
    patterns = [
        # |logo_partido = [[Imagem:X.svg|165px]]
        r'\|\s*logo_partido\s*=\s*\[\[(?:Imagem|Image|Ficheiro|File|Arquivo):([^\]|]+)',
        # |logo_partido = File:X.svg  or  |logo_partido = X.svg
        r'\|\s*logo_partido\s*=\s*(?:File:|Ficheiro:|Arquivo:)?([^\n|{}<>\[\]]+\.(?:png|svg|jpg|jpeg|gif))',
        # |logo = X  (simpler infoboxes)
        r'\|\s*logo\s*=\s*(?:File:|Ficheiro:|Arquivo:)?([^\n|{}<>\[\]]+\.(?:png|svg|jpg|jpeg|gif))',
        # |imagem = X
        r'\|\s*imagem\s*=\s*(?:File:|Ficheiro:|Arquivo:)?([^\n|{}<>\[\]]+\.(?:png|svg|jpg|jpeg|gif))',
        # [[Ficheiro:X]] or [[File:X]] (first image in article)
        r'\[\[(?:Ficheiro|File|Arquivo|Imagem|Image):([^\]|]+\.(?:png|svg|jpg|jpeg|gif))',
    ]
    for pattern in patterns:
        for m in re.finditer(pattern, wikitext, re.IGNORECASE):
            filename = m.group(1).strip()
            # Remove "File:" prefix if accidentally captured
            for prefix in ["File:", "Ficheiro:", "Arquivo:", "Imagem:", "Image:"]:
                if filename.startswith(prefix):
                    filename = filename[len(prefix):]
            # Skip non-logo images
            if any(skip in filename.lower() for skip in ["flag", "bandeira", "mapa", "map", "coat", "brasao"]):
                continue
            return filename

    return None


def get_image_url(filename: str, width: int = 500) -> str | None:
    """Get the actual image URL from Wikimedia Commons (or pt.wikipedia as fallback)."""
    # Ensure no double "File:" prefix
    if filename.startswith("File:"):
        filename = filename[5:]
    title = f"File:{filename}"
    encoded = urllib.parse.quote(title, safe="")
    params = f"action=query&titles={encoded}&prop=imageinfo&iiprop=url&iiurlwidth={width}&format=json"

    # Try en.wikipedia, then commons.wikimedia.org, then pt.wikipedia for local files
    for wiki in ["https://en.wikipedia.org", "https://commons.wikimedia.org", "https://pt.wikipedia.org"]:
        url = f"{wiki}/w/api.php?{params}"
        try:
            data = api_get(url)
        except Exception as e:
            continue

        pages = data.get("query", {}).get("pages", {})
        for page in pages.values():
            if "missing" in page:
                continue
            imageinfo = page.get("imageinfo", [])
            if imageinfo:
                # Prefer thumburl (resized PNG even for SVGs) over raw url
                return imageinfo[0].get("thumburl") or imageinfo[0].get("url")

    return None


def get_logo_via_images_api(page_title: str) -> str | None:
    """Fallback: use Wikipedia images API to find logo among page images."""
    encoded = urllib.parse.quote(page_title, safe="")
    url = (
        f"https://pt.wikipedia.org/w/api.php?action=query&titles={encoded}"
        f"&prop=images&format=json"
    )
    try:
        data = api_get(url)
    except Exception as e:
        print(f"  ERROR images API: {e}")
        return None

    pages = data.get("query", {}).get("pages", {})
    for page in pages.values():
        images = page.get("images", [])
        for img in images:
            title = img.get("title", "")
            tl = title.lower()
            # Look for images that are likely logos
            if any(k in tl for k in ["logo", "logomarca", "logotipo", "símbolo", "simbolo"]):
                # Skip non-logo
                if any(skip in tl for skip in ["flag", "bandeira", "mapa", "coat"]):
                    continue
                # Remove "Ficheiro:" or "File:" prefix
                fname = title.split(":", 1)[-1] if ":" in title else title
                return fname
    return None


def download_image(url: str, dest: Path) -> bool:
    """Download an image file."""
    try:
        req = urllib.request.Request(url, headers=HEADERS)
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = resp.read()
            dest.write_bytes(data)
            return True
    except Exception as e:
        print(f"  ERROR downloading: {e}")
        return False


def main():
    import sys
    skip_existing = "--skip-existing" in sys.argv
    success = 0
    failed = []

    for sigla, wiki_page in PARTIES:
        dest = BASE_DIR / f"{sigla}.png"
        if skip_existing and dest.exists():
            print(f"[{sigla}] Already exists, skipping")
            success += 1
            continue
        print(f"\n[{sigla}] Looking up: {wiki_page}")

        # Step 1: Get logo filename from Wikipedia infobox
        logo_file = get_logo_filename(wiki_page)
        if not logo_file:
            print(f"  No logo in infobox, trying images API...")
            logo_file = get_logo_via_images_api(wiki_page)
        if not logo_file:
            print(f"  No logo found anywhere")
            failed.append(sigla)
            time.sleep(0.5)
            continue

        print(f"  Found logo: {logo_file}")

        # Step 2: Get actual download URL (thumbnail as PNG)
        image_url = get_image_url(logo_file)
        if not image_url:
            print(f"  Could not resolve image URL")
            failed.append(sigla)
            time.sleep(0.5)
            continue

        print(f"  URL: {image_url[:100]}...")

        # Step 3: Download
        if download_image(image_url, dest):
            size_kb = dest.stat().st_size / 1024
            print(f"  Saved: {dest} ({size_kb:.1f} KB)")
            success += 1
        else:
            failed.append(sigla)

        time.sleep(1.5)  # Be nice to Wikipedia

    print(f"\n{'='*50}")
    print(f"Downloaded: {success}/{len(PARTIES)}")
    if failed:
        print(f"Failed: {', '.join(failed)}")


if __name__ == "__main__":
    main()
