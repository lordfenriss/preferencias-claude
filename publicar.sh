#!/bin/bash
# publicar.sh · v2.0 · 24/11/2026
# Antes de publicar, traz o que mudou no repositório (sincronizar.ps1, mesclagem em três vias),
# para não apagar mudança feita direto no GitHub ou em outra máquina. Depois copia o CLAUDE.md
# global local para cá, faz commit e push se houver mudança.
set -e
cd "$(dirname "$0")"
if ! powershell.exe -NoProfile -ExecutionPolicy Bypass -File sincronizar.ps1 -SoPreferencias; then
  echo "Nada publicado: a sincronização não concluiu (decisão pendente, erro ou outra execução em andamento). Ver %LOCALAPPDATA%\\preferencias-claude\\sincronizar.log."
  exit 1
fi
tr -d '\r' < "$HOME/.claude/CLAUDE.md" > CLAUDE.md
if git diff --quiet -- CLAUDE.md; then
  if [ -n "$(git log '@{u}..HEAD' --oneline 2>/dev/null)" ]; then
    git push -q; echo "Publicado: envio pendente concluído."
  else
    echo "Sem mudanças."
  fi
  exit 0
fi
VER=$(grep -m1 -o 'Versão [0-9.]*' CLAUDE.md || echo "sem versão")
git add CLAUDE.md
git commit -q -m "Atualiza preferências gerais ($VER)" -m "Sincroniza a cópia pública usada pelo script de configuração da nuvem."
git push -q
cp CLAUDE.md "$(cygpath -u "$LOCALAPPDATA")/preferencias-claude/base-CLAUDE.md"
echo "Publicado: $VER"
