# Sleep when idle, wake on a message

Opt-in; the Railway template turns it on. An agent listens to Telegram by asking it for messages without pause, so to its host it always looks busy and is billed around the clock, mostly for memory. With `IDLE_SLEEP_MINUTES` set, an agent nobody is talking to stops costing.

## How it works

1. After `IDLE_SLEEP_MINUTES` without activity in the conversation, `start.sh` stops Claude.
2. `doorbell.sh` tells Telegram to call this service when a message arrives (a webhook, protected by a secret only Telegram and the agent know) and waits. Nothing talks to the network any more, so a host that suspends idle containers (Railway Serverless) suspends this one.
3. A message arrives. Telegram calls; the host wakes the container if it was suspended. The call is answered **503**, which makes Telegram keep the message.
4. The webhook is removed and Claude starts with `--continue`. The **official plugin** receives the message the way it always does, by polling.

The doorbell never reads or forwards a message. That is why a message cannot be delivered twice, however often Telegram retries the call, and why messages sent in a row arrive once each, in order.

## Set-up

| Variable | Value |
|---|---|
| `IDLE_SLEEP_MINUTES` | Minutes without activity before sleeping, e.g. `10`. Unset = never sleep |
| `DOORBELL_URL` | The public `https://…` address of this service. On Railway it is taken from the service's public domain |
| `PORT` | Port the doorbell listens on (default 8080); the public address must route to it |

On Railway: generate a public domain for the service with target port 8080, and turn **Serverless** on in the service settings. The template sets the domain and `IDLE_SLEEP_MINUTES` (3); Serverless is the one switch a template cannot set (checked 2026-11-21: the template editor has no such setting, and Config as Code, `railway.json`, is no longer read by new services), so whoever deploys turns it on and redeploys.

Without Serverless the agent still stops Claude, but the host keeps the container running and billed. The agent cannot read that setting, so it watches its own clock: a host that suspends the container stops time for it, and on waking the clock has jumped. Asleep for 30 minutes without a jump, and with no scheduled jobs (which keep the container on purpose), it tells the owner once per start to turn Serverless on.

## Measured on Railway (2026-11-11)

| State when the message arrived | Time |
|---|---|
| Claude stopped, container running | Doorbell reached 0.9 s after sending; Claude starting 0.5 s later |
| Container suspended by the host for 4 hours | The owner measured 2 to 3 s to the answer |

- Memory: 0.40 GB average for an agent that is always on; 0.12 GB with Claude stopped; **0 while suspended** (three hours of metrics at zero).
- Several messages sent in a row to a suspended agent arrived once each, in order.

## What changes when an agent sleeps

- **If Telegram refuses the webhook** (no HTTPS), the agent does not sleep: the log says `not sleeping: Telegram did not accept the webhook`. Telegram does accept an address that does not reach the agent (for example a domain pointed at the wrong port), so before sleeping the agent also calls itself through that address; if its own listener does not answer, the log says `not sleeping: … does not reach this service on port …` and it removes the webhook. Either way it keeps working, always on, and tells the owner on Telegram why it cannot sleep (once per start), since an agent that stays awake is billed around the clock.
- **Scheduled jobs.** A suspended container runs nothing. If the agent has jobs, the doorbell sends one packet every four minutes so the host keeps the container (Claude still sleeps: about a third of the memory). An agent without jobs is suspended completely.
- **Nightly backup.** It would not run in a suspended container, so a backup is made when going to sleep if the last one is older than 20 hours.
- **The first answer** after a sleep takes a few seconds longer.
- **The peer view** of a suspended agent: untested. Private-network traffic should wake the container, and the first attempt may fail.
- The public address only wakes the container; without the secret the doorbell answers 403 and Claude is not started. After a wake with no message waiting, the agent goes straight back to waiting.

## Not verified yet

- The host's invoice itself (the metrics show zero while suspended).
- Groups, and updates other than plain messages, as the ring.
- The Serverless check (30 minutes asleep without a clock jump) on a real host: tested only with a simulated clock.
- The keep-awake for agents with jobs, and the backup before sleeping, on a real host.
- Hosts other than Railway.
