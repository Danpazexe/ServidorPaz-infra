# Servidor-PAZ

Servidor Paper 1.20.1 (AD LAND). As mudanças de jogabilidade estão em [MUDANCAS.md](MUDANCAS.md).

## Segurança

> **Aviso:** enquanto os passos abaixo não forem aplicados no servidor real, ele continua vulnerável. Hoje qualquer pessoa que alcance o túnel do bore pode entrar com o nome de um OP e ter controle total do servidor. Mudar este repositório não muda o servidor que já está rodando.

### Por que isso é preciso

O servidor roda com `online-mode=false`, para aceitar jogadores sem conta original. Nesse modo o servidor **não confere quem é o jogador**: a identidade é só o nome digitado, e o UUID é derivado desse nome. Os nomes dos jogadores e dos OPs já são públicos (estavam neste repo). Por isso a proteção é feita em três camadas:

1. **Whitelist** (`white-list=true` e `enforce-whitelist=true`): só os nomes da lista entram.
2. **AuthMe Reloaded**: cada nome da whitelist tem uma senha. Antes do `/login`, o jogador não anda, não fala, não usa comandos e não tem o status de OP (o AuthMe tira e devolve depois do login).
3. **OP com nível 2** (`op-permission-level=2`): mesmo que alguém passe pelas duas camadas, um OP nível 2 não consegue dar OP para outros, banir, mexer na whitelist nem parar o servidor. Essas ações ficam só no console. Se você precisar de nível 3 ou 4 no jogo, aumente sabendo desse risco.

A whitelist sozinha não basta, porque os nomes dela também são públicos. O que impede alguém de entrar com o seu nome é a senha do AuthMe.

### Passo a passo no servidor real

Faça na ordem, com o servidor **parado**.

**1. Backup antes de atualizar o repositório.** Este PR tira do git `ops.json`, `whitelist.json`, `usercache.json`, `banned-*.json`, `.console_history`, `logs/`, `world*/playerdata`, `world*/stats`, `world*/advancements` e o `bore`. Se o servidor roda a partir de um clone deste repo, o `git pull` **apaga esses arquivos do disco**, inclusive os inventários dos jogadores. Faça o backup e restaure depois:

```bash
cd /caminho/do/servidor
mkdir -p ../backup-antes-pull
cp -a ops.json whitelist.json usercache.json banned-players.json banned-ips.json \
      .console_history logs bore bore-*.tar.gz ../backup-antes-pull/ 2>/dev/null
for w in world world_nether world_the_end; do
  for d in playerdata stats advancements; do
    [ -d "$w/$d" ] && mkdir -p "../backup-antes-pull/$w" && cp -a "$w/$d" "../backup-antes-pull/$w/"
  done
done

git pull

cp -an ../backup-antes-pull/. .   # devolve o que o pull apagou, sem sobrescrever nada
```

Confira se `world/playerdata/` voltou antes de ligar o servidor.

