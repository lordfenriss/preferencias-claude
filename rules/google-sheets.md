---
paths:
  - "**/*.gs"
  - "**/appsscript.json"
  - "**/.clasp.json"
---

# Google Sheets, Apps Script e Workspace

Versão 1.0 · 19/11/2026 (saiu da seção S do CLAUDE.md global)

- S1. Complementa L1. Para fórmula, recurso ou código de Google Sheets, Apps Script ou API do Workspace, fontes nesta ordem: Developer Knowledge MCP do Google (developers.google.com: Apps Script, Sheets API); Central de Ajuda dos Editores de Documentos (support.google.com/docs) para funções e recursos da planilha, como tabelas e referências estruturadas; sem MCP, busca na web restrita a essas fontes oficiais.
- S2. Planilhas com localidade Brasil: fórmula gravada por script com vírgula pode não ser interpretada; grave com a localidade temporariamente em en_US ou use a sintaxe local.
- S3. Nomes em LET/LAMBDA não podem parecer endereço de célula (m1, dia1, ab12).
- S4. Sempre que eu pedir trabalho com planilhas Google (fórmula, recurso, estrutura, script ligado), leia antes de propor o guia de atualização sobre o Google Planilhas, que corrige o que o treinamento tende a errar (tabelas, chips, notificações condicionais, funções ausentes, limites). Local: repositório `afastamentos-quorum`, arquivo `docs/guia-google-sheets-atualizacao.md` (os temas ficam em `docs/guia-google-sheets/`). Se o arquivo não existir no ambiente, diga isso e aplique S1.
