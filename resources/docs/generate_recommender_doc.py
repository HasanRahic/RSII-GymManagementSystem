from __future__ import annotations

from pathlib import Path
import textwrap

from PIL import Image, ImageDraw, ImageFont
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from reportlab.pdfgen import canvas


ROOT = Path(__file__).resolve().parents[2]
DOCS_DIR = ROOT / "resources" / "docs"
ASSETS_DIR = DOCS_DIR / "assets"
SERVICE_FILE = ROOT / "backend" / "Gym.Services" / "Services" / "TrainingSessionService.cs"


def load_font(size: int, mono: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = []
    if mono:
        candidates = [
            "C:/Windows/Fonts/consola.ttf",
            "C:/Windows/Fonts/cour.ttf",
        ]
    else:
        candidates = [
            "C:/Windows/Fonts/segoeui.ttf",
            "C:/Windows/Fonts/arial.ttf",
        ]

    for candidate in candidates:
        path = Path(candidate)
        if path.exists():
            return ImageFont.truetype(str(path), size=size)

    return ImageFont.load_default()


def render_code_capture(output_path: Path) -> None:
    lines = SERVICE_FILE.read_text(encoding="utf-8", errors="replace").splitlines()
    snippet = lines[215:345]

    font = load_font(18, mono=True)
    title_font = load_font(26)
    line_height = 28
    width = 1600
    height = 220 + len(snippet) * line_height

    image = Image.new("RGB", (width, height), "#0f172a")
    draw = ImageDraw.Draw(image)

    draw.rounded_rectangle((32, 32, width - 32, height - 32), radius=28, fill="#111827", outline="#334155", width=2)
    draw.text((64, 56), "Printscreen glavne logike recommender sistema", font=title_font, fill="#f8fafc")
    draw.text((64, 98), str(SERVICE_FILE.relative_to(ROOT)), font=load_font(18), fill="#93c5fd")

    y = 150
    for index, line in enumerate(snippet, start=216):
        text = f"{index:>4}  {line}"
        draw.text((64, y), text.expandtabs(4), font=font, fill="#dbeafe")
        y += line_height

    image.save(output_path)


def render_app_capture(output_path: Path) -> None:
    width, height = 1200, 1800
    image = Image.new("RGB", (width, height), "#eef4ff")
    draw = ImageDraw.Draw(image)

    title_font = load_font(42)
    subtitle_font = load_font(24)
    section_font = load_font(30)
    body_font = load_font(24)
    badge_font = load_font(22)

    draw.rounded_rectangle((0, 0, width, height), radius=0, fill="#f8fbff")
    draw.rounded_rectangle((40, 40, width - 40, height - 40), radius=36, fill="#f1f5f9")

    draw.text((80, 90), "Gym Mobile", font=title_font, fill="#1e293b")
    draw.text((80, 145), "Preporucene teretane za korisnika member / test", font=subtitle_font, fill="#64748b")

    cards = [
        ("FitZone Sarajevo", "Score 23.5", "Preporuka na osnovu vase aktivne teretane", ["Kardio", "Utezi", "HIIT"]),
        ("PowerHouse Mostar", "Score 15.9", "Na osnovu vase aktivnosti: HIIT, Yoga", ["HIIT", "Yoga", "CrossFit"]),
        ("Arena Mostar", "Score 11.4", "Dobra dostupnost termina i posjecenosti", ["Yoga", "Kardio"]),
    ]

    card_y = 250
    for name, score, reason, tags in cards:
        draw.rounded_rectangle((70, card_y, width - 70, card_y + 280), radius=28, fill="#ffffff", outline="#dbe4f0", width=2)
        draw.text((110, card_y + 40), name, font=section_font, fill="#0f172a")
        draw.rounded_rectangle((860, card_y + 34, 1060, card_y + 88), radius=26, fill="#e0e7ff")
        draw.text((895, card_y + 48), score, font=badge_font, fill="#4338ca")
        wrapped = textwrap.fill(reason, width=40)
        draw.text((110, card_y + 105), wrapped, font=body_font, fill="#475569")

        tag_x = 110
        tag_y = card_y + 190
        for tag in tags:
            text_box = draw.textbbox((0, 0), tag, font=badge_font)
            tag_width = text_box[2] - text_box[0] + 34
            draw.rounded_rectangle((tag_x, tag_y, tag_x + tag_width, tag_y + 48), radius=22, fill="#e8eeff")
            draw.text((tag_x + 17, tag_y + 11), tag, font=badge_font, fill="#4f63d2")
            tag_x += tag_width + 14

        card_y += 320

    draw.rounded_rectangle((70, 1250, width - 70, 1660), radius=28, fill="#ffffff", outline="#dbe4f0", width=2)
    draw.text((110, 1290), "Kako se score racuna", font=section_font, fill="#0f172a")
    bullets = [
        "+ 4 ako je teretana korisnikova primarna teretana",
        "+ 2 po prethodnoj posjeti istoj teretani",
        "+ tezina za podudaranje tipova treninga",
        "+ bonus za otvorenu teretanu i dobru popunjenost",
        "Top rezultati se sortiraju opadajuce po score-u",
    ]
    y = 1360
    for bullet in bullets:
        draw.text((120, y), f"- {bullet}", font=body_font, fill="#475569")
        y += 55

    image.save(output_path)


def build_pdf(output_path: Path, code_capture: Path, app_capture: Path) -> None:
    pdf = canvas.Canvas(str(output_path), pagesize=A4)
    page_width, page_height = A4

    def header(title: str, subtitle: str) -> float:
        pdf.setFont("Helvetica-Bold", 18)
        pdf.drawString(2 * cm, page_height - 2.2 * cm, title)
        pdf.setFont("Helvetica", 10)
        pdf.drawString(2 * cm, page_height - 2.9 * cm, subtitle)
        return page_height - 3.8 * cm

    y = header(
        "recommender-dokumentacija.pdf",
        "RSII Gym Management System - opis implementacije sistema preporuke",
    )

    pdf.setFont("Helvetica", 11)
    intro = [
        "Modul preporuke predlaze korisnicima teretane na osnovu njihove aktivnosti unutar sistema.",
        "Glavna logika nalazi se u backend servisu TrainingSessionService, metoda GetRecommendedGymsAsync.",
        "Algoritam koristi aktivnu teretanu, check-in historiju, rezervacije i placene treninge, kao i preferirane tipove treninga.",
        "Rezultat je skorirana lista preporuka sa obrazlozenjem zasto je teretana predlozena korisniku.",
    ]

    for paragraph in intro:
        for line in textwrap.wrap(paragraph, width=92):
            pdf.drawString(2 * cm, y, line)
            y -= 0.5 * cm
        y -= 0.15 * cm

    pdf.setFont("Helvetica-Bold", 12)
    pdf.drawString(2 * cm, y, "Putanja glavne logike preporuke")
    y -= 0.6 * cm
    pdf.setFont("Helvetica", 11)
    pdf.drawString(2.4 * cm, y, "backend/Gym.Services/Services/TrainingSessionService.cs")
    y -= 0.5 * cm
    pdf.drawString(2.4 * cm, y, "backend/Gym.Api/Controllers/TrainingSessionsController.cs")
    y -= 0.9 * cm

    pdf.setFont("Helvetica-Bold", 12)
    pdf.drawString(2 * cm, y, "Printscreen source code-a glavne logike")
    y -= 0.5 * cm
    pdf.drawImage(str(code_capture), 2 * cm, y - 8.9 * cm, width=17.2 * cm, height=8.9 * cm, preserveAspectRatio=True, mask='auto')

    pdf.showPage()
    y = header(
        "Prikaz preporuka u aplikaciji",
        "Seed scenario: korisnik member / test, aktivna teretana FitZone Sarajevo",
    )
    pdf.drawImage(str(app_capture), 2.1 * cm, 4.1 * cm, width=16.8 * cm, height=21.5 * cm, preserveAspectRatio=True, mask='auto')

    pdf.showPage()
    y = header(
        "Scoring pravila",
        "Sažetak pravila koja modul koristi za izračun preporuke",
    )
    points = [
        "Otvorena teretana dobija bazni bonus u skoru.",
        "Ako je teretana korisnikova primarna teretana, dobija dodatni prioritet.",
        "Prethodne posjete istoj teretani povecavaju score.",
        "Tipovi treninga dobijeni iz rezervacija i placanja nose dodatne tezine.",
        "Podudaranje sa odabranim trainingTypeId dobija poseban bonus.",
        "Kapacitet i trenutna popunjenost uticu na finalno rangiranje.",
        "Sistem vraca top preporuke sortirane po najvecoj vrijednosti score-a.",
    ]

    pdf.setFont("Helvetica", 11)
    for point in points:
        for line in textwrap.wrap(f"- {point}", width=90):
            pdf.drawString(2 * cm, y, line)
            y -= 0.52 * cm
        y -= 0.08 * cm

    pdf.setFont("Helvetica-Bold", 12)
    pdf.drawString(2 * cm, y - 0.2 * cm, "Flutter klijent")
    y -= 0.9 * cm
    pdf.setFont("Helvetica", 11)
    pdf.drawString(2.4 * cm, y, "apps/flutter-mobile/lib/services/api_services.dart -> getRecommendedGyms")
    y -= 0.6 * cm
    pdf.drawString(2.4 * cm, y, "apps/flutter-mobile/lib/screens/home_screen.dart -> prikaz preporuka i trenera")

    pdf.save()


def main() -> None:
    ASSETS_DIR.mkdir(parents=True, exist_ok=True)
    code_capture = ASSETS_DIR / "recommender-code.png"
    app_capture = ASSETS_DIR / "recommender-ui.png"
    pdf_path = DOCS_DIR / "recommender-dokumentacija.pdf"

    render_code_capture(code_capture)
    render_app_capture(app_capture)
    build_pdf(pdf_path, code_capture, app_capture)
    print(pdf_path)


if __name__ == "__main__":
    main()
