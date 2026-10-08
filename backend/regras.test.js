const { test, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const jsonServer = require('json-server');

// Sobe o JSON Server com um banco temporário, preservando os pontos do exercício.
const pasta = fs.mkdtempSync(path.join(os.tmpdir(), 'json-ponto-'));
const arquivo = path.join(pasta, 'db.json');
const exemplo = JSON.parse(fs.readFileSync(path.join(__dirname, 'db.json'), 'utf8'));
exemplo.pontos = [{ id: 'outro', usuarioId: 'outro-usuario', dataHora: '2026-01-01T00:00:00Z' }];
fs.writeFileSync(arquivo, JSON.stringify(exemplo));
const api = jsonServer.create();
const rotas = jsonServer.router(arquivo);
api.db = rotas.db;
api.use(require('./regras'));
api.use(rotas);
const servidor = api.listen(0, '127.0.0.1');
const pronto = new Promise((resolve) => servidor.on('listening', resolve));

after(async () => {
  await new Promise((resolve) => servidor.close(resolve));
  fs.unlinkSync(arquivo);
  fs.rmdirSync(pasta);
});

async function requisitar(rota, { metodo = 'GET', dados, token } = {}) {
  await pronto;
  const resposta = await fetch(`http://127.0.0.1:${servidor.address().port}${rota}`, {
    method: metodo,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    ...(dados ? { body: JSON.stringify(dados) } : {}),
  });
  return { status: resposta.status, dados: await resposta.json() };
}

test('JSON Server: login padrão, raio de 100 m, gravação, histórico e logout', async () => {
  assert.equal((await requisitar('/pontos')).status, 401);
  assert.equal((await requisitar('/login', {
    metodo: 'POST', dados: { identificador: '1001', senha: 'errada' },
  })).status, 401);
  const login = await requisitar('/login', {
    metodo: 'POST', dados: { identificador: '1001', senha: 'senha123' },
  });
  assert.equal(login.status, 200);
  const token = login.dados.token;
  const usuario = (await requisitar('/usuario', { token })).dados;
  assert.equal(usuario.nif, '1001');
  assert.equal((await requisitar('/login', {
    metodo: 'POST', dados: { identificador: usuario.email.toUpperCase(), senha: 'senha123' },
  })).status, 200);
  const local = (await requisitar('/local-trabalho', { token })).dados;

  function pontoA(metros) {
    return {
      tipo: 'Entrada',
      latitude: local.latitude + metros / 6371000 * 180 / Math.PI,
      longitude: local.longitude,
      usuarioId: 'outro-usuario',
      dataHora: '2000-01-01T00:00:00.000Z',
      distancia: 0,
    };
  }
  for (const metros of [0, 99.99]) {
    const ponto = await requisitar('/pontos', { metodo: 'POST', token, dados: pontoA(metros) });
    assert.equal(ponto.status, 201);
    assert.ok(ponto.dados.id);
    assert.equal(ponto.dados.usuarioId, usuario.id);
    assert.ok(Math.abs(ponto.dados.distancia - metros) < 0.001);
    assert.ok(Math.abs(Date.now() - Date.parse(ponto.dados.dataHora)) < 5000);
  }
  for (const metros of [100.01, 500]) {
    assert.equal((await requisitar('/pontos', { metodo: 'POST', token, dados: pontoA(metros) })).status, 403);
  }
  assert.equal((await requisitar('/pontos', {
    metodo: 'POST', token, dados: { tipo: 'Entrada', latitude: '0', longitude: 0 },
  })).status, 400);
  const historico = (await requisitar('/pontos?usuarioId=outro-usuario', { token })).dados;
  assert.equal(historico.length, 2);
  assert.ok(historico.every((ponto) => ponto.usuarioId === usuario.id));
  assert.ok(historico[0].dataHora >= historico[1].dataHora);
  assert.equal(JSON.parse(fs.readFileSync(arquivo, 'utf8')).pontos.length, 3);
  assert.equal((await requisitar('/db', { token })).status, 404);
  assert.equal((await requisitar('/usuario', { metodo: 'PATCH', token, dados: { nif: '9999' } })).status, 404);
  assert.equal((await requisitar('/logout', { metodo: 'POST', token })).status, 200);
  assert.equal((await requisitar('/usuario', { token })).status, 401);
});
