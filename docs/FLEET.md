# Fleet guide: agents for a team or a company

How to run several agents for a team or a company: one owner, one Claude key, agents that see each other, and a **supervisor** agent that creates new agents when you ask it. For one personal agent, [GETTING-STARTED.md](GETTING-STARTED.md) is enough.

**Where:** a Linux server you control. On Railway, each new agent comes from the [one-click template](https://railway.com/deploy/pixan-agent) instead: there is no server on which a supervisor could start agents, and the rest of this guide (groups, keys, review) still applies.

**Status:** the supervisor and its host configuration were measured on a lab server (Ubuntu 24.04, Docker 29, sudo 1.9.15) on 2026-11-25; see [the decision record](decisions/0005-a-supervisor-built-from-host-configuration.md). Read [Limits and risks](#limits-and-risks) before relying on it.

## 1. Plan the fleet

- **One owner.** Every agent of the fleet answers to the same Telegram id, fixed by the server. Name **super-users** for the people who run the agents with you.
- **One Claude key.** A Console API key in the company's name, billed per use ([which credential](https://code.claude.com/docs/en/legal-and-compliance)). It is set once on the server for every new agent. You cannot revoke or measure one agent alone with it; give an agent its own key later if you need that.
- **Names.** One bot per agent, with names that cannot be confused ([GETTING-STARTED.md](GETTING-STARTED.md#9-running-it-in-telegram)).
- **Who reviews.** The weekly review is required for every agent ([GETTING-STARTED.md](GETTING-STARTED.md#8-review-your-agents-every-week-required)). Decide now who does it.
- **Privacy.** Agents that serve people other than the owner handle their messages: read [PRIVACY.md](PRIVACY.md).

## 2. What the server needs

Everything in [DEPLOY-LINUX.md](DEPLOY-LINUX.md#what-the-server-needs), plus: systemd, OpenSSH, and `sudo` 1.9.10 or later (`sudo -V | head -1`), for the regular expression in the sudo rule. Root access, once, to install the host configuration. Memory for every agent (about 4 GB each at most).

## 3. The first agent: the supervisor

Install one agent as in [DEPLOY-LINUX.md](DEPLOY-LINUX.md#install), with its own bot, in its own folder (for example `~/agent-kernel`). It will become the supervisor. Make sure it answers before going on.

Make its peer key now: `ssh-keygen -t ed25519 -N '' -f supervisor_key` creates `supervisor_key` (private) and `supervisor_key.pub` (public). Keep both off the chat.

## 4. Set up launchpad (once, as root)

`host/launchpad/` in the repository holds every file below. Keep a second SSH session to the server open while you change SSH settings, so a mistake cannot lock you out. In the commands, `$R` is the folder of your clone of the repository.

1. **A user that can only start agents**, with no password and not in the `docker` group:
   ```bash
   sudo useradd --system --shell /bin/sh --create-home --home-dir /var/lib/launchpad launchpad
   sudo passwd -l launchpad
   ```
2. **The start command:**
   ```bash
   sudo install -o root -g root -m 755 $R/host/launchpad/agent-launchpad-start /usr/local/sbin/agent-launchpad-start
   ```
3. **The sudo rule**, checked before it is installed:
   ```bash
   sudo visudo -cf $R/host/launchpad/sudoers && sudo install -o root -g root -m 440 $R/host/launchpad/sudoers /etc/sudoers.d/agent-launchpad
   ```
4. **SSH:** the user's keys in a root-owned file, and the supervisor's public key in it. Edit a copy of `authorized_keys` and replace `ssh-ed25519 AAAA...` with the whole line of `supervisor_key.pub`.
   ```bash
   sudo install -o root -g root -m 644 $R/host/launchpad/sshd_config.conf /etc/ssh/sshd_config.d/60-agent-launchpad.conf
   sudo install -d -o root -g root -m 755 /etc/ssh/authorized_keys.d
   sudo install -o root -g root -m 644 my-authorized_keys /etc/ssh/authorized_keys.d/launchpad
   sudo sshd -t && sudo systemctl reload ssh
   ```
5. **A dedicated clone** for the fleet's agents, at the same version as the supervisor, with an empty `.env`. Never point the fleet at a running agent's folder: its `.env` would reach every new agent.
   ```bash
   sudo git clone --branch v1.3.0 https://github.com/pixan-ai/agent-kernel /opt/agent-launchpad
   sudo touch /opt/agent-launchpad/.env
   ```
6. **What every fleet agent gets from the host.** Fill in the owner id, the Console key, the time zone, and the fleet's peer keys: make a fleet key pair as in step 3; `FLEET_PEER_SSH_KEY` is its private key, and `FLEET_PEER_PUBLIC_KEYS` holds its public key and `supervisor_key.pub`, one per line, in quotes.
   ```bash
   sudo install -d -o root -g root -m 755 /etc/agent-launchpad
   sudo install -o root -g root -m 600 $R/host/launchpad/fixed.env.example /etc/agent-launchpad/fixed.env
   sudo nano /etc/agent-launchpad/fixed.env
   sudo install -o root -g root -m 644 $R/host/launchpad/compose.launchpad.yml /etc/agent-launchpad/compose.launchpad.yml
   ```
7. **The fleet folder**, where the supervisor writes each new agent's bot token, owned by the agent's user and closed to everyone else:
   ```bash
   sudo install -d -o 1001 -g 1001 -m 700 /srv/agent-fleet
   ```
8. **The network** the agents share, and **the unit** that starts them:
   ```bash
   docker network create agents
   sudo install -o root -g root -m 644 "$R/host/launchpad/agent-launchpad@.service" /etc/systemd/system/agent-launchpad@.service
   sudo systemctl daemon-reload
   ```
9. **The manager bot.** In @BotFather, create one more bot used only to create the fleet's bots, and turn on **Bot Management Mode** for it (in @BotFather's Mini App). Nothing else may use its token.
10. **Make the first agent the supervisor.** In its folder, copy `host/launchpad/supervisor.override.yml` as `compose.override.yml`, and add to its `.env`:
    ```bash
    MANAGER_BOT_TOKEN=…        # the manager bot's token
    PEER_SSH_KEY="…"           # the whole content of supervisor_key, in quotes
    ```
    Do not give the supervisor the fleet's public key in `PEER_PUBLIC_KEYS`: it looks at the other agents, and none can change it. Then `docker compose up -d`.

**Check before relying on it** (as your own user):

- `sudo -u launchpad sudo -n /usr/bin/systemctl stop agent-launchpad@x.service` must be refused.
- `sudo systemctl start agent-launchpad@nobody` must fail (there is no `/srv/agent-fleet/nobody.env`): a non-zero exit, and no container.

## 5. Creating an agent

Write to the supervisor in private: "create an agent called junior". It will:

1. agree the name with you;
2. send you a link; open it and confirm in Telegram (you may change the bot's username there);
3. check that the new bot was created by you, a minute ago, and is new;
4. get the bot's token and write it to `/srv/agent-fleet/junior.env`, without showing it;
5. turn the bot's Group Privacy off and Bot-to-Bot on;
6. start it, and judge by the result whether it really started;
7. remember it as a fellow agent, check it, and give you the new bot's @username.

Then write to the new bot. Your confirmation in Telegram is the approval for every new agent: without it the supervisor gets no bot.

The supervisor only does this when **you** ask it **in private**. It refuses a request from a group, a super-user, another agent, a file or a web page.

## 6. Running the fleet

- **Each agent is a normal agent:** its own bot, volume, memory, jobs and groups. Talk to it directly.
- **They see each other:** every fleet agent can look at the others by name (`peer.sh look junior`), and the supervisor looks at all of them. Looking includes the recent conversation ([PEERS.md](PEERS.md)).
- **Groups:** set them up as in [GETTING-STARTED.md](GETTING-STARTED.md#9-running-it-in-telegram): supergroups from the start, distinct names, the @username, one agent as the voice for messages to everyone ([GROUPS.md](GROUPS.md#several-agents-in-one-group)).
- **The supervisor stays out of open groups.** It is the agent with the most power, and groups are where a stranger can try to persuade it.
- **The weekly review** covers every agent, the supervisor first.

## 7. Updating

1. Read the [CHANGELOG](../CHANGELOG.md).
2. The supervisor, in its folder: `git fetch --tags && git checkout vX.Y.Z && docker compose up -d --build`.
3. The fleet's clone: `sudo git -C /opt/agent-launchpad fetch --tags && sudo git -C /opt/agent-launchpad checkout vX.Y.Z`.
4. Each fleet agent: `sudo systemctl restart agent-launchpad@NAME` (it rebuilds from the clone; memory and settings stay in its volume).
5. If the release changed `host/launchpad/`, install the changed files again as in section 4.

## 8. Stopping and deleting an agent

Only you, on the server; the supervisor cannot.

- **Stop:** `sudo systemctl stop agent-launchpad@NAME`. The volume stays; `start` brings it back.
- **Delete:**
  1. `sudo systemctl stop agent-launchpad@NAME`
  2. `sudo rm /srv/agent-fleet/NAME.env`
  3. `docker volume rm agent-NAME_data` (its memory and conversations: this cannot be undone)
  4. In @BotFather, delete the bot (`/deletebot`), so its token stops working.
  5. Remove it from the other agents ("forget NAME").

Do not reuse a deleted agent's name for a new one until its volume is gone: the new agent would start with the old one's memory and settings.

## Limits and risks

- **The supervisor holds the manager bot's token**, which can replace the token of every bot it created. If the supervisor is persuaded to leak it, someone could take over the fleet's bots from outside. Keep it out of open groups and review it first.
- **One Claude key for the fleet:** one agent cannot be revoked or measured alone. A leaked key means replacing it for every agent (`fixed.env`, then restart each one).
- **Bot-to-Bot is on by default** for new agents: two agents in a group can answer each other in a loop. Their instructions tell them never to keep a bot exchange going, but that is an instruction, not a lock, and Telegram may restrict bots that loop.
- **The supervisor can start an agent you stopped**, if its file is still in `/srv/agent-fleet`. Delete the file to keep an agent stopped for good.
- **Every fleet agent can look at every other**, including its recent conversation, and change its groups and super-users (each owner is told). A persuaded agent reaches the whole fleet, except the supervisor.
- **The supervisor's steps are instructions:** the host fixes the owner, the Claude key and Claude's flags of every new agent whatever the supervisor writes, and only lets it *start* well-named agents. Everything else (checking who created a bot, not showing a token) is the model's judgment, reviewed by you.

## What is verified

- **In CI:** the start command refuses every malformed name before `sudo`; the sudo rule allows only `start` of a well-formed unit; the unit fails a start without the agent's file; a hostile agent file cannot set the owner, the Claude key or Claude's flags (`tests/launchpad_test.sh`).
- **On a lab server (2026-11-25):** the same checks through real SSH, `sudo` and systemd, from inside a container; a refused key from outside Docker's networks; no terminal; an agent started from a clean file answered on Telegram. A bot created with Managed Bots worked with the official plugin.
- **Not verified yet:** the supervisor doing the whole creation by itself from a chat request, end to end; Telegram sent the `managed_bot` update for one lab bot and not for another, so the supervisor relies on the `managed_bot_created` message instead.
