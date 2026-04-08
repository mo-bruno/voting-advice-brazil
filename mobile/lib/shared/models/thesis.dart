enum ThesisAnswer { agree, neutral, disagree, skipped, unanswered }

class Thesis {
  final int id;
  final String title;
  final String description;
  final String category;
  ThesisAnswer answer;
  bool doubleWeight;

  Thesis({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.answer = ThesisAnswer.unanswered,
    this.doubleWeight = false,
  });

  static List<Thesis> getSampleTheses() {
    return [
      Thesis(id: 1, title: 'A favor da privatização de estatais', description: 'O governo deve vender empresas estatais para a iniciativa privada.', category: 'Economia'),
      Thesis(id: 2, title: 'Limite de velocidade em rodovias', description: 'Deve ser introduzido um limite geral de velocidade de 110 km/h nas rodovias abertas, a fim de reduzir as emissões de CO2 e aumentar a segurança no trânsito.', category: 'Transporte'),
      Thesis(id: 3, title: 'Aumento do salário mínimo', description: 'O salário mínimo deve ser reajustado acima da inflação anualmente.', category: 'Economia'),
      Thesis(id: 4, title: 'Agricultura ecológica', description: 'Deve haver mais incentivos fiscais para a agricultura ecológica e sustentável.', category: 'Meio Ambiente'),
      Thesis(id: 5, title: 'Digitalização nas escolas', description: 'Todas as escolas públicas devem receber infraestrutura digital completa até 2028.', category: 'Educação'),
      Thesis(id: 6, title: 'Aposentadoria aos 67 anos', description: 'A idade mínima de aposentadoria deve ser elevada para 67 anos.', category: 'Previdência'),
      Thesis(id: 7, title: 'Fim do uso de carvão até 2030', description: 'O Brasil deve eliminar o uso de carvão para geração de energia até 2030.', category: 'Meio Ambiente'),
      Thesis(id: 8, title: 'Legalização da cannabis', description: 'O uso recreativo da cannabis deve ser legalizado e regulamentado.', category: 'Saúde'),
      Thesis(id: 9, title: 'Imposto sobre grandes fortunas', description: 'Deve ser implementado um imposto progressivo sobre grandes fortunas.', category: 'Economia'),
      Thesis(id: 10, title: 'Proibição de celulares', description: 'O uso de celulares deve ser proibido em escolas de ensino fundamental e médio.', category: 'Educação'),
      Thesis(id: 11, title: 'Reforma tributária', description: 'O sistema tributário brasileiro deve ser simplificado com a unificação de impostos.', category: 'Economia'),
      Thesis(id: 12, title: 'Energia nuclear', description: 'O Brasil deve investir na expansão de usinas nucleares para diversificar a matriz energética.', category: 'Energia'),
      Thesis(id: 13, title: 'Redução da maioridade penal', description: 'A maioridade penal deve ser reduzida de 18 para 16 anos.', category: 'Segurança'),
      Thesis(id: 14, title: 'Porte de armas', description: 'Cidadãos comuns devem ter direito ao porte de armas de fogo.', category: 'Segurança'),
      Thesis(id: 15, title: 'Renda básica universal', description: 'Todo cidadão brasileiro deve receber uma renda básica mensal do governo.', category: 'Social'),
      Thesis(id: 16, title: 'Privatização do SUS', description: 'Serviços do SUS devem ser parcialmente privatizados para melhorar a eficiência.', category: 'Saúde'),
      Thesis(id: 17, title: 'Voto facultativo', description: 'O voto obrigatório deve ser substituído pelo voto facultativo.', category: 'Política'),
      Thesis(id: 18, title: 'Fim do foro privilegiado', description: 'O foro privilegiado para políticos deve ser extinto.', category: 'Política'),
      Thesis(id: 19, title: 'Educação financeira obrigatória', description: 'Educação financeira deve ser disciplina obrigatória no ensino médio.', category: 'Educação'),
      Thesis(id: 20, title: 'Transporte público gratuito', description: 'O transporte público deve ser gratuito em todas as capitais.', category: 'Transporte'),
      Thesis(id: 21, title: 'Marco regulatório da IA', description: 'Deve ser criada uma legislação específica para regular a inteligência artificial.', category: 'Tecnologia'),
      Thesis(id: 22, title: 'Desmatamento zero', description: 'O desmatamento na Amazônia deve ser completamente proibido.', category: 'Meio Ambiente'),
      Thesis(id: 23, title: 'Prisão após segunda instância', description: 'A execução da pena deve iniciar após condenação em segunda instância.', category: 'Justiça'),
      Thesis(id: 24, title: 'Cotas raciais', description: 'As cotas raciais em universidades e concursos devem ser mantidas permanentemente.', category: 'Social'),
      Thesis(id: 25, title: 'Reforma agrária', description: 'O governo deve intensificar a reforma agrária e redistribuição de terras.', category: 'Agricultura'),
      Thesis(id: 26, title: 'Privatização dos Correios', description: 'Os Correios devem ser totalmente privatizados.', category: 'Economia'),
      Thesis(id: 27, title: 'Casamento igualitário', description: 'O casamento civil entre pessoas do mesmo sexo deve ser garantido por lei.', category: 'Direitos Civis'),
      Thesis(id: 28, title: 'Pena de morte', description: 'A pena de morte deve ser instaurada para crimes hediondos.', category: 'Segurança'),
      Thesis(id: 29, title: 'Ensino religioso', description: 'O ensino religioso deve ser removido das escolas públicas.', category: 'Educação'),
      Thesis(id: 30, title: 'Imposto sobre dividendos', description: 'Deve haver taxação sobre distribuição de lucros e dividendos.', category: 'Economia'),
      Thesis(id: 31, title: 'Serviço militar obrigatório', description: 'O serviço militar obrigatório deve ser extinto.', category: 'Defesa'),
      Thesis(id: 32, title: 'Autonomia do Banco Central', description: 'O Banco Central deve manter sua autonomia operacional.', category: 'Economia'),
      Thesis(id: 33, title: 'Teleconsulta no SUS', description: 'O SUS deve expandir o atendimento por teleconsulta em todo o país.', category: 'Saúde'),
      Thesis(id: 34, title: 'Limite de mandatos', description: 'Deve haver limite de reeleições para todos os cargos legislativos.', category: 'Política'),
      Thesis(id: 35, title: 'Energia solar obrigatória', description: 'Novos edifícios devem ser obrigados a instalar painéis solares.', category: 'Energia'),
      Thesis(id: 36, title: 'Financiamento público de campanha', description: 'Campanhas eleitorais devem ser financiadas exclusivamente com recursos públicos.', category: 'Política'),
      Thesis(id: 37, title: 'Descriminalização de drogas', description: 'O porte de drogas para consumo pessoal deve ser descriminalizado.', category: 'Saúde'),
      Thesis(id: 38, title: 'Redução de ministérios', description: 'O número de ministérios do governo federal deve ser reduzido.', category: 'Política'),
    ];
  }
}