**2. Conferir o AuthMe.** O jar `plugins/AuthMe-5.7.0.jar` vem da [release oficial 5.7.0](https://github.com/AuthMe/AuthMeReloaded/releases/tag/5.7.0). Ele precisa de **Java 17 ou mais novo**. Confira o checksum:

```bash
shasum -a 256 plugins/AuthMe-5.7.0.jar
# esperado: 67cc5c1923315cedc152616abce81cf79d004d44cb8fe9ab4d0b262728f23e08
```

Por que a 5.7.0 e não a 6.0.x: os jars da 6.0.x para Paper exigem Paper 1.21+, e o jar "Spigot 1.21" declara `api-version: 1.21.11`, que o Paper 1.20.1 recusa ao carregar. A 5.7.0 declara `api-version: 1.16` e roda em 1.18+. Se o servidor migrar para Paper 1.21+, troque pela versão 6.x correspondente.

A configuração está em `plugins/AuthMe/config.yml` (o AuthMe usa esse arquivo na primeira vez que liga). O que mudou em relação ao padrão:

| Opção | Valor | Motivo |
|---|---|---|
| `registration.force` | `true` | Ninguém joga sem fazer `/login`. |
| `registration.enabled` | `false` | Só o dono cria contas, pelo console. Com `/register` aberto, quem entrasse primeiro com o nome de alguém ainda sem conta tomaria a conta. |
| `restrictions.kickNonRegistered` | `true` | Nome sem conta é expulso. |
| `security.passwordHash` | `BCRYPT` (custo 12) | Hash lento e com salt. ARGON2 exigiria a biblioteca nativa `libargon2`. |
| `security.minPasswordLength` | `8` | Senhas curtas e óbvias também estão em `unsafePasswords`. |
| `allowChat`, `allowMovement` | `false` | Antes do login não fala, não anda e só usa `/login`. |
| `applyBlindEffect`, `teleportUnAuthedToSpawn` | `true` | Antes do login não vê nada e fica no spawn. A posição real volta depois. |
| `restrictions.timeout` | `60` | Expulsa quem não fizer login em 60 s. |
| `kickOnWrongPassword` | `true` | Senha errada expulsa. |
| `captcha.useCaptcha` / `maxLoginTry` | `true` / `3` | Depois de 3 senhas erradas para um nome, pede captcha. |
| `sessions.enabled` | `false` | Ver abaixo. |
| `tempban.enableTempban` | `false` | Ver abaixo. |
| `maxRegPerIp` | `0` | Ver abaixo. |

**Sessão, tempban e limite por IP ficam desligados por causa do túnel.** Pelo bore, todos os jogadores chegam ao servidor com o IP `127.0.0.1`. Por isso:

- Uma sessão "por IP" deixaria qualquer pessoa que entrasse com o nome de outro jogador, logo depois dele sair, pular o `/login`.
- Banir por IP após várias senhas erradas baniria todo mundo de uma vez.
- O limite de 1 registro por IP só deixaria uma conta no servidor.

Se um dia o servidor sair do túnel (por exemplo, usando Tailscale ou ZeroTier, em que cada jogador tem o próprio IP), dá para ligar `sessions.enabled: true` com `timeout: 5` e `tempban.enableTempban: true`.

**3. Ligar o servidor e conferir que o AuthMe carregou.** No console, `plugins` precisa mostrar `AuthMe` em verde. Se ele aparecer em vermelho ou não aparecer, **não abra o túnel**: sem o AuthMe, sobra só a whitelist.

**4. Criar as contas e a whitelist (no console):**

```
whitelist add <nome>
authme register <nome> <senha-temporaria>
```

Repita para cada jogador e passe a senha a ele por um canal privado. No primeiro acesso, o jogador faz `/login <senha-temporaria>` e depois `/changepassword <senha-temporaria> <senha-nova>`.

**5. Rebaixar os OPs existentes.** O `op-permission-level` só vale para quem receber OP daqui em diante. Quem já está no `ops.json` continua com o nível gravado lá (hoje, 4). No console:

```
deop <nome>
op <nome>
```

Faça isso só para quem realmente precisa de OP. Os outros ficam sem OP.

**6. Reiniciar** (`stop` no console e `./start_all.sh` de novo) e testar: entre com um nome que não está na whitelist (deve ser recusado) e com um nome da whitelist sem senha (deve ficar cego, parado e ser expulso em 60 s).

### Instalar o bore

O binário do bore não fica mais no git. Para instalar a mesma versão que estava no repo (v0.5.0, Linux x86_64) conferindo o checksum:

```bash
curl -fsSLO https://github.com/ekzhang/bore/releases/download/v0.5.0/bore-v0.5.0-x86_64-unknown-linux-musl.tar.gz
echo "f606f2a59706479d9cab36d16b9c241e204edb46540c92333521872dfcda025f  bore-v0.5.0-x86_64-unknown-linux-musl.tar.gz" | shasum -a 256 -c -
tar -xzf bore-v0.5.0-x86_64-unknown-linux-musl.tar.gz bore
chmod +x bore
```

O arquivo que estava versionado tinha exatamente esse SHA-256, o mesmo da release oficial. Já existe a v0.6.0, que pode ser usada trocando a versão e o hash conforme a [página de releases](https://github.com/ekzhang/bore/releases).

O `bore.pub` é um túnel público: qualquer pessoa que descubra a porta alcança o servidor. Uma VPN como Tailscale ou ZeroTier deixa o servidor visível só para quem você convidar.

### O que este repositório não versiona mais

`ops.json`, `whitelist.json`, `usercache.json`, `banned-*.json`, `.console_history`, `logs/`, `world*/playerdata`, `world*/stats`, `world*/advancements`, os dados do AuthMe (banco de senhas `authme.db` etc., só a `config.yml` é versionada) e o `bore`. Tudo isso continua existindo no disco do servidor e está no `.gitignore`.

Esses arquivos **ainda aparecem no histórico do git**, que é público. Para removê-los de lá é preciso reescrever o histórico (por exemplo, com `git filter-repo`) e fazer force push. Essa decisão é do dono do repositório.
