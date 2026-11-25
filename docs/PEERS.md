# Peer view: one agent looks at another

Opt-in. Lets a fellow agent (or its owner, through it) see what this agent is doing, and add or drop its Telegram groups and super-users ([SETTINGS.md](SETTINGS.md)). Nothing else. It is SSH with a forced command, built with standard tools and no extra code beyond `bin/peer.sh`.

## What a peer can do

| Request | Returns |
|---|---|
| `screen` (default) | The last readable lines of this agent's Claude Code screen |
| `status` | Whether Claude is running and the last heartbeat |
| `transcript` | The last 40 messages of the latest conversation: what the owner wrote and what the agent answered (each cut at 600 characters). No tool results |
| `group ID`, `admin ID`, `drop ID` | Changes this agent's groups and super-users through its own `config.sh`; this agent's owner is told |
| anything else | Refused |

No shell, no terminal, no forwarding of any kind (`DisableForwarding`), no file transfer: the SSH server runs one fixed command per connection (`ForceCommand`), as the unprivileged `agent` user, on port 2222. The command does not receive this agent's environment, so it cannot return its tokens.

## Set-up for two agents, A looks at B

1. On any machine: `ssh-keygen -t ed25519 -N '' -f peer_key` creates `peer_key` (private) and `peer_key.pub` (public).
2. On **B** (the one being looked at), set `PEER_PUBLIC_KEYS` to the content of `peer_key.pub` (one key per line for several peers).
3. On **A** (the one looking), set `PEER_SSH_KEY` to the content of `peer_key`.
4. Redeploy both. On A: `peer.sh look B-HOST`, where `B-HOST` is B's private address. On Railway it is in B's variable `RAILWAY_PRIVATE_DOMAIN`, which is not always the service's name (a service `agent-kernel-ZG_U` got `agent-kernel-zgu.railway.internal`); ask B "what is your address for fellow agents?". Not its IP or hostname: both change at every deploy.

For both to see each other, set both variables on both.

## Two agents on one Linux server

Each agent's folder is its own Compose project, with its own network: two agents on one server cannot reach each other until they share one. A network joined by hand (`docker network connect`) is lost at the next `docker compose up -d`, which every update runs, and with it the name the other agent looks up. Declare it instead, in a `compose.override.yml` next to each agent's `compose.yml`. Compose reads that file by itself, and `git pull` never touches it (it is in `.gitignore`).

1. Once per server: `docker network create agents`.
2. In each agent's folder, a `compose.override.yml` with that agent's own name as its alias:

   ```yaml
   services:
     agent:
       networks:
         default: {}
         agents:
           aliases: [junior]
   networks:
     agents:
       external: true
   ```

3. `docker compose up -d` in each folder. The other agent's address is then its alias: `config.sh peer Junior=junior`, or "your fellow agent Junior is at junior".

No port is published: the agents reach each other on the server's own Docker network.

## Names instead of addresses

Set `PEERS` on the agent that looks, as `name=host` pairs separated by spaces, for example `Junior=agent2.railway.internal`. Then `peer.sh look junior` works (names are case-insensitive), and the agent can find a fellow agent when the owner names it.

## Read before enabling

- **The screen is the owner's conversation, and `transcript` returns more of it.** Whoever holds a listed key can read what B is discussing with its owner.
- `PEER_SSH_KEY` is a secret in A's environment. On hosts without a hard floor (Railway), A's own shell can read it. A leaked key lets its holder read the screens and conversations of the peers that list it, and add or drop their groups and super-users (each change is reported to that peer's owner).
- Do not publish port 2222 to the internet; use the host's private network.
- Without `PEER_PUBLIC_KEYS` no SSH server starts.

## Verified

- In CI, inside the image, with a real server and client: a listed key sees the screen; other commands, chained commands, shells, terminals and tunnels are refused; an unlisted key sees nothing.
- On Railway (2026-11-10): one agent read the other's screen and status over the private network (`agent2.railway.internal`).
- On a Linux server (2026-11-24): two agents in two Compose projects read each other's screen and status, both ways, over a shared Docker network joined by hand with an alias; a chained command, a shell and an unlisted command were refused. On 2026-11-25 the same network declared in `compose.override.yml` kept both agents and their aliases across a recreation of the containers (`up -d --force-recreate`), and the look worked both ways.
- Not verified yet on Railway: `transcript` against a real session file, and names from `PEERS`; an agent answering with `RAILWAY_PRIVATE_DOMAIN` when asked for its address.
