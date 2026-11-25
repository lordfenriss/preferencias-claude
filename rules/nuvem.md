# Sessão na nuvem e acesso local (regras T)

Versão 1.0 · 24/11/2026 (saiu da seção T do CLAUDE.md global; a ponte fica lá)

- T1. Numa sessão na nuvem, quando o resultado sair melhor com acesso local (conta ou Drive institucional, plugin ou CLI só da conta pessoal, arquivo ou site que só o computador alcança), não contorne, não entregue versão menos eficiente nem dê resposta negativa sem antes avisar. Pare antes de qualquer outra ação e mostre, em elemento interativo (E1): o que a nuvem não alcança, o que o computador faria e o que muda no resultado. Opções: "Ir ao computador" (recomendada quando a diferença for relevante, com o handoff `/teleport` ou `claude --teleport <id>` pronto, G4); "Continuar na nuvem, aceitando o resultado menor"; "Não é possível localmente" (com o motivo técnico).
- T2. Recursos do ambiente que eu esqueço que existem. Quando surgir a oportunidade, sugira em caixa de opções (E1), com o ganho concreto e o caminho de tela, depois de conferir a documentação (L1):
  - **Variáveis de ambiente** (ambiente de nuvem): configuração não secreta que toda sessão na nuvem precisa, como fuso (`TZ=America/Sao_Paulo`), tempo limite de comando ou ID de pasta. Quem usa o ambiente lê os valores; segredo nunca vai aqui.
  - **"Permita que as sessões chamem APIs sem ver os segredos"** (segredos de rede): chave de API ou token que uma sessão na nuvem precisa para chamar um serviço; o proxy da Anthropic anexa a chave fora da máquina da sessão. Não serve para o GitHub (já tem proxy próprio) nem para o script de configuração.
  - **Adicionar conexão SSH**: trabalho que precisa rodar numa máquina que a nuvem não alcança e que aceita SSH; a conexão guarda host, pastas e variáveis.
  - **Script de configuração**: ferramenta que falta nas sessões na nuvem, ou gravar `~/.claude/CLAUDE.md` nelas (L5).
  - Gatilhos: chave ou token colado no chat ou num `.env`; sessão na nuvem que falhou por domínio bloqueado, ferramenta ausente ou falta de credencial; tarefa que pede outra máquina; o mesmo ajuste repetido no início de várias sessões.
