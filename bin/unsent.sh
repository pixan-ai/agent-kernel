#!/usr/bin/env bash
# The owner wrote in private and nothing went back: a model sometimes writes its answer in the terminal, which nobody reads, and ends
# the turn without the reply tool (docs/LEARNINGS.md, "Telegram"). Three hooks of the managed policy call this, with their input on stdin.
# Usage: unsent.sh in    (UserPromptSubmit) a message from the owner's private chat arrived: mark it. Groups are not marked: there, silence is often right.
#        unsent.sh out   (PostToolUse of the Telegram tools) something was sent: clear the mark.
#        unsent.sh stop  (Stop) the turn ends with the mark still there: send Claude back once to use the reply tool; if it ends again
#                        without sending, send the owner what it wrote the first time. A mark, not a count: one reply clears it.
set -uo pipefail
M=/data/cron/unsent
[ "${CLAUDE_CONFIG_DIR-}" != /data/cron/config ] || exit 0  # a job or the dream: no Telegram there (the image sets the variable)
case ${1:-} in
  in) rm -f $M $M.said; o=${OWNER_TELEGRAM_ID:-$(sed -n 's/^OWNER_TELEGRAM_ID=//p' /data/config/channels/telegram/.env 2> /dev/null)}
    # The plugin's own tag opens the prompt and names the chat; a tag typed inside a message comes later and is not looked at.
    jq -r '.prompt // ""' | head -1 | grep -q "^<channel [^>]*chat_id=\"$o\"" && : > $M ;;
  out) rm -f $M $M.said ;;
  stop) [ -e $M ] || exit 0; t=$(jq -r '.last_assistant_message // ""')
    if [ ! -e $M.said ]; then printf '%s' "$t" > $M.said
      echo '{"decision":"block","reason":"Your answer is only in the terminal, which nobody reads: the owner has received nothing. Send it now with the Telegram reply tool, using the chat_id of their message."}'
    else s=$(cat $M.said); rm -f $M $M.said; s=${s:-$t}
      notify.sh "${s:-⚠️ I received your message and have no answer to send. Please write to me again.}" || true; fi ;;
esac
exit 0
