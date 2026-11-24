# Preferências gerais do Claude Code

`CLAUDE.md` deste repositório é a fonte única das minhas preferências globais.

- **Local:** cópia em `~/.claude/CLAUDE.md` (Windows: `C:\Users\<usuário>\.claude\CLAUDE.md`).
- **Nuvem:** o script de configuração do ambiente baixa este arquivo (`raw.githubusercontent.com`) ao montar a VM; o cache é refeito a cada ~7 dias.
- **Publicar mudanças:** editar o arquivo local e rodar `./publicar.sh`. Ele roda antes o `sincronizar.ps1`, que traz e mescla o que mudou aqui (no GitHub ou por outra máquina); só então copia, faz commit e push.
- **Receber mudanças (todas as máquinas Windows):** a tarefa agendada "Claude - sincronizar preferencias" roda `sincronizar.ps1` todo dia às 09:00 (ou na próxima vez que o computador estiver ligado). Ela:
  1. faz `git pull` deste clone;
  2. atualiza `~/.claude/CLAUDE.md` quando só o repositório mudou; mescla em três vias quando os dois mudaram; não toca em nada quando há conflito (deixa a proposta em `%LOCALAPPDATA%\preferencias-claude\CLAUDE.md.conflito`);
  3. confere o curl: em rede que inspeciona HTTPS com certificado sem endereço de revogação (rede do MPF), liga `ssl-revoke-best-effort` em `~/.curlrc`;
  4. mantém as skills do repositório privado `lordfenriss/claude-mods` (pasta `skills/`): clona em `%LOCALAPPDATA%\preferencias-claude\claude-mods` e liga cada skill em `~/.claude/skills` por um vínculo (junction) para a pasta dela no clone. Atualiza só por `git fetch` + `merge --ff-only`, então edição local nunca é sobrescrita:
     - skill nova no repositório vira vínculo; skill que saiu do repositório perde o vínculo;
     - cópia solta em `~/.claude/skills` só é trocada por vínculo se for idêntica a uma versão já publicada no GitHub (a anterior vai para `%LOCALAPPDATA%\preferencias-claude\skills-anteriores\`); cópia com edição própria fica como está, o log pede decisão e o resto segue (saída 2);
     - atualização que tocaria arquivo editado no clone não altera nada (saída 2);
     - `%LOCALAPPDATA%\preferencias-claude\skills-fora.txt`, um nome por linha, lista o que a máquina não recebe. Nasce com `acesso-remoto-casa`, `ideia`, `migrar-codex` e `orquestrar` (dependem do PC de casa, do ai-memory e dos scripts codex-casa e agy-casa); tirar o nome da lista instala a skill;
     - clone e fetch têm limite de 180 s (`-LimiteRede`), para uma rede travada não consumir os 10 minutos da tarefa;
     - na máquina principal, onde existe o clone de trabalho `~/.claudecode/mods` (vínculos do `checar-skills.js`), esta etapa não faz nada.

  O `claude-mods` é privado: a máquina precisa do login do GitHub no Git (na primeira vez, o comando de "Ligar numa máquina nova" abre a janela de login; a tarefa diária não abre janela e registra o erro no log se faltar o login).

  Registro: `%LOCALAPPDATA%\preferencias-claude\sincronizar.log`. Cópia anterior do CLAUDE.md: `%LOCALAPPDATA%\preferencias-claude\CLAUDE.md.anterior`.

## Ligar numa máquina nova (uma vez, no PowerShell)

```powershell
git clone https://github.com/lordfenriss/preferencias-claude.git "$env:USERPROFILE\repos\preferencias-claude"; powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\repos\preferencias-claude\sincronizar.ps1" -Registrar
```

Numa máquina que já tem o clone: `git -C <pasta do clone> pull` e depois a segunda parte do comando acima, com a pasta do clone.

Repositório público de propósito: a rede "Confiável" da nuvem só alcança arquivos públicos. Não colocar aqui nada sensível nem contexto de trabalho de projetos.
