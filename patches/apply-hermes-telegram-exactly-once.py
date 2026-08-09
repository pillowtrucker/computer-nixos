#!/usr/bin/env python
"""Apply the exactly-once telegram patch to the hermes-agent checkout.
Surgical string replacements — aborts loudly if any anchor is missing."""
import sys

REPO = "/etc/nixos/hermes-agent"

def patch(path, pairs):
    with open(path) as f:
        src = f.read()
    for old, new in pairs:
        if src.count(old) != 1:
            print(f"ABORT: anchor occurs {src.count(old)}x in {path}: {old[:80]!r}")
            sys.exit(1)
        src = src.replace(old, new)
    with open(path, "w") as f:
        f.write(src)
    print(f"patched {path} ({len(pairs)} hunks)")

# ── Patch A: adapter ingress dedup ──────────────────────────────────────
patch(f"{REPO}/plugins/platforms/telegram/adapter.py", [
    # A1: import collections
    (
        "import asyncio\nimport dataclasses\n",
        "import asyncio\nimport collections\nimport dataclasses\n",
    ),
    # A2: ledger state in __init__
    (
        "        self._pending_photo_batches: Dict[str, MessageEvent] = {}",
        "        self._pending_photo_batches: Dict[str, MessageEvent] = {}\n"
        "        # ── Exactly-once inbound delivery (LOCAL PATCH 2026-08-09) ──\n"
        "        # Telegram redelivers pending updates after a reconnect/crash,\n"
        "        # and hermes' #47237 guard only dedupes transcript persistence,\n"
        "        # not the agent turn itself — so the user saw duplicate replies.\n"
        "        # Dedup at INGRESS by update_id (globally unique, strictly\n"
        "        # increasing per bot). The ledger is an in-memory bounded\n"
        "        # deque: it survives the 409-conflict application rebuild\n"
        "        # (which is exactly when redelivery happens) because the\n"
        "        # adapter instance does; cross-restart redelivery is covered\n"
        "        # by Telegram's own getUpdates offset tracking plus the\n"
        "        # platform_message_id persistence guard in gateway/run.py.\n"
        "        self._seen_update_ids: collections.deque = collections.deque(maxlen=512)\n"
        "        self._seen_update_lock = threading.Lock()",
    ),
    # A3: gate method, right before _effective_update_message
    (
        "    def _effective_update_message(self, update: Update) -> Optional[Message]:",
        "    def _update_already_seen(self, update: Update) -> bool:\n"
        "        \"\"\"Exactly-once gate (LOCAL PATCH 2026-08-09).\n"
        "\n"
        "        Returns True when this PTB ``update_id`` was already handled\n"
        "        earlier in this process — i.e. a redelivery after a reconnect,\n"
        "        crash recovery, or the 409-conflict handler re-entering polling\n"
        "        without dropping pending updates. Without this gate the same\n"
        "        update runs the agent turn twice and the user sees the reply\n"
        "        twice (observed live in ~/.hermes/state.db). One PTB update\n"
        "        dispatches to exactly one handler, so a single shared window\n"
        "        across all handlers is correct. Missing update_id (never\n"
        "        happens with PTB) fails OPEN: process the message rather than\n"
        "        silently dropping user input.\n"
        "        \"\"\"\n"
        "        uid = getattr(update, \"update_id\", None)\n"
        "        if uid is None:\n"
        "            return False\n"
        "        with self._seen_update_lock:\n"
        "            if uid in self._seen_update_ids:\n"
        "                return True\n"
        "            self._seen_update_ids.append(uid)\n"
        "            return False\n"
        "\n"
        "    def _effective_update_message(self, update: Update) -> Optional[Message]:",
    ),
    # A4: text handler gate
    (
        "        Telegram clients split long messages into multiple updates.  Buffer\n"
        "        rapid successive text messages from the same user/chat and aggregate\n"
        "        them into a single MessageEvent before dispatching.\n"
        "        \"\"\"\n"
        "        msg = self._effective_update_message(update)",
        "        Telegram clients split long messages into multiple updates.  Buffer\n"
        "        rapid successive text messages from the same user/chat and aggregate\n"
        "        them into a single MessageEvent before dispatching.\n"
        "        \"\"\"\n"
        "        if self._update_already_seen(update):\n"
        "            logger.info(\n"
        "                \"[Telegram] Dropping redelivered update %s (exactly-once gate)\",\n"
        "                getattr(update, \"update_id\", None),\n"
        "            )\n"
        "            return\n"
        "        msg = self._effective_update_message(update)",
    ),
    # A5: command handler gate
    (
        "    async def _handle_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:\n"
        "        \"\"\"Handle incoming command messages.\"\"\"\n"
        "        msg = self._effective_update_message(update)",
        "    async def _handle_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:\n"
        "        \"\"\"Handle incoming command messages.\"\"\"\n"
        "        if self._update_already_seen(update):\n"
        "            logger.info(\n"
        "                \"[Telegram] Dropping redelivered update %s (exactly-once gate)\",\n"
        "                getattr(update, \"update_id\", None),\n"
        "            )\n"
        "            return\n"
        "        msg = self._effective_update_message(update)",
    ),
    # A6: location handler gate
    (
        "    async def _handle_location_message(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:\n"
        "        \"\"\"Handle incoming location/venue pin messages.\"\"\"\n"
        "        msg = self._effective_update_message(update)",
        "    async def _handle_location_message(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:\n"
        "        \"\"\"Handle incoming location/venue pin messages.\"\"\"\n"
        "        if self._update_already_seen(update):\n"
        "            logger.info(\n"
        "                \"[Telegram] Dropping redelivered update %s (exactly-once gate)\",\n"
        "                getattr(update, \"update_id\", None),\n"
        "            )\n"
        "            return\n"
        "        msg = self._effective_update_message(update)",
    ),
    # A7: media handler gate
    (
        "    async def _handle_media_message(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:\n"
        "        \"\"\"Handle incoming media messages, downloading images to local cache.\"\"\"",
        "    async def _handle_media_message(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:\n"
        "        \"\"\"Handle incoming media messages, downloading images to local cache.\"\"\"\n"
        "        if self._update_already_seen(update):\n"
        "            logger.info(\n"
        "                \"[Telegram] Dropping redelivered update %s (exactly-once gate)\",\n"
        "                getattr(update, \"update_id\", None),\n"
        "            )\n"
        "            return",
    ),
    # A8: callback query handler gate
    (
        "        \"\"\"Handle inline keyboard button clicks.\"\"\"\n"
        "        query = update.callback_query",
        "        \"\"\"Handle inline keyboard button clicks.\"\"\"\n"
        "        if self._update_already_seen(update):\n"
        "            logger.info(\n"
        "                \"[Telegram] Dropping redelivered update %s (exactly-once gate)\",\n"
        "                getattr(update, \"update_id\", None),\n"
        "            )\n"
        "            return\n"
        "        query = update.callback_query",
    ),
])

