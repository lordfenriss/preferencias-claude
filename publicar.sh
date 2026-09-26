#!/bin/bash
# Copia o CLAUDE.md global local para este repositório, faz commit e push se houver mudança.
set -e
cd "$(dirname "$0")"
tr -d '\r' < "$HOME/.claude/CLAUDE.md" > CLAUDE.md
if git diff --quiet -- CLAUDE.md; then echo "Sem mudanças."; exit 0; fi
VER=$(grep -m1 -o 'Versão [0-9.]*' CLAUDE.md || echo "sem versão")
git add CLAUDE.md
git commit -q -m "Atualiza preferências gerais ($VER)" -m "Sincroniza a cópia pública usada pelo script de configuração da nuvem."
git push -q
echo "Publicado: $VER"
