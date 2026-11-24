# Preferências gerais do Claude Code

`CLAUDE.md` deste repositório é a fonte única das minhas preferências globais.

- **Local:** cópia em `~/.claude/CLAUDE.md` (Windows: `C:\Users\<usuário>\.claude\CLAUDE.md`).
- **Nuvem:** o script de configuração do ambiente baixa este arquivo (`raw.githubusercontent.com`) ao montar a VM; o cache é refeito a cada ~7 dias.
- **Publicar mudanças:** editar o arquivo local e rodar `./publicar.sh`. Ele roda antes o `sincronizar.ps1`, que traz e mescla o que mudou aqui (no GitHub ou por outra máquina); só então copia, faz commit e push.
- **Receber mudanças (todas as máquinas Windows):** a tarefa agendada "Claude - sincronizar preferencias" roda `sincronizar.ps1` todo dia às 09:00 (ou na próxima vez que o computador estiver ligado). Ela:
  1. faz `git pull` deste clone;
  2. atualiza `~/.claude/CLAUDE.md` quando só o repositório mudou; mescla em três vias quando os dois mudaram; não toca em nada quando há conflito (deixa a proposta em `%LOCALAPPDATA%\preferencias-claude\CLAUDE.md.conflito`);
  3. confere o curl: em rede que inspeciona HTTPS com certificado sem endereço de revogação (rede do MPF), liga `ssl-revoke-best-effort` em `~/.curlrc`.

  Registro: `%LOCALAPPDATA%\preferencias-claude\sincronizar.log`. Cópia anterior do CLAUDE.md: `%LOCALAPPDATA%\preferencias-claude\CLAUDE.md.anterior`.

## Ligar numa máquina nova (uma vez, no PowerShell)

```powershell
git clone https://github.com/lordfenriss/preferencias-claude.git "$env:USERPROFILE\repos\preferencias-claude"; powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\repos\preferencias-claude\sincronizar.ps1" -Registrar
```

Numa máquina que já tem o clone: `git -C <pasta do clone> pull` e depois a segunda parte do comando acima, com a pasta do clone.

Repositório público de propósito: a rede "Confiável" da nuvem só alcança arquivos públicos. Não colocar aqui nada sensível nem contexto de trabalho de projetos.
