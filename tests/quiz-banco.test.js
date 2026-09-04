/**
 * Banco público de questões e relatórios.
 *
 * O que se protege aqui é a promessa da página: ela é pública (sem token) e
 * não mostra desempenho individual. Um `quiz_relatorio` ou um `quiz_gabarito`
 * colados nela por engano — ambos existem no mesmo projeto e devolvem nomes ou
 * o gabarito de sala não publicada — passariam despercebidos sem este teste,
 * porque nenhuma suíte exercita as páginas do quiz.
 */
const fs = require('fs');
const path = require('path');
const { JSDOM } = require('jsdom');

const ROOT = path.resolve(__dirname, '..');
const PAGINA = 'pages/qualidade2/quiz/banco.html';
const SQL = 'supabase/quiz-banco.sql';

const ler = (p) => fs.readFileSync(path.join(ROOT, p), 'utf-8');

describe('banco.html (leitura pública do quiz)', () => {
  let html;
  let doc;

  beforeAll(() => {
    html = ler(PAGINA);
    doc = new JSDOM(html).window.document;
  });

  test('está ligado por um botão na home da disciplina', () => {
    const home = new JSDOM(ler('pages/home_qualidade_2026_2.html')).window.document;
    const link = home.querySelector('a[href="qualidade2/quiz/banco.html"]');
    expect(link).not.toBeNull();
    expect(link.textContent).toMatch(/banco/i);
  });

  test('não chama nenhuma RPC que exija token do professor', () => {
    for (const rpc of ['quiz_relatorio', 'quiz_gabarito', 'quiz_host', 'quiz_publicar']) {
      expect(html).not.toContain(rpc);
    }
  });

  test('não pede nem guarda token', () => {
    expect(doc.querySelector('#token')).toBeNull();
    expect(html).not.toMatch(/localStorage/);
  });

  test('só lê pelas duas funções públicas do banco', () => {
    const chamadas = [...html.matchAll(/db\.rpc\(\s*'([a-z_]+)'/g)].map((m) => m[1]);
    expect(new Set(chamadas)).toEqual(new Set(['quiz_banco_salas', 'quiz_banco']));
  });

  test('avisa, na própria página, que não há resultado individual', () => {
    expect(doc.body.textContent).toMatch(/sem resultado individual/i);
  });
});

describe('quiz-banco.sql (as funções por trás do banco)', () => {
  let sql;

  beforeAll(() => {
    sql = ler(SQL);
  });

  test('define as três funções que a página e o painel usam', () => {
    expect(sql).toMatch(/create or replace function quiz_banco_salas\(\)/);
    expect(sql).toMatch(/create or replace function quiz_banco\(p_slug text\)/);
    expect(sql).toMatch(/create or replace function quiz_publicar\(p_slug text, p_token text/);
  });

  test('quiz_banco recusa sala não publicada', () => {
    expect(sql).toMatch(/v_s\.publicado_em is null[\s\S]{0,200}'ok', false/);
  });

  test('quiz_publicar exige o token do professor', () => {
    const corpo = sql.slice(sql.indexOf('function quiz_publicar'));
    expect(corpo).toMatch(/quiz_host_tokens[\s\S]{0,300}Token do professor inválido/);
  });

  test('nenhuma função do banco devolve nome de estudante', () => {
    // 'nome' pode aparecer para contar participantes e para o piso de
    // privacidade, nunca dentro de um jsonb_build_object devolvido.
    const publicadas = sql.match(/jsonb_build_object\([^)]*'nome'/g) || [];
    expect(publicadas).toEqual([]);
  });

  test('mantém o piso de privacidade por rodada', () => {
    expect(sql).toMatch(/function quiz_banco_piso\(\)[\s\S]{0,120}select 3/);
    expect(sql).toMatch(/count\(distinct nome\) >= quiz_banco_piso\(\)/);
  });

  test('ordena por taxa como número, não como texto', () => {
    expect(sql).not.toMatch(/order by [a-z_]+->>'taxa'/);
  });
});

describe('funções internas não podem ficar expostas à API', () => {
  // O Supabase concede EXECUTE a anon e authenticated por default privilege em
  // toda função nova do schema public, e esse grant sobrevive a um `revoke ...
  // from public`. Uma interna deixada assim vira RPC aberta: quiz_linhas
  // devolveria nome, escolha e gabarito de uma rodada em andamento.
  const INTERNAS = {
    'supabase/quiz-ingestao.sql': ['quiz_linhas(text)', 'quiz_arquivar(text)'],
    'supabase/quiz-banco.sql': ['quiz_banco_piso()'],
  };

  for (const [arquivo, funcoes] of Object.entries(INTERNAS)) {
    for (const fn of funcoes) {
      test(`${fn} é revogada de anon e authenticated`, () => {
        const escapada = fn.replace(/[()]/g, '\\$&');
        const linha = new RegExp(`revoke all on function ${escapada}\\s+from ([^;]+);`);
        const achado = ler(arquivo).match(linha);
        expect(achado).not.toBeNull();
        expect(achado[1]).toContain('anon');
        expect(achado[1]).toContain('authenticated');
      });
    }
  }
});
