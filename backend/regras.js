const jsonServer = require('json-server');
const { randomBytes } = require('node:crypto');

const sessoes = new Map();

function distanciaEmMetros(latitude, longitude, local) {
  const radianos = Math.PI / 180;
  const a = Math.sin((local.latitude - latitude) * radianos / 2) ** 2
    + Math.cos(latitude * radianos) * Math.cos(local.latitude * radianos)
    * Math.sin((local.longitude - longitude) * radianos / 2) ** 2;
  return 6371000 * 2 * Math.asin(Math.sqrt(Math.min(1, a)));
}

// O JSON Server cuida das rotas e da gravação; aqui ficam só as regras do exercício.
module.exports = [jsonServer.bodyParser, (req, res, next) => {
  const banco = req.app.db.getState();

  if (req.method === 'POST' && req.path === '/login') {
    const { identificador, senha } = req.body ?? {};
    if (typeof identificador !== 'string' || typeof senha !== 'string') {
      return res.status(400).json({ erro: 'Informe NIF/e-mail e senha.' });
    }
    const usuario = banco.usuario;
    if ((identificador.trim() !== usuario.nif
        && identificador.trim().toLowerCase() !== usuario.email.toLowerCase())
        || senha !== 'senha123') {
      return res.status(401).json({ erro: 'NIF/e-mail ou senha incorretos.' });
    }
    const token = randomBytes(32).toString('hex');
    sessoes.set(token, Date.now() + 7 * 24 * 60 * 60 * 1000);
    return res.json({ token, usuario });
  }

  // O token permite reabrir o app com biometria sem guardar a senha no celular.
  const token = req.get('Authorization')?.replace(/^Bearer /, '');
  if (!sessoes.has(token) || sessoes.get(token) <= Date.now()) {
    sessoes.delete(token);
    return res.status(401).json({ erro: 'Sessão encerrada. Entre novamente com sua senha.' });
  }
  if (req.method === 'POST' && req.path === '/logout') {
    sessoes.delete(token);
    return res.json({ mensagem: 'Sessão encerrada.' });
  }
  if (req.method === 'GET' && ['/usuario', '/local-trabalho', '/pontos'].includes(req.path)) {
    if (req.path === '/pontos') {
      req.query.usuarioId = banco.usuario.id;
      req.query._sort = 'dataHora';
      req.query._order = 'desc';
    }
    return next();
  }
  if (req.method !== 'POST' || req.path !== '/pontos') {
    return res.status(404).json({ erro: 'Rota não encontrada.' });
  }

  const { tipo, latitude, longitude } = req.body ?? {};
  if (!['Entrada', 'Saída'].includes(tipo)
      || !Number.isFinite(latitude) || latitude < -90 || latitude > 90
      || !Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
    return res.status(400).json({ erro: 'Informe o tipo de ponto e coordenadas válidas.' });
  }
  const local = banco['local-trabalho'];
  const distancia = distanciaEmMetros(latitude, longitude, local);
  if (!Number.isFinite(distancia)) {
    return res.status(500).json({ erro: 'Confira as coordenadas do trabalho no db.json.' });
  }
  if (distancia > 100) {
    return res.status(403).json({ erro: 'Registro bloqueado: fora do limite de 100 metros.' });
  }

  // Ignora usuário, data e distância enviados pelo cliente. O JSON Server gera o id.
  req.body = {
    usuarioId: banco.usuario.id,
    tipo,
    latitude,
    longitude,
    dataHora: new Date().toISOString(),
    localTrabalho: local.nome,
    distancia,
  };
  next();
}, (erro, req, res, next) => {
  const status = erro.type === 'entity.parse.failed' || erro.type === 'entity.too.large' ? 400 : 500;
  res.status(status).json({ erro: status === 400 ? 'Envie um JSON válido.' : 'Não foi possível ler o db.json.' });
}];
