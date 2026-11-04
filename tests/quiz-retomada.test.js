const fs = require('fs');
const path = require('path');
const { JSDOM } = require('jsdom');

const root = path.resolve(__dirname, '..');
const read = (relativePath) => fs.readFileSync(path.join(root, relativePath), 'utf8');

// material: o da aula alvo (onde fica o aviso do quiz); anterior: o que o quiz cobra.
const salas = [
  { aula: '02', slug: 'qualidade-q2-a02', seed: 'quiz-seed-aula02-qualidade.sql', slide: 'slide_planejamento-casos-teste.html', material: 'material_planejamento-casos-teste.html', anterior: 'material_introducao-qualidade.html' },
  { aula: '03', slug: 'atam-q2-a03', seed: 'quiz-seed-aula03-atam.sql', slide: 'slide_caixa-branca-preta.html', material: 'material_caixa-branca-preta.html', anterior: 'material_planejamento-casos-teste.html' },
  { aula: '04', slug: 'caixa-q2-a04', seed: 'quiz-seed-aula04-caixas.sql', slide: 'slide_introducao-testes-automatizados.html', material: 'material_introducao-testes-automatizados.html', anterior: 'material_caixa-branca-preta.html' },
  { aula: '05', slug: 'atam-q2-a05', seed: 'quiz-seed-aula05-atam.sql', slide: 'slide_gestao-erros-bugs.html', material: 'material_gestao-erros-bugs.html', anterior: 'material_introducao-testes-automatizados.html' },
  { aula: '06', slug: 'bugs-q2-a06', seed: 'quiz-seed-aula06-bugs.sql', slide: 'slide_ci-github-actions.html', material: 'material_ci-github-actions.html', anterior: 'material_gestao-erros-bugs.html' },
  { aula: '07', slug: 'ci-q2-a07', seed: 'quiz-seed-aula07-ci.sql', slide: 'slide_junit-jacoco-sonarcloud.html', material: 'material_junit-jacoco-sonarcloud.html', anterior: 'material_ci-github-actions.html' },
  { aula: '08', slug: 'cobertura-q2-a08', seed: 'quiz-seed-aula08-cobertura.sql', slide: 'slide_wiremock-api-seguras.html', material: 'material_wiremock-api-seguras.html', anterior: 'material_junit-jacoco-sonarcloud.html' }
];

const alternativas = (sql) => [...sql.matchAll(/'(\[.*?\])'::jsonb/gs)]
  .map((match) => JSON.parse(match[1].replace(/''/g, "'")));
// Em cada linha do insert, segundos, tema e secao vêm logo depois das alternativas.
const questoes = (sql) => [...sql.matchAll(/'\[.*?\]'::jsonb\s*,\s*(\d+)\s*,\s*'((?:[^']|'')*)'\s*,\s*'((?:[^']|'')*)'\)/gs)]
  .map((match) => ({ segundos: Number(match[1]), tema: match[2], secao: match[3] }));
