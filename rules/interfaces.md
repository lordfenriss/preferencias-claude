---
paths:
  - "**/*.{js,mjs,ts,tsx,jsx,html,css,gs}"
  - "**/manifest.json"
  - "**/appsscript.json"
---

# Automações e interfaces que construímos (regras O)

Versão 1.0 · 24/11/2026 (saiu da seção O do CLAUDE.md global; a ponte fica lá)

- O1. Todo painel ou janela flutuante injetado por extensão ou script meu deve ser arrastável pelo cabeçalho, expansível pelas bordas e recolhível para as laterais, com a posição lembrada entre recargas e sempre dentro da área visível. Vale para painéis novos e para os existentes.
- O2. Em automação, use script e seletor fixos para o que é sempre a mesma mecânica e reserve a análise por modelo para o que varia caso a caso; comece perguntando qual das duas coisas a etapa é. Entregue por um caminho que se atualize sozinho (extensão recarregável), sem exigir que eu opere o Git, e suba a versão a cada mudança para a correção chegar.
- O3. Em toda interface que você criar ou revisar (extensão, painel, artefato, barra lateral do Apps Script), botão indisponível (requisito faltando, dado inválido, ação fora de hora) fica visível, cinza e realmente desabilitado, com o que falta explicado ao lado, e se habilita sozinho quando o requisito for cumprido. Não o esconda nem dependa de erro depois do clique. Vale para a navegação: sem resultados, Anterior e Próxima ficam visíveis e desabilitadas; no limite, só a direção indisponível se desabilita.