# ── Patch B: run.py fallback-branch persistence dedup ───────────────────
patch(f"{REPO}/gateway/run.py", [
    (
        "                # If no new messages found (edge case), fall back to simple user/assistant\n"
        "                if not new_messages:\n"
        "                    _user_entry = {\n"
        "                        \"role\": \"user\",\n"
        "                        \"content\": (\n"
        "                            persist_user_message\n"
        "                            if persist_user_message is not None\n"
        "                            else message_text\n"
        "                        ),\n"
        "                        \"timestamp\": (\n"
        "                            persist_user_timestamp\n"
        "                            if persist_user_timestamp is not None\n"
        "                            else ts\n"
        "                        ),\n"
        "                    }\n"
        "                    if event.message_id:\n"
        "                        _user_entry[\"message_id\"] = str(event.message_id)\n"
        "                    await self.async_session_store.append_to_transcript(\n"
        "                        session_entry.session_id,\n"
        "                        _user_entry,\n"
        "                        skip_db=agent_persisted,\n"
        "                    )\n"
        "                    if response:\n"
        "                        await self.async_session_store.append_to_transcript(\n"
        "                            session_entry.session_id,\n"
        "                            {\"role\": \"assistant\", \"content\": response, \"timestamp\": ts},\n"
        "                            skip_db=agent_persisted,\n"
        "                        )\n",
        "                # If no new messages found (edge case), fall back to simple user/assistant\n"
        "                if not new_messages:\n"
        "                    _user_entry = {\n"
        "                        \"role\": \"user\",\n"
        "                        \"content\": (\n"
        "                            persist_user_message\n"
        "                            if persist_user_message is not None\n"
        "                            else message_text\n"
        "                        ),\n"
        "                        \"timestamp\": (\n"
        "                            persist_user_timestamp\n"
        "                            if persist_user_timestamp is not None\n"
        "                            else ts\n"
        "                        ),\n"
        "                    }\n"
        "                    if event.message_id:\n"
        "                        _user_entry[\"message_id\"] = str(event.message_id)\n"
        "                    # Dedupe (LOCAL PATCH 2026-08-09): mirror of the #47237\n"
        "                    # guard above — this fallback branch previously persisted\n"
        "                    # unconditionally, so a redelivered platform message that\n"
        "                    # hit the empty-new_messages edge case got stored twice.\n"
        "                    _skip_persist_fallback = (\n"
        "                        event.message_id\n"
        "                        and await self.async_session_store.has_platform_message_id(\n"
        "                            session_entry.session_id, str(event.message_id)\n"
        "                        )\n"
        "                    )\n"
        "                    if _skip_persist_fallback:\n"
        "                        logger.info(\n"
        "                            \"Skipping duplicate user turn in fallback branch \"\n"
        "                            \"(message_id=%s) in session %s\",\n"
        "                            event.message_id, session_entry.session_id,\n"
        "                        )\n"
        "                    else:\n"
        "                        await self.async_session_store.append_to_transcript(\n"
        "                            session_entry.session_id,\n"
        "                            _user_entry,\n"
        "                            skip_db=agent_persisted,\n"
        "                        )\n"
        "                        if response:\n"
        "                            await self.async_session_store.append_to_transcript(\n"
        "                                session_entry.session_id,\n"
        "                                {\"role\": \"assistant\", \"content\": response, \"timestamp\": ts},\n"
        "                                skip_db=agent_persisted,\n"
        "                            )\n",
    ),
])

print("ALL PATCHES APPLIED")