const gabarito = (sql) => [...sql.slice(sql.indexOf('insert into quiz_answer_key')).matchAll(/^\s*\((\d+), (\d), '/gm)]
  .map((match) => Number(match[2]));
const tituloDaSessao = (sql, slug) => sql.match(new RegExp(`\\('${slug}', '([^']+)', '2026-2'\\)`))[1];

describe('quizzes de retomada de Qualidade 2026.2', () => {
  const home = new JSDOM(read('pages/home_qualidade_2026_2.html')).window.document;
  const central = read('pages/qualidade2/quiz/index.html');

  test.each(salas)('Aula $aula possui aula, acessos, material e seed integrados', ({ aula, slug, seed, slide, material }) => {
    const prefixo = `pages/qualidade2/quiz/aula${aula}`;
    for (const sufixo of ['quiz', 'painel', 'relatorio']) {
      expect(fs.existsSync(path.join(root, `${prefixo}-${sufixo}.html`))).toBe(true);
      expect(central).toContain(`aula${aula}-${sufixo}.html`);
    }

    expect(home.querySelector(`a[href="qualidade2/quiz/aula${aula}-quiz.html"]`)).not.toBeNull();
    expect(read(`pages/qualidade2/${slide}`)).toContain(`href="quiz/aula${aula}-painel.html"`);
    expect(read(`pages/qualidade2/material/${material}`)).toContain(`href="../quiz/aula${aula}-quiz.html"`);
    expect(read(`supabase/${seed}`)).toContain(`'${slug}'`);
  });

  test.each(salas)('seed da Aula $aula mantém oito questões de 90 s, quatro alternativas, tema e seção', ({ seed }) => {
    const sql = read(`supabase/${seed}`);
    const listas = alternativas(sql);
    expect(listas).toHaveLength(8);
    expect(listas.every((lista) => lista.length === 4)).toBe(true);

    const qs = questoes(sql);
    expect(qs).toHaveLength(8);
    expect(qs.filter((q) => q.segundos !== 90 || !q.tema || !q.secao)).toEqual([]);
  });

  test.each(salas)('gabarito da Aula $aula tem oito respostas, duas em cada letra', ({ seed }) => {
    const g = gabarito(read(`supabase/${seed}`));
    expect(g).toHaveLength(8);
    expect([0, 1, 2, 3].map((letra) => g.filter((c) => c === letra).length)).toEqual([2, 2, 2, 2]);
  });

  // A seção vira o "o que retomar" do aluno e do relatório: tem de existir
  // no material da aula cobrada ("seção N" = <h2> "N. …").
  test.each(salas)('toda seção citada pela Aula $aula existe no material da aula anterior', ({ seed, anterior }) => {
    const html = read(`pages/qualidade2/material/${anterior}`);
    const titulos = [...new JSDOM(html).window.document.querySelectorAll('h2')]
      .map((h) => h.textContent.trim());
    const ausentes = questoes(read(`supabase/${seed}`)).map((q) => q.secao).filter((secao) => {
      const numero = secao.match(/^seção (\d+)$/);
      if (numero) return !titulos.some((t) => t.startsWith(`${numero[1]}. `));
      return !html.includes(secao.split(' · ')[0]);   // "Parte 1 · …" do material da Aula 03
    });
    expect(ausentes).toEqual([]);
  });

  test.each(salas)('o título fixo do painel e do relatório da Aula $aula é o da sessão', ({ aula, slug, seed }) => {
    const titulo = tituloDaSessao(read(`supabase/${seed}`), slug);
    const painel = new JSDOM(read(`pages/qualidade2/quiz/aula${aula}-painel.html`)).window.document;
    const relatorio = new JSDOM(read(`pages/qualidade2/quiz/aula${aula}-relatorio.html`)).window.document;
    expect(painel.getElementById('cab-titulo').textContent).toBe(titulo);
    expect(relatorio.getElementById('cab').textContent).toBe(titulo);
  });

  test.each(salas)('na Aula $aula a última pergunta vale o dobro no celular, no painel e no aviso do material', ({ aula, material }) => {
    const quiz = new JSDOM(read(`pages/qualidade2/quiz/aula${aula}-quiz.html`)).window.document;
    expect(quiz.getElementById('selo-dobro')).not.toBeNull();
    expect(quiz.querySelector('.regras').textContent).toMatch(/última pergunta vale o dobro/i);

    const painel = read(`pages/qualidade2/quiz/aula${aula}-painel.html`);
    expect(painel).toContain('id="p-dobro"');
    expect(painel).toContain('valeu o dobro');
    expect(read(`pages/qualidade2/material/${material}`)).toMatch(/última pergunta vale o dobro/i);
  });

  test('o ajuste do banco dá peso 2 a toda sala e repete a seção dos seeds', () => {
    const ajuste = read('supabase/quiz-ajuste-peso-secao.sql');
    const salasComPeso = ajuste.match(/session_slug in \(([^)]+)\)/)[1];
    for (const { slug } of salas) expect(salasComPeso).toContain(`'${slug}'`);

    const valores = [...ajuste.matchAll(/\('([a-z0-9-]+)', (\d+), '([^']+)'\)/g)];
    expect(valores.length).toBeGreaterThan(0);
    for (const [, slug, ordem, secao] of valores) {
      const { seed } = salas.find((s) => s.slug === slug);
      expect(`${slug} Q${ordem}: ${questoes(read(`supabase/${seed}`))[Number(ordem) - 1].secao}`)
        .toBe(`${slug} Q${ordem}: ${secao}`);
    }
  });
});

describe('peso por questão e strike por saída da aba (toda sala)', () => {
  const sql = read('supabase/quiz-peso-strike.sql');

  test('quiz_strike é RPC pública e só pune com a pergunta aberta', () => {
    expect(sql).toMatch(/create or replace function quiz_strike\(p_player uuid, p_motivo text/);
    expect(sql).toMatch(/grant execute on function quiz_strike\(uuid,text\)\s+to anon, authenticated;/);
    expect(sql).toMatch(/v_s\.estado <> 'pergunta' then\s+return jsonb_build_object\('ok', true, 'strike', false\)/);
  });

  test('quiz_strikes não é legível pela API', () => {
    expect(sql).toMatch(/alter table quiz_strikes enable row level security;/);
    expect(sql).toMatch(/revoke all on quiz_strikes from anon, authenticated;/);
  });

  test('a pontuação multiplica pelo peso e o strike zera a questão', () => {
    expect(sql).toMatch(/\(600 \+ 400 \* v_fracao\) \* v_q\.peso/);
    expect(sql).toMatch(/if v_correta and not v_strike then/);
    expect(sql).toMatch(/update quiz_answers set pontos = 0/);
  });

  test('o esquema destrutivo não redefine as RPCs do jogo', () => {
    const schema = read('supabase/quiz-schema.sql');
    for (const fn of ['quiz_responder', 'quiz_estado', 'quiz_host']) {
      expect(schema).not.toMatch(new RegExp(`create or replace function ${fn}\\(`));
    }
  });

  // As duas regras valem em toda sala: peso dobrado na última e strike por sair da aba.
  test.each(salas)('o seed da Aula $aula dá peso 2 à última questão', ({ seed }) => {
    expect(read(`supabase/${seed}`)).toMatch(/set peso = 2[\s\S]{0,160}max\(ordem\)/);
  });

  test.each(salas)('a página do aluno da Aula $aula registra o strike e avisa as regras', ({ aula }) => {
    const html = read(`pages/qualidade2/quiz/aula${aula}-quiz.html`);
    const doc = new JSDOM(html).window.document;
    expect(html).toContain("'quiz_strike'");
    expect(html).toMatch(/addEventListener\('visibilitychange'[\s\S]{0,80}saiu\('aba'\)/);
    expect(doc.querySelector('#strike-pergunta')).not.toBeNull();
    expect(doc.querySelectorAll('.regras')).toHaveLength(2);
    expect(doc.querySelector('.regras').textContent).toMatch(/vale o dobro/i);
  });

  test.each(salas)('o painel e o relatório da Aula $aula mostram peso e strikes', ({ aula }) => {
    const painel = read(`pages/qualidade2/quiz/aula${aula}-painel.html`);
    expect(painel).toContain('id="m-strikes"');
    expect(painel).toContain('id="p-dobro"');
    expect(read(`pages/qualidade2/quiz/aula${aula}-relatorio.html`)).toContain('<th>Strikes</th>');
  });

  // Quem respondeu cedo e quem lê o resultado continuam com a pergunta à vista.
  test.each(salas)('a Aula $aula repete o enunciado na espera e na revelação', ({ aula }) => {
    const html = read(`pages/qualidade2/quiz/aula${aula}-quiz.html`);
    const doc = new JSDOM(html).window.document;
    for (const id of ['eco-respondido', 'eco-revelacao']) {
      const eco = doc.querySelector(`#${id}`);
      expect(eco).not.toBeNull();
      expect(eco.querySelector('.rot')).not.toBeNull();
      expect(eco.querySelector('.txt')).not.toBeNull();
      expect(html).toContain(`ecoDaPergunta('${id}'`);
    }
    expect(html).toMatch(/alvo\.querySelector\('\.txt'\)\.textContent = p\.enunciado;/);

    const painel = read(`pages/qualidade2/quiz/aula${aula}-painel.html`);
    expect(new JSDOM(painel).window.document.querySelector('#rev-enunciado')).not.toBeNull();
    expect(painel).toContain("el('rev-enunciado').textContent = d.pergunta.enunciado;");
  });
});
