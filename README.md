# Registro de ponto com GPS e biometria

Aplicativo Flutter com três telas: login, registro de ponto e histórico.
O [enunciado completo](enunciado.md) foi preservado; o Firebase foi substituído
por uma API local com **JSON Server**, conforme solicitado.

## Estrutura

```text
lib/
  main.dart                 # Abre o aplicativo.
  api_service.dart          # GET e POST com o pacote http.
  biometria.dart            # Biometria do aparelho e token salvo com segurança.
  views/
    login_page.dart         # Login com senha ou biometria.
    ponto_page.dart         # GPS e registro de entrada/saída.
    historico_page.dart     # Lista dos pontos.
backend/
  package.json              # Comando para iniciar o JSON Server.
  json-server.json           # Porta, host e middleware carregados automaticamente.
  db.json                   # Funcionário, local de trabalho e pontos.
  regras.js                 # Middleware de login e validação dos 100 metros.
```

Referências de `mobile/`: `ApiWebService/biblioteca_api_json` para JSON Server
e requisições HTTP; `RecursosHardware/gps_exercicio` para GPS e permissões.
As telas usam `StatefulWidget`, `setState` e `Navigator`, sem providers ou models.

## Iniciar a API

Na pasta deste projeto, abra um terminal:

```powershell
cd backend
npm install
npx json-server --watch db.json
```

O `npx` usa o JSON Server instalado no projeto. O arquivo `json-server.json`
carrega automaticamente a porta 3000, o host e as regras de login e localização.
Também é possível usar `npm start`, que executa o mesmo comando. Execute apenas
uma instância da API por vez.

Deixe esse terminal aberto. Para confirmar que a API está ligada, abra
`http://localhost:3000` no navegador. Se a porta estiver ocupada por outra
instância, encerre-a com `Ctrl+C` no terminal dela e tente novamente.

Usamos JSON Server **0.17.4**, a mesma versão declarada no projeto de referência.
Ele cria as rotas a partir de `db.json` e grava os pontos nesse arquivo. O pequeno
middleware `regras.js` confere a senha, o token e a distância antes de deixar a
requisição chegar às rotas do JSON Server. Não há servidor Express próprio.

## Executar o aplicativo

Em outro terminal, na raiz do projeto:

```powershell
flutter pub get
flutter run
```

O emulador Android usa `http://10.0.2.2:3000`. Para celular físico, conecte ambos
à mesma rede, veja o IPv4 do computador com `ipconfig` e execute:

```powershell
flutter run --dart-define=API_URL=http://SEU_IP:3000
```

Se aparecer erro de conexão ou demora, confira se a API está ligada, se o IP
está correto e se o firewall permite a porta 3000. O Android permite HTTP local.

## Usar

1. Entre com **NIF `1001`** e **senha `senha123`**. Não há cadastro.
   Também é possível usar o e-mail do funcionário informado em `db.json`.
2. Para habilitar biometria, marque a opção no login e confirme o rosto ou a
   digital do aparelho. Depois de fechar e reabrir o app, use **Entrar com biometria**.
3. Ative o GPS e permita localização precisa. Escolha **Entrada** ou **Saída**
   e toque em **Registrar ponto**.
4. Consulte **Ver histórico** para ver data, hora, coordenadas e distância.

Configure o nome, latitude e longitude reais da escola ou trabalho na chave
`local-trabalho` de `backend/db.json` antes de abrir o app. O exemplo aponta
para o SENAI Americana, na Avenida Brasil, 2801. O limite é de 100 metros, validado no app e na API; cada registro
consulta uma posição nova e recebe a data/hora do computador que executa a API.

O token dura sete dias e fica na memória da API. Reiniciar a API exige novo login
com senha. **Sair** revoga o token e remove o acesso biométrico salvo. Pontos
continuam no JSON. A senha padrão fica no middleware e não é salva no celular.

## Rotas

| Método | Rota | Função |
| --- | --- | --- |
| POST | `/login` | Recebe `identificador` e `senha`; retorna usuário e token. |
| GET | `/usuario` | Retorna o funcionário. |
| GET | `/local-trabalho` | Retorna as coordenadas do trabalho. |
| GET | `/pontos` | Lista os pontos do funcionário, dos mais novos aos mais antigos. |
| POST | `/pontos` | Recebe `tipo`, `latitude` e `longitude`; o JSON Server gera o id. |
| POST | `/logout` | Encerra a sessão. |

Depois do login, as rotas exigem `Authorization: Bearer TOKEN`. O middleware
define funcionário, data/hora e distância; bloqueia outras rotas e alterações
diretas no funcionário. A API verifica as coordenadas recebidas, mas não comprova
que vieram de um GPS real. A senha padrão e o HTTP local são próprios do exercício.

O arquivo antigo `backend/banco.json`, se existir, permanece como cópia da versão
anterior; a API agora utiliza apenas `db.json`.

## Verificar

```powershell
flutter analyze
flutter test
cd backend
npm test
```

Os testes usam um JSON Server real com banco temporário para conferir login,
distância, persistência, histórico e logout. Os testes Flutter verificam o login,
a navegação e o bloqueio da biometria recusada ou indisponível. GPS e biometria
precisam ser conferidos também no aparelho.
