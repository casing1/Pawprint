# Counting downloads and active users

Two separate questions, with two very different answers.

## Downloads — already working, nothing to set up

GitHub counts every release asset fetch and exposes it through the API. No code in the app, no
server, no privacy cost at all.

```bash
./scripts/stats.sh
```

That prints per-release download counts plus repository traffic. Read it as:

| Asset | What it means |
|---|---|
| `.dmg` | Closest thing to a fresh install — this is what a new user downloads. |
| `.zip` | Fetched by the in-app updater, so it counts upgrades as well as first installs. |

Repository traffic (`views` / `clones`) needs push access to the repo, which the owner has.

**What this cannot tell you:** whether anybody kept the app. A download is not a user.

## Active users — optional, off until you deploy something

This one needs the app to say "I'm still here", which means a network request, which the app
otherwise doesn't make. So it is built to give up as little as possible.

### What gets sent

Once a day, at most, four short strings:

```json
{ "day": "9f2c1a7e5b3d4088", "month": "31ab77c0e1f29d54", "version": "0.3.2", "os": "26" }
```

* **No counters and no metrics.** Nothing about how the Mac was used. That is the thing Pawprint
  promises never to transmit, and an analytics endpoint is exactly where such a promise would
  erode first, so the payload has no room for it by construction.
* **No stable identifier.** The install ID is a random UUID that never leaves the machine. What is
  sent is `SHA256(installID + date)`, truncated — so the same install produces an unrelated value
  tomorrow. Distinct `day` hashes on a date give you daily actives; distinct `month` hashes give
  monthly actives. Two days' rows cannot be joined, so the data set cannot answer "when does this
  person use their Mac".
* **No IP address is stored.** Cloudflare necessarily sees one; the worker never writes or logs it.

### Off by default in practice

`usageStatsEndpoint` ships **empty**, and with no endpoint the reporter never opens a connection.
A stock build of Pawprint is exactly as offline as it was before this existed. The toggle in
Settings → Updates only starts meaning something once an endpoint is configured.

### Deploying the endpoint

Cloudflare Workers + D1, both free at this scale.

```bash
cd scripts/usage-worker
npx wrangler d1 create pawprint-usage     # paste the printed database_id into wrangler.toml
npx wrangler deploy
```

You get a URL like `https://pawprint-usage.<account>.workers.dev`. Then either:

* set it in **Settings → Updates → 익명 사용 통계** on your own machine, to check it works; or
* make it the shipped default by changing `usageStatsEndpoint` in
  `Sources/Pawprint/Models/AppSettings.swift` — **and say so in the README's privacy section and
  in the first-run wizard**, because that is the point at which the app starts making a request
  users did not ask for.

Reading the numbers:

```bash
PAWPRINT_STATS_ENDPOINT=https://pawprint-usage.<account>.workers.dev ./scripts/stats.sh
```

### Why not an off-the-shelf analytics service

| Option | Why not |
|---|---|
| Google Analytics / Firebase | Ad-tech identifiers and cross-site tracking, in an app whose entire pitch is that your data stays put. Non-starter. |
| Plausible / Fathom (hosted) | Genuinely privacy-respecting, but page-analytics shaped and paid; a desktop app pinging them is off-label and still ships a third party your users' requests. |
| Sparkle's update stats | Real precedent for exactly this, but it rides on the updater's User-Agent and needs a server that logs — which is what the worker already is, without also logging IPs. |
| Self-hosted Umami / GoatCounter | Fine, but a VM to run and patch forever for one integer a day. |

The worker is ~120 lines, costs nothing, stores four columns, and can be read end to end in a
minute — which matters more here than features, because anyone can check what it does.
