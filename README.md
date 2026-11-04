# ACS Engenharia e Serviços · Site

Site institucional da **ACS Engenharia e Serviços LTDA**: obras públicas e licitações, construção, reformas, energia solar, projetos e acompanhamento técnico em 17 cidades do Ceará.

Site estático (HTML, CSS e JavaScript puros), sem servidor nem banco de dados.

## Estrutura

```
index.html        Site completo (páginas por âncora: #inicio, #servicos, #obras, #publicas, #atuacao, #sobre, #contato, #guia)
favicon.svg       Ícone do navegador
_headers          Cabeçalhos de segurança (Netlify / Cloudflare Pages)
media/            Vídeos do topo, fotos, logo e mapa do Ceará (ceara.json)
```

### Vídeo do topo
O site escolhe o arquivo conforme a tela:
- `hero-1080.webm` (computador, ~5 MB)
- `hero-720.mp4` (tablet)
- `hero-540.mp4` (celular, ~3,4 MB)
- `hero-poster.jpg` aparece enquanto o vídeo carrega e quando o celular está em economia de dados.

## Como atualizar o site

O arquivo de trabalho fica fora do repositório. Depois de editá-lo, gere o `index.html` publicado com:

```bash
python3 tools/build.py CAMINHO/DO/ARQUIVO-FONTE.html
```

O script coloca título, metas e estilos no `<head>` e o conteúdo no `<body>`.

Ao trocar o vídeo do topo, mantenha os nomes dos arquivos e altere o número de versão (`?v=`) nos endereços dentro do `index.html`, para os navegadores baixarem o vídeo novo.

## Como ver no computador

```bash
python3 -m http.server 8000
```

Depois abra http://localhost:8000

## Como publicar

**Netlify ou Cloudflare Pages (recomendado, grátis):** conecte este repositório. Não há etapa de build; a pasta publicada é a raiz (`/`). Cada `git push` na `main` atualiza o site no ar.

**Domínio:** registre em registro.br no CNPJ da ACS e aponte o DNS para a hospedagem. O HTTPS é ativado automaticamente.

## Onde editar

Os textos e dados ficam no próprio `index.html`. No bloco `<script>` no fim do arquivo estão as listas:
- `SERVICES`: serviços
- `WORKS`: fotos da galeria de obras
- `REG`: as 17 cidades e suas regiões
- `FAQ`: perguntas frequentes

Contato: WhatsApp (85) 9708-5814 · Instagram [@acsengenharia.br](https://www.instagram.com/acsengenharia.br/)

## Pendências antes de ir ao ar
- Trocar as imagens marcadas como "Imagem ilustrativa" por fotos de obras reais da ACS.
- Criar a página de Política de Privacidade (LGPD).
- Opcional: ligar o Netlify Forms para o formulário e o diagnóstico chegarem por e-mail.
