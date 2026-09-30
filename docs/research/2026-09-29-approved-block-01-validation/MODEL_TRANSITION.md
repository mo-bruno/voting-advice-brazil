# Transição de modelo da rodada B01

Por solicitação do usuário, a continuação da rodada usa `gpt-5.6-sol` com raciocínio `xhigh`, inclusive no chat orquestrador e nos agentes pendentes.

Três revisões já estavam concluídas antes da mudança: Lula, Ronaldo Caiado e Escritor Augusto Cury. Seus arquivos permanecem imutáveis e identificam o modelo usado. Os agentes pendentes que estavam em execução foram interrompidos. Como o executor não permite alterar o modelo de um agente já criado, a continuação usa agentes Sol substitutos, cada um limitado ao mesmo plano e alimentado pelo diário integral, perfil temático e checkpoint persistidos pelo responsável original.

O campo `agent_id` de cada revisão continua apontando para a identidade documental original exigida pelo protocolo. O `method` da revisão e os campos `executor_*` do estado registram quando houve substituição de executor. Essa transição não muda perguntas, explicações, fontes, critérios de classificação ou a exclusão de Pablo Marçal.
