// Telegram's webhook ends here while the agent sleeps (docs/SLEEP.md). A ring that carries the secret is answered
// with 503, so Telegram keeps the message for the plugin to collect, and this process exits. Anything else gets 403 with
// this sleep's nonce, which lets doorbell.sh tell its own listener from anything else in front of the address that says 403.
const secret = process.env.DOORBELL_SECRET
const nonce = process.env.DOORBELL_NONCE || "no"
Bun.serve({
  port: Number(process.env.PORT || 8080),
  fetch(req) {
    if (!secret || req.headers.get("x-telegram-bot-api-secret-token") !== secret) return new Response(nonce, { status: 403 })
    setTimeout(() => process.exit(0), 100)
    return new Response("waking", { status: 503 })
  },
})
