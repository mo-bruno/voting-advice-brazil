#!/usr/bin/env python3
"""Maintain the durable status document without loading full review texts."""
import argparse,datetime,json
from pathlib import Path
P=Path(__file__).resolve().parent

def now():return datetime.datetime.now(datetime.timezone.utc).isoformat()
def read(p):return json.loads(p.read_text())
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--assign',nargs=2,metavar=('CANDIDATE_ID','AGENT_ID'));ap.add_argument('--status',nargs=2,metavar=('CANDIDATE_ID','STATUS'));args=ap.parse_args();s=read(P/'STATE.json');cs={c['id']:c for c in s['candidates']}
 if args.assign:
  cid,agent=args.assign;c=cs[cid]
  if c['agent_id'] and c['agent_id']!=agent:raise ValueError('One exclusive reviewer per plan: cannot replace agent silently')
  c.update(agent_id=agent,status='reading',started_at=now())
 if args.status:
  cid,status=args.status;cs[cid]['status']=status
 for c in s['candidates']:
  p=P/'reviews'/(c['id']+'.checkpoint.json')
  if p.exists():
   try:
    checkpoint=read(p);ns=checkpoint.get('pages_read',checkpoint.get('completed_pages',[]));c['pages_read']=len(set(ns)) if isinstance(ns,list) else ns
   except (ValueError,TypeError):pass
  p=P/'reviews'/(c['id']+'.json')
  if p.exists():
   try:
    r=read(p);c['pages_read']=len(set(r.get('pages_read',[])));c['review_file']='reviews/'+p.name;c['position_count']=len(r.get('positions',[]));c['divergent_count']=sum(x.get('comparison')=='divergent' for x in r.get('positions',[]))
    if c['status'] not in ['validated','needs_followup']:c['status']='submitted'
   except ValueError:pass
 s['updated_at']=now();(P/'STATE.json').write_text(json.dumps(s,ensure_ascii=False,indent=2)+'\n')
 submitted=sum(c['status'] in ['submitted','validated'] for c in s['candidates']);validated=sum(c['status']=='validated' for c in s['candidates']);read_pages=sum(c['pages_read'] for c in s['candidates']);labels={'queued':'Na fila','reading':'Leitura integral em andamento','submitted':'Entregue; em conferência','validated':'Conferido pelo orquestrador','needs_followup':'Retorno ao mesmo revisor'}
 lines=['# Documento central — validação integral por plano','',f"Atualizado: {s['updated_at']}. **{submitted}/{s['plan_count']} entregas; {validated} conferidas; {read_pages}/{s['total_pages']} páginas registradas como lidas.**",'', 'Este documento é o ponto de retomada desta conversa. Estado estruturado: [STATE.json](STATE.json). Fontes atuais: [source-manifest.json](source-manifest.json). Textos congelados: [questions.json](questions.json). Protocolo: [PROTOCOL.md](PROTOCOL.md).','',f"Escopo: **{s['question_count']} perguntas × {s['plan_count']} documentos oficiais**, um agente exclusivo por plano, modelo solicitado `gpt-6-astra`, esforço `ultra`, no máximo três revisores simultâneos. Leitura integral com diário por página; buscas lexicais apenas complementares.",'', 'O pacote atual contém os mesmos 13 PDFs da base anterior e um documento adicional de Pablo Marçal. O cadastro complementar atual informa indeferimento e substituição deste último; sua leitura fica como análise documental separada, sem inclusão no ranking nem alteração da lista do produto.','', '| Plano | Páginas | Responsável exclusivo | Estado | Páginas registradas | Entrega |','|---|---:|---|---|---:|---|']
 for c in s['candidates']:
  link=f"[Revisão]({c['review_file']})" if c.get('review_file') else '—'
  lines.append(f"| {c['name']} | {c['pages']} | {c['agent_id'] or 'A designar'} | {labels.get(c['status'],c['status'])} | {c['pages_read']} | {link} |")
 lines+=['','## Decisões persistentes','']
 for d in s['decisions']:lines.append(f"- **{d['id']}:** {d['decision']}")
 lines+=['','## Divergências e decisões editoriais','', 'Registro consolidado em [STATE.json](STATE.json); cada decisão deve apontar pergunta, categoria anterior, evidência e resolução. As entregas individuais são preservadas, mesmo quando o orquestrador adota outra conclusão.','']
 for d in s.get('divergences',[]):lines.append(f"- {d['candidate_id']} / {d['question_id']}: {d.get('resolution','Pendente de adjudicação')}.")
 lines+=['','## Retomada após compactação','', '1. Ler este documento e STATE.json. Não recomeçar a análise ou reenviar tarefas já concluídas.', '2. Consultar checkpoints somente dos revisores em execução e os resumos dos que terminaram.', '3. Não transformar leitura declarada em aprovação: conferir páginas, 16 registros, hashes e citações, e adjudicar divergências.', '4. Criar um novo agente apenas para plano sem responsável. Retornos e novas redações vão ao mesmo responsável, preservando um agente por plano.', '5. Se uma pergunta mudar substantivamente, remetê-la aos mesmos responsáveis pelos demais planos antes de tratá-la como validada.', '6. Não fazer deploy nem alterar perguntas, candidaturas ou respostas do aplicativo nesta etapa de validação.']
 (P/'ORCHESTRATION.md').write_text('\n'.join(lines)+'\n')
 print(json.dumps({'submitted':submitted,'validated':validated,'pages_logged':read_pages,'total_pages':s['total_pages'],'reading':[c['name'] for c in s['candidates'] if c['status']=='reading']},ensure_ascii=False))
if __name__=='__main__':main()
