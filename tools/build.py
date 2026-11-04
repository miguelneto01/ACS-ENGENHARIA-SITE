"""Monta o index.html publicado a partir do arquivo-fonte do site.

O arquivo-fonte começa com <title>, metas, links de fonte e o <style>;
aqui eles vão para o <head> e o restante vai para o <body>.

Uso: python3 tools/build.py CAMINHO/DO/FONTE.html
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

HEAD_META = '''<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="description" content="ACS Engenharia e Serviços: empresa habilitada para licitações e obras públicas, com 17 prefeituras atendidas, além de construção, reformas, energia solar e projetos no Ceará.">
<meta name="theme-color" content="#0B2540">
<link rel="icon" href="favicon.svg" type="image/svg+xml">
<meta property="og:type" content="website">
<meta property="og:locale" content="pt_BR">
<meta property="og:title" content="ACS Engenharia e Serviços">
<meta property="og:description" content="Obras públicas e privadas em 17 prefeituras do Ceará. A solução para sua obra.">
<meta property="og:image" content="media/og-acs.jpg">
<script type="application/ld+json">{"@context":"https://schema.org","@type":"GeneralContractor","name":"ACS Engenharia e Serviços LTDA","slogan":"A solução para sua obra","telephone":"+55 85 9708-5814","areaServed":"Ceará, Brasil","sameAs":["https://www.instagram.com/acsengenharia.br/"]}</script>'''


def build(src_path):
    src = Path(src_path).read_text(encoding="utf-8")
    end_style = src.index("</style>") + len("</style>")
    head_part, body_part = src[:end_style], src[end_style:].lstrip("\n")
    # meta exclusiva do visualizador do Claude: não vai para o site publicado
    head_part = re.sub(r'<meta name="claude:viewport-fit-sides"[^>]*>\n?', "", head_part)
    html = (
        '<!doctype html>\n<html lang="pt-BR">\n<head>\n'
        + HEAD_META + "\n" + head_part.strip() + "\n</head>\n<body>\n"
        + body_part.rstrip() + "\n</body>\n</html>\n"
    )
    (ROOT / "index.html").write_text(html, encoding="utf-8")
    print("index.html gerado:", len(html), "bytes")


if __name__ == "__main__":
    build(sys.argv[1])
