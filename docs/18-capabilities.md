# 18. Capabilities: how Phew acts through real doors (phase NB)

Written 16 November 2026. Research only: nothing is built, no connection was made, no account was touched. The plain-words version with drawings is `docs/connections.html`. This file holds the design in short (18.1) and the two research notes in full, with a link for every claim (18.2, 18.3). What could not be verified is marked in the notes and gathered at the end of each.

## 18.1 The design in short

**The order of doors.** When a job can go through more than one, he takes the first that exists: a connection (MCP) to the tool; a file in a folder you chose; the app's own scripting or one of your Shortcuts; the web; the screen (press, type, click) last.

**How connections are built: a client inside Phew, in Swift** (design (b) in 18.2 section 7), with the official Swift kit. Not through the Claude API's own connector, and not with a bundled helper such as `mcp-use`. Reasons: only a client inside Phew sees a call before it runs, so the one acting function, the card and the confirm rules keep working; sign-in tokens stay in the Keychain and go only to the tool; the desktop doors of Figma and Fusion are on the Mac and only a local client reaches them; the API's connector does not do the sign-in anyway.

**The first doors, in order.** Notion (open sign-in, read and write). Your Shortcuts as tools, the ones you tick; a shortcut can do anything and cannot be inspected, so it counts as "cannot be undone" unless you mark it safe. Fusion's desktop door (read and change the open design; switched on in its preferences, and open to any program on the Mac while on) and Figma's (read only; needs a paid Dev or Full seat; to be tested). GitHub and Linear if used. Google, Slack and Microsoft later: each needs a registration with the vendor, Slack and Microsoft also an admin's approval, and Microsoft is for work or school accounts.

**Guards.**
- A fixed list of servers, each run by the tool's own maker. No free "add any server" field at first.
- The list of a server's tools is remembered on the day you connect; if it changes, he stops and shows the change.
- Phew's own table says which tools read and which write. Reads run freely. Writes go through the one acting function, with the "cannot be undone or leaves your Mac" class decided by code: a change in a cloud tool leaves your Mac by definition.
- What a tool answers is data, never orders. The secrets filter runs on it before any model call.
- Tokens in the Keychain, one per server, smallest reach.
- Only the tools that fit the job are sent to the model, to keep the cost down.

**`mcp-use`.** A good open-source kit for TypeScript and Python. Not usable inside a native Swift app without shipping a second runtime, and its agent would call the model outside Phew's one provider and cost log. Useful beside Phew as a workbench: its Inspector shows a server's real tools before any code is written.

**Agents that start agents.** The smallest version runs on the Mac: the lead (main model) may call one tool, `start_workers`; Phew's code opens up to 4 Claude calls at once on the small model, each with one question, a named tool set and a budget; workers only read and cannot start workers; a check by code, then one fresh model read, before you see anything. Limits by code: 4 workers, depth 1, one split per job, $2 per job, 5 minutes per worker. Anthropic measured several agents at about 4 times one agent (about 15 times a chat), and its later guidance says 3 to 10 times, so not splitting is the normal case. Workers that act, hosted agents and self-made tools are not built yet (the last is phase NC).

**Two short tests before building** (each a few minutes, with your word since they touch a real service): does each tool's server accept the standard's 2025-11-25 version, which the Swift kit speaks, and does its sign-in accept an app it does not know; does the sign-in flow work from a menu-bar app without breaking the focus rules.

**Rules this changes.** "Calls only the Claude API" becomes "calls the Claude API and the tools you connected". "He never takes focus" gets a third exception: the browser, once per tool, for sign-in.

---

## 18.2 Research note: connections (MCP)

## MCP for a native macOS app: research notes

Researched 16 November 2026. Every claim has a link. "Not verified" marks what I could not confirm on a primary source. Web pages were read as data only.

Short version, for the hurried reader:

- MCP is a standard way for an AI app to talk to a tool. The tool's maker runs a small "server" that lists what it can do; the app is the "client" that asks.
- The current specification is dated **2026-07-28**. It changed the protocol a lot: there is no opening handshake and no session any more.
- The Claude API can call **remote** MCP servers by itself (the "MCP connector"). It is in beta, it covers tools only, it cannot reach programs on the Mac, and the app has to get the sign-in token itself.
- There is an official **Swift** SDK, maintained with Apple. It works, but it is the lowest support tier and it still speaks the previous protocol version (2025-11-25).
- `mcp-use` is a TypeScript and Python framework. A Swift app could only use it as a separate helper program.
- The main risks are not in the wire protocol. They are: text in a tool's description or in a tool's result that the model obeys, a server that changes its tools after you approved them, tokens that open too much, and local servers that run with all of the user's rights.

---

### 1. MCP itself

#### 1.1 The three roles

- **Host**: the AI application the person uses. It starts connections. Here, the macOS app.
- **Client**: the connector inside the host. One client talks to one server.
- **Server**: the service that offers context and abilities (a program on the Mac, or a web address).

Source: [Specification overview](https://modelcontextprotocol.io/specification/latest) ("Hosts: LLM applications that initiate connections; Clients: Connectors within the host application; Servers: Services that provide context and capabilities"). Messages are JSON-RPC 2.0.

#### 1.2 What a server can offer

| Feature | What it is | Who decides to use it |
|---|---|---|
| **Tools** | Functions the model can call (search, create a page, send a message) | The model |
| **Resources** | Data to read (a file, a record), addressed by a URI | The app or the user |
| **Prompts** | Ready-made message templates | The user |

Source: [Specification overview](https://modelcontextprotocol.io/specification/latest), [Tools](https://modelcontextprotocol.io/specification/2026-07-28/server/tools).

A tool definition has: `name`, optional `title`, `description`, `inputSchema` (JSON Schema, default dialect 2020-12), optional `outputSchema`, optional `icons`, optional `annotations` (hints such as read-only or destructive). The specification says clients **MUST** treat annotations as untrusted unless the server is trusted. Source: [Tools, Data Types](https://modelcontextprotocol.io/specification/2026-07-28/server/tools).

#### 1.3 What a client can offer, and the newer parts

- **Elicitation**: the server asks the user for more information through the client (a small form, or "URL mode", which sends the user to a web page, for example to sign in). Active. URL mode was added in 2025-11-25. Source: [2025-11-25 changelog](https://modelcontextprotocol.io/specification/2025-11-25/changelog).
- **Sampling** (the server asks the host's model to write something), **Roots** (the client tells the server which folders it may use) and **Logging**: all three are **Deprecated** in 2026-07-28. They still work during the deprecation window (at least twelve months), but new software should not add them. Suggested replacements: pass folders as tool parameters, call the model provider's API directly, log to `stderr`. Source: [2026-07-28 changelog, Deprecated](https://modelcontextprotocol.io/specification/2026-07-28/changelog), [Versioning, Feature States](https://modelcontextprotocol.io/specification/versioning).
- **Tasks**: long-running work with a handle you poll. Experimental inside the core in 2025-11-25; moved out into an official **extension** (`io.modelcontextprotocol/tasks`) in 2026-07-28, with `tasks/get` polling and `tasks/update`. Source: [2026-07-28 changelog, item 6](https://modelcontextprotocol.io/specification/2026-07-28/changelog).
- **MCP Apps** (extension `io.modelcontextprotocol/ui`): a server can send a small interactive interface (HTML) to be shown inside the conversation. Opt-in on both sides. Source: [Specification overview, Extensions](https://modelcontextprotocol.io/specification/latest), [Versioning and Compatibility](https://modelcontextprotocol.io/specification/2026-07-28/basic/versioning).
- **Skills over MCP**: listed as a notable extension (instructions for agent workflows found through MCP). Source: [Specification overview](https://modelcontextprotocol.io/specification/latest).

Extensions are always optional and are agreed through the `extensions` field of the capabilities.

#### 1.4 Transports in the current specification

Two standard transports. Source: [Transports overview](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports).

1. **stdio**: the client starts the server as a child program on the same machine and exchanges one JSON message per line over the program's standard input and output. No network.
2. **Streamable HTTP**: the server has one web address (the "MCP endpoint"). Every message from the client is its own HTTP `POST`. The answer is either one JSON object or a stream (Server-Sent Events) that belongs to that one request. Source: [Streamable HTTP](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http).

Facts about Streamable HTTP in 2026-07-28:

- Required headers on each POST: `MCP-Protocol-Version` (for example `2026-07-28`), `Mcp-Method`, and `Mcp-Name` for `tools/call`, `resources/read`, `prompts/get`. `Accept` must list both `application/json` and `text/event-stream`.
- No sessions: the `Mcp-Session-Id` header is gone. No GET stream. No resuming a broken stream; the client sends the request again with a new id.
- Change notices (for example "my tool list changed") arrive on a long-lived `subscriptions/listen` request.
- Servers **MUST** validate the `Origin` header, and a local server **SHOULD** listen only on 127.0.0.1.
- To cancel, the client closes the stream.

**The old "HTTP+SSE" transport** (protocol 2024-11-05, two endpoints) has been deprecated since 2025-03-26 and is formally in the Deprecated state in 2026-07-28: new software should not adopt it, and it may be removed in a later revision. Many servers still expose an `/sse` address next to `/mcp`. Source: [Streamable HTTP, Backward Compatibility](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http).

Custom transports are allowed if they keep the JSON-RPC format.

#### 1.5 Lifecycle: how a conversation with a server goes

This is the part that changed most. There are now two "eras". Source: [Versioning and Compatibility](https://modelcontextprotocol.io/specification/2026-07-28/basic/versioning).

**Modern (2026-07-28 and later): no handshake.**

1. Optional: the client calls `server/discover` to learn the server's versions, capabilities and identity. Servers must implement it; clients may skip it.
2. Every request carries, in `params._meta`, the protocol version (`io.modelcontextprotocol/protocolVersion`), the client's capabilities (`io.modelcontextprotocol/clientCapabilities`) and, recommended, the client's name (`io.modelcontextprotocol/clientInfo`).
3. `tools/list` returns the tools (with paging by `cursor`, and `ttlMs` and `cacheScope` hints so the client can cache the list).
4. `tools/call` runs one tool and returns a result.
5. If the version is not supported, the server answers `UnsupportedProtocolVersionError` (code `-32022`) with the list it supports, and the client retries.
6. If the server needs something from the user in the middle (elicitation), it does not send its own request. It returns a result with `resultType: "input_required"`; the client collects the input and sends the original request again with `inputResponses`. This pattern is called Multi Round-Trip Requests.

**Legacy (2025-11-25 and earlier): handshake and session.**

1. Client sends `initialize` with its version and capabilities; server answers with its own; client sends `notifications/initialized`.
2. Then `tools/list`, `tools/call` as above, inside that session.

Compatibility, from the specification's own table:

| Client | Server | Result |
|---|---|---|
| Modern | Modern | Works |
| Modern only | Legacy only | **Fails** |
| Legacy only | Modern only | **Fails** (a legacy client has no way to move forward) |
| Either | Dual-era server | Works |
| Dual-era client | Either | Works (it probes, then falls back to `initialize`) |

This matters for the Swift SDK (section 3): today it is a legacy client.

**Errors, two kinds.** Source: [Tools, Error Handling](https://modelcontextprotocol.io/specification/2026-07-28/server/tools).

- *Protocol errors*: the request itself is wrong (unknown tool, malformed). Returned as a JSON-RPC `error`, for example code `-32602`.
- *Tool execution errors*: the tool ran and failed (bad date, API refused). Returned as a normal result with `isError: true` and a text the model can read and correct from.

#### 1.6 A real example: `tools/list` and `tools/call`

Taken from the specification ([Tools](https://modelcontextprotocol.io/specification/2026-07-28/server/tools), [Streamable HTTP](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http)).

Ask for the tools:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/list",
  "params": {
    "_meta": {
      "io.modelcontextprotocol/protocolVersion": "2026-07-28",
      "io.modelcontextprotocol/clientInfo": { "name": "ExampleClient", "version": "1.0.0" },
      "io.modelcontextprotocol/clientCapabilities": {}
    }
  }
}
```

Answer:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "resultType": "complete",
    "tools": [
      {
        "name": "get_weather",
        "title": "Weather Information Provider",
        "description": "Get current weather information for a location",
        "inputSchema": {
          "type": "object",
          "properties": {
            "location": { "type": "string", "description": "City name or zip code" }
          },
          "required": ["location"]
        }
      }
    ],
    "ttlMs": 300000,
    "cacheScope": "public"
  }
}
```

Call one tool (over HTTP this POST also carries the headers `MCP-Protocol-Version: 2026-07-28`, `Mcp-Method: tools/call`, `Mcp-Name: get_weather`; the `_meta` block is the same as above and is left out here, as the specification's own examples do):

```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/call",
  "params": {
    "name": "get_weather",
    "arguments": { "location": "New York" }
  }
}
```

Result:

```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "result": {
    "resultType": "complete",
    "content": [
      { "type": "text", "text": "Current weather in New York:\nTemperature: 72°F\nConditions: Partly cloudy" }
    ],
    "isError": false
  }
}
```

In the legacy versions the same two messages have no `_meta` version fields and no `resultType`, and they come after `initialize`.

#### 1.7 Authorization for remote servers

Source: [Authorization](https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization), [Client Registration](https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization/client-registration).

Authorization is optional in MCP. When a remote server uses it, it is **OAuth 2.1**. For stdio servers the specification says not to use this flow and to take credentials from the environment instead.

The flow, in plain steps:

1. The client calls the server without a token. The server answers `401` with a `WWW-Authenticate` header that points to its "protected resource metadata" (RFC 9728). Servers **MUST** publish this.
2. That document names the **authorization server** (the sign-in service). The client reads the sign-in service's metadata (RFC 8414 or OpenID Connect Discovery; clients must support both).
3. The client needs a **client ID**. Three ways, in this priority order:
   1. **Pre-registration**: the app's maker registered the app with that service beforehand and ships the ID.
   2. **Client ID Metadata Documents (CIMD)**: the client ID is an `https://` address the app's maker hosts, pointing to a small JSON file (`client_id`, `client_name`, `redirect_uris`). Recommended since 2025-11-25; used when the sign-in service advertises `client_id_metadata_document_supported`.
   3. **Dynamic Client Registration (DCR, RFC 7591)**: the client registers itself on the spot. **Deprecated in 2026-07-28**, kept only for older sign-in services. A native app must send `application_type: "native"`.
   4. If none works, ask the user to type the client details.
4. The client opens the browser on the sign-in page with **PKCE** and a `resource` parameter that names the MCP server (RFC 8707, mandatory). The user signs in and approves.
5. The browser returns to the app (for a desktop app, a `http://127.0.0.1:<port>/callback` address) with a code. The client checks the `iss` value (RFC 9207), then exchanges the code for an **access token**, and possibly a **refresh token**.
6. Every later request carries `Authorization: Bearer <access-token>`. Tokens must never go in the URL.

Scopes (what the token may do):

- The client should ask only for the scopes the server names in its `401` challenge, or failing that the `scopes_supported` list.
- If a later call needs more, the server answers `403` with `error="insufficient_scope"` and the client runs a "step-up" sign-in for the extra scope.
- Servers must check that a token was issued for them (audience) and must not pass a client's token on to another service ("token passthrough" is forbidden).
- Client credentials are bound to the sign-in service that issued them (keyed by its `issuer`).

A practical limit not in the specification: some vendors only let clients they have approved connect to their server (see section 5). OAuth being standard does not mean any app may connect.

#### 1.8 Versions and what changed

Current version: **2026-07-28**. Previous: **2025-11-25**. Before that: 2025-06-18, 2025-03-26, 2024-11-05. Version names are dates of the last breaking change. Source: [Versioning](https://modelcontextprotocol.io/specification/versioning).

**2026-07-28, main changes** ([changelog](https://modelcontextprotocol.io/specification/2026-07-28/changelog)):

1. Stateless protocol: the `initialize` handshake is removed. Each request carries its version and capabilities.
2. Sessions removed from Streamable HTTP (`Mcp-Session-Id` gone). Tool lists may not differ per connection. State across calls is carried by explicit handles passed as tool arguments.
3. New mandatory `server/discover`.
4. The GET stream and `resources/subscribe` are replaced by `subscriptions/listen`.
5. `ping`, `logging/setLevel` and `notifications/roots/list_changed` removed.
6. Tasks moved to an extension.
7. Servers no longer send requests to clients; they return `input_required` results (Multi Round-Trip Requests). Every result has a `resultType`.
8. Stream resuming removed.
9. Smaller: `Mcp-Method` and `Mcp-Name` headers required; `ttlMs` and `cacheScope` on list results; tools should be listed in a stable order (helps prompt caching); `iss` check in sign-in; any JSON Schema 2020-12 keyword allowed in schemas.
10. Deprecated: Roots, Sampling, Logging, the HTTP+SSE transport, Dynamic Client Registration.

**2025-11-25, main changes** ([changelog](https://modelcontextprotocol.io/specification/2025-11-25/changelog)):

1. Client ID Metadata Documents added as the recommended registration method.
2. OpenID Connect Discovery accepted for finding the sign-in service; protected resource metadata aligned with RFC 9728.
3. Step-by-step scope consent through `WWW-Authenticate`.
4. URL mode elicitation.
5. Experimental tasks.
6. Tool calling inside sampling.
7. Icons for tools, resources and prompts; guidance on tool names; JSON Schema 2020-12 as the default.
8. Input validation errors are to be returned as tool execution errors, so the model can correct itself.

---

### 2. The Claude API MCP connector

Source for everything in this section unless noted: [MCP connector](https://platform.claude.com/docs/en/agents-and-tools/mcp-connector) (read 16 November 2026; the page shows no "last updated" date).

#### 2.1 What it is

With the connector, the app sends a normal Messages API request that names one or more remote MCP servers. **Anthropic's servers** connect to those MCP servers, list their tools, let the model call them, and return everything in the same response. The app does not need an MCP client.

Status: **beta**.

#### 2.2 The exact request

Beta header, one of:

- `anthropic-beta: mcp-client-2026-09-15` (newest; Claude API only; includes everything in the older one and adds tool-list pinning);
- `anthropic-beta: mcp-client-2025-11-20` (also on Claude Platform on AWS, Claude Models on Google Cloud (Anthropic managed), Microsoft Foundry).

The older `mcp-client-2025-04-04` is deprecated.

Both halves are required: a server in `mcp_servers` and a matching `mcp_toolset` in `tools`.

```json
{
  "model": "claude-sonnet-5-5",
  "max_tokens": 1000,
  "messages": [{ "role": "user", "content": "What tools do you have available?" }],
  "mcp_servers": [
    {
      "type": "url",
      "url": "https://example-server.modelcontextprotocol.io/sse",
      "name": "example-mcp",
      "authorization_token": "YOUR_TOKEN"
    }
  ],
  "tools": [
    { "type": "mcp_toolset", "mcp_server_name": "example-mcp" }
  ]
}
```

(The page's examples use `claude-opus-5-5`; the model line above is changed to one of the two models this app uses. Both are on the supported list.)

`mcp_servers` entry:

| Field | Required | Meaning |
|---|---|---|
| `type` | yes | Only `url` is supported |
| `url` | yes | Must start with `https://` |
| `name` | yes | Unique; must be referenced by exactly one `mcp_toolset` |
| `authorization_token` | no | OAuth access token, if the server needs one |

`mcp_toolset` entry:

| Field | Required | Meaning |
|---|---|---|
| `type` | yes | `mcp_toolset` |
| `mcp_server_name` | yes | Must match a `name` in `mcp_servers` |
| `default_config` | no | Settings for all tools: `enabled` (default `true`), `defer_loading` (default `false`) |
| `configs` | no | Per-tool overrides, keyed by tool name |
| `cache_control` | no | A prompt-caching breakpoint for this toolset |
| `tools` | no | Only with `mcp-client-2026-09-15`: a pinned copy of the server's tool list |

Validation: every server must be used by exactly one toolset. An unknown tool name in `configs` gives no error (only a backend warning).

#### 2.3 Allowlist and denylist

Allow only two tools:

```json
{
  "type": "mcp_toolset",
  "mcp_server_name": "google-calendar-mcp",
  "default_config": { "enabled": false },
  "configs": {
    "search_events": { "enabled": true },
    "create_event": { "enabled": true }
  }
}
```

Block some tools: leave the default and set `"enabled": false` on the ones to block. The page recommends blocking write or destructive tools "when you want a human confirmation step before state changes".

Important for this app: the page describes **no way to approve a single call before it runs**. The tool runs on Anthropic's side inside the response. The only control is which tools are enabled.

#### 2.4 Supported models

"MCP connector is in beta on every model." The list on the page includes `claude-sonnet-5-5` and `claude-haiku-5-5`, plus the Fable, Mythos and Opus families, `claude-sonnet-5`, `claude-haiku-4-5-20251001`, `claude-sonnet-4-6`, `claude-opus-4-5-20251101`, `claude-sonnet-4-5-20250929`.

#### 2.5 Limits

- **Tools only.** Resources and prompts are not supported through the connector.
- **Remote only.** "The server must be publicly exposed through HTTP (supports both Streamable HTTP and SSE transports). Local STDIO servers cannot be connected directly."
- Several servers per request are allowed. The page gives **no maximum number** of servers (not verified whether one exists).
- For many tools, set `defer_loading: true` in `default_config` and add the tool search tool, so only relevant tool descriptions are loaded. Source: [Tool search tool, MCP integration](https://platform.claude.com/docs/en/agents-and-tools/tool-use/tool-search-tool).
- Not compatible with programmatic tool calling (stated in Anthropic's developer guidance; not re-verified on a docs page).
- **MCP tunnels** are a separate research-preview feature (request access; depends on Cloudflare) that lets the connector reach servers inside a private network through an outbound-only connection. It is built for company networks (Docker, Helm), not for a program on one person's Mac. Source: [MCP tunnels](https://platform.claude.com/docs/en/agents-and-tools/mcp-tunnels/overview).

#### 2.6 Who does the sign-in

The app does. Quote: "API consumers are expected to handle the OAuth flow and obtain the access token prior to making the API call, and to refresh the token as needed." And in the availability table: "For OAuth servers you get and refresh the access token yourself and pass it as `authorization_token`."

So the connector removes the MCP client, but **not** the OAuth work: discovery, client registration, browser sign-in, PKCE, token refresh and safe storage all stay in the app. The token is then sent to Anthropic inside each request, and Anthropic presents it to the MCP server.

For testing, the page suggests getting a token with the MCP Inspector (`npx @modelcontextprotocol/inspector`, needs Node.js).

#### 2.7 What comes back

Two block types in the response content:

```json
{
  "type": "mcp_tool_use",
  "id": "mcptoolu_014Q35RayjACSWkSj4X2yov1",
  "name": "echo",
  "server_name": "example-mcp",
  "input": { "param1": "value1", "param2": "value2" }
}
```

```json
{
  "type": "mcp_tool_result",
  "tool_use_id": "mcptoolu_014Q35RayjACSWkSj4X2yov1",
  "is_error": false,
  "content": [{ "type": "text", "text": "Hello" }]
}
```

With `mcp-client-2026-09-15` there is a third: `mcp_tool_listing`, one per server, at the start of the response, holding the tool list the server returned (`name`, `description`, `input_schema`). The app must send the assistant message back unchanged, these blocks included.

#### 2.8 Pinning the tool list (new, useful against "rug pulls")

"An MCP server can change its tools at any time." With `mcp-client-2026-09-15` the app can copy the `tools` from an `mcp_tool_listing` block into the toolset's `tools` field. Then "the API doesn't ask the server for its tools, and the toolset's tools are exactly those entries". Claude API only.

#### 2.9 Cost

- The page lists **no separate fee** for the connector. Batch requests with `mcp_servers` are "priced the same as those in regular Messages API requests".
- Tool definitions are input tokens. The tool-use pricing rule counts "the total number of input tokens sent to the model (including in the `tools` parameter)", plus a fixed tool-use system prompt per model. Tool results that come back also enter the context as input tokens for the rest of the turn. Source: [Tool use overview, Pricing](https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview).
- So a server with many tools and long descriptions costs tokens on every request unless the list is cached, trimmed by an allowlist, or deferred with tool search.
- Whether an *allowlisted-out* tool's description is still counted is not stated on the page (not verified).

#### 2.10 Data retention

"The MCP connector is not covered by ZDR arrangements. Data exchanged with MCP servers, including tool definitions and execution results, is retained according to Anthropic's standard data retention policy." Zero data retention: **not eligible**. HIPAA: not eligible.

#### 2.11 Streaming and prompt caching

- **Prompt caching: yes.** The `mcp_toolset` accepts `cache_control`. Pinning the tool list also helps, because the tool list stops changing.
- **Streaming: not stated on the connector page.** The API reference lists `mcp_tool_use` and `mcp_tool_result` among the beta content blocks ([Create a Message (beta)](https://platform.claude.com/docs/en/api/beta/messages/create)), and server-side blocks in general arrive through the usual `content_block_start` / `content_block_stop` events. I did not find a sentence that says "the MCP connector works with `stream: true`". **Not verified**; a five-minute test with a streaming request settles it.

#### 2.12 The other route Anthropic documents

The same page has "Client-side MCP helpers": if the app runs its own MCP client (for local stdio servers, prompts or resources), Anthropic's SDKs convert MCP tools into Claude API tools. These helpers exist for Python, TypeScript, C#, Go, Java, PHP and Ruby. **There is no Swift helper**, because there is no official Anthropic Swift SDK. In Swift the conversion is done by hand; it is small: an MCP tool's `name`, `description` and `inputSchema` become a Claude tool's `name`, `description` and `input_schema`.

---

### 3. An MCP client inside a Swift app

#### 3.1 The official Swift SDK

- Repository: [modelcontextprotocol/swift-sdk](https://github.com/modelcontextprotocol/swift-sdk). Description: "The official Swift SDK for Model Context Protocol servers and clients. Maintained in collaboration with Apple".
- Latest release: **0.12.1**, 7 May 2026. Main branch is active: 26 commits after that release, last push 15 November 2026. About 1,580 stars, 112 open issues. (GitHub API, read 16 November 2026.)
- Licence: in transition from MIT to **Apache-2.0** (new contributions are Apache-2.0; older ones stay MIT until relicensed). Source: [LICENSE](https://github.com/modelcontextprotocol/swift-sdk/blob/main/LICENSE). Both are fine for a commercial app.
- Requirements: Swift 6.1+ (Xcode 16.3+); macOS 13.0+, iOS 16.0+. Source: [README](https://github.com/modelcontextprotocol/swift-sdk/blob/main/README.md), [Package.swift](https://github.com/modelcontextprotocol/swift-sdk/blob/main/Package.swift).
- Dependencies: `swift-system`, `swift-log`, `eventsource`, `swift-nio` (the last for the server and conformance targets).
- **Protocol version: 2025-11-25** ("latest" in its README), also 2025-06-18, 2025-03-26, 2024-11-05. I found **no 2026-07-28 support** in the main branch ([Versioning.swift](https://github.com/modelcontextprotocol/swift-sdk/blob/main/Sources/MCP/Base/Versioning.swift)). In the specification's terms it is a *legacy* client: it works with legacy and dual-era servers and would fail against a server that speaks only 2026-07-28.
- Maturity: **Tier 3**, the lowest of the official tiers (TypeScript, Python, C#, Go, Rust, Ruby are Tier 1; Java Tier 2; Swift, PHP, Kotlin Tier 3). Version numbers are still 0.x, so the API can change. Source: [SDKs](https://modelcontextprotocol.io/docs/sdk).

What the client supports (README): tools, resources, prompts, completions, sampling, elicitation (form and URL), roots, logging, cancellation, progress.

Transports:

| Transport | Use |
|---|---|
| `StdioTransport` | A local server started as a child process. The app starts the process with `Process()` and hands its pipes to the transport |
| `HTTPClientTransport` | Remote servers over Streamable HTTP, with optional streaming |
| `InMemoryTransport` | Tests |
| `NetworkTransport` | Non-standard TCP/UDP |

The old HTTP+SSE transport is not listed as a client transport (not verified whether `HTTPClientTransport` falls back to it).

Sign-in: `HTTPClientTransport` has OAuth 2.1 built in, off by default. With an `OAuthAuthorizer` it does the discovery (RFC 9728, RFC 8414, OpenID Connect), uses a Client ID Metadata Document when the client ID is an `https` URL and the service supports it, otherwise Dynamic Client Registration, enforces PKCE, refreshes tokens, and handles `403 insufficient_scope`. The app supplies an `OAuthAuthorizationDelegate` (opens the browser, catches the redirect) and a `TokenStorage` (where tokens are kept, for example the Keychain).

#### 3.2 Other Swift options

- [Cocoanetics/SwiftMCP](https://github.com/Cocoanetics/SwiftMCP): mainly for writing *servers* in Swift with macros. 166 stars, active (November 2026), BSD-2-Clause.
- [gsabran/mcp-swift-sdk](https://github.com/gsabran/mcp-swift-sdk): archived (last push May 2025). Do not use.
- [jamesrochabrun/MCPSwiftWrapper](https://github.com/jamesrochabrun/MCPSwiftWrapper): thin wrapper, 36 stars, no push since March 2025.
- Writing a minimal client by hand: for tools only over Streamable HTTP it is small (POST a JSON-RPC body with a Bearer header, read JSON or an event stream). Sign-in is the large part.

Verdict: the official SDK is the only serious choice. Its weak points are the tier, the 0.x version and the protocol lag.

#### 3.3 Starting a local stdio server from a macOS app

A local server is an ordinary program. Most are written in TypeScript (run with Node.js) or Python.

What must be on the Mac:

- `npx <package>` needs **Node.js** installed. macOS does not ship Node.
- `uvx <package>` needs **uv** installed (it fetches Python and the packages). macOS does not ship uv.
- Both download code from a public registry at first run and run it with the user's rights.
- A compiled binary needs nothing.

(The two "does not ship" statements and the next paragraph are common knowledge about macOS, not re-verified against an Apple page for this note.)

A menu-bar app started from the Finder does not get the shell's `PATH`, so `npx` installed by Homebrew or nvm is usually not found unless the app looks for it in the usual folders or asks the user for the path.

**Sandboxed app** (Mac App Store style): a sandboxed app may run a helper tool that is embedded in its own bundle and signed to inherit the app's sandbox. Source: [Embedding a command-line tool in a sandboxed app](https://developer.apple.com/documentation/xcode/embedding-a-helper-tool-in-a-sandboxed-app) (title and summary verified; details not re-read line by line). Running the user's own Node or uv from outside the bundle, which then downloads and writes packages in the home folder, does not fit the sandbox. In practice a sandboxed app can only run servers it ships itself, and those inherit its restrictions.

**Non-sandboxed app** (Developer ID, notarized): it can start any program with `Process()`. The child runs with the user's full rights and with the app's privacy permissions context. This is how other desktop hosts work.

**MCP Bundles (`.mcpb`, formerly Desktop Extensions `.dxt`)**: a zip with a local server and a `manifest.json`, so a person installs a local server with one click. Server types: `node`, `python`, `binary`, and `uv` (manifest 0.4+). The repository also contains "the code used by Claude for macOS and Windows to load and verify MCPB bundles", in TypeScript. Latest release v2.1.2 (December 2025). Source: [modelcontextprotocol/mcpb](https://github.com/modelcontextprotocol/mcpb), [MANIFEST.md](https://github.com/modelcontextprotocol/mcpb/blob/main/MANIFEST.md). A Swift host would have to write its own loader (unzip, read the manifest, start the command) and, for `node` bundles, supply a Node runtime. Claude Desktop ships its own Node for this (not verified on a primary page).

Plain consequence: for a non-developer owner, anything that needs "install Node first" is a support problem. Remote servers need nothing installed. Local servers are only comfortable if they are compiled binaries or if the app carries the runtime.

---

### 4. `mcp-use`

Source: [mcp-use/mcp-use](https://github.com/mcp-use/mcp-use) (README and GitHub API, read 16 November 2026).

- **What it is**: "The fullstack MCP framework to develop MCP Apps for ChatGPT / Claude & MCP Servers for AI Agents." Its centre of gravity today is *building servers and MCP Apps* (tools with React views), then deploying them on the company's cloud, Manufact.
- **Languages**: TypeScript (main) and Python. No Swift.
- **Licence**: MIT.
- **Activity**: about 11,000 stars, 1,550 forks, pushed 13 November 2026, canary releases the same day. npm `mcp-use` 2.12.4 needs Node >= 22.22.2; PyPI `mcp-use` 1.7.1 needs Python >= 3.11.
- **Parts** (TypeScript packages: `server`, `client`, `agent`, `inspector`, `cli`, `tunnel`, `create-mcp-use-app`):
  - **Server**: define tools with schemas, attach views, built on the official TypeScript SDK v2, with OAuth adapters.
  - **Client** (`@mcp-use/client`): "Connect to MCP servers from Node.js, browsers, React, and sandboxes". Also a command line (`npx mcp-use client connect …`, `tools list`, `tools call`).
  - **Agent** (`@mcp-use/agent`): "Build model-powered agents on top of MCP clients". In Python, `MCPAgent` runs a multi-step loop and talks to the model through LangChain provider packages (`langchain-anthropic`, `langchain-openai`).
  - **Inspector**: a web page to try a server by hand (list tools, call them, see views); served at `/mcp/inspector` in development, also hosted.
  - Python transports: stdio, SSE, Streamable HTTP.

**Could a native Swift app use it?** Only as a separate helper process: a bundled Node or Python program that the Swift app starts and talks to over a pipe or a local socket. There is no Swift binding and no C library.

Honest judgement for this app:

- It would bring a second runtime (Node 22 is roughly 100 MB; the README's own chart puts its development install at 74 MiB), a second language to maintain, and a second process to sign, notarize, start, watch and update.
- Its agent would call the model itself, through LangChain. This app's rule is that all model calls go through one provider interface in Swift and that every action goes through one acting function. An agent loop inside a helper breaks both, unless only the *client* part is used and the loop stays in Swift. And then the helper adds little over the Swift SDK.
- It does not remove the hard parts (sign-in per vendor, deciding which tools are allowed, confirming writes).

Where it is useful anyway:

- **As a workbench, not as a part of the app.** The Inspector and the command-line client are a quick way to see what a server really offers before writing Swift: connect, list the tools, read their descriptions, try a call.
- **If the owner ever wants to publish his own server** (for example, to expose the app's memory to other AI apps), `mcp-use` is a reasonable way to build it.
- It tracks the newest protocol quickly, which the Swift SDK does not.

---

### 5. Servers for the tools the owner uses

Read from each vendor's documentation on 16 November 2026. No live connection was tested. Tool lists come from documentation, not from a real `tools/list`. "NV" means not verified on a primary source.

#### 5.1 At a glance

| Tool | Official server? | Where it runs | Can an unknown desktop app connect? | Read / write |
|---|---|---|---|---|
| Figma (remote) | Yes | `https://mcp.figma.com/mcp` | **No.** Only clients in Figma's catalog; others join a waitlist | Read and write |
| Figma (desktop) | Yes | `http://127.0.0.1:3845/mcp`, served by the Figma desktop app | Yes, it appears so (no sign-in described) | Read only (cannot write to the canvas) |
| Notion | Yes | `https://mcp.notion.com/mcp` | **Yes** (Dynamic Client Registration and Client ID Metadata Documents) | Read and write |
| Google Drive | Yes, Developer Preview | `https://drivemcp.googleapis.com/mcp/v1` | Only with the app maker's own Google Cloud OAuth client, in a project enrolled in the preview | Read, create, copy. No edit or delete |
| Gmail | Yes, Developer Preview | `https://gmailmcp.googleapis.com/mcp/v1` | Same as Drive | Read, draft, label. **No send** |
| Google Calendar | Yes, Developer Preview | `https://calendarmcp.googleapis.com/mcp/v1` | Same as Drive | Read and write |
| GitHub | Yes | `https://api.githubcopilot.com/mcp/` (and a local binary) | Yes with a personal access token; OAuth needs the app maker's own GitHub App | Read and write; read-only address exists |
| Slack | Yes | `https://mcp.slack.com/mcp` | **No.** Only directory-published or internal Slack apps; workspace admin approves | Read and write |
| Microsoft 365 | Yes (Work IQ MCP) | `https://workiq.svc.cloud.microsoft/mcp` | Only work or school tenants, own Entra app, tenant admin consent | Read; writes blocked until an admin enables them |
| Excel | **No official server** | – | – | – |
| Autodesk Fusion (desktop) | Yes | `http://127.0.0.1:27182/mcp`, inside Fusion | Yes, no sign-in | Read and write the open design |
| Autodesk Fusion (data) | Yes | Remote, address not published | Autodesk account sign-in; client rules NV | Hubs, projects, folders, items |
| Linear | Yes | `https://mcp.linear.app/mcp` | **Yes** (Dynamic Client Registration), or an API key | Read and write; read-only address exists |
| Apple Notes, Reminders, Calendar | **No Apple server** | Community, local only | – | – |
| Local files | Yes, reference server | Local stdio (`npx` or Docker) | Yes | Read and write; `--read-only` flag |

All the remote servers above use Streamable HTTP. Two of the most interesting ones for a designer and maker, Figma desktop and Fusion desktop, are **local HTTP servers on 127.0.0.1**. The Claude API connector cannot reach those (it needs a public `https://` address). A client inside the app can.

#### 5.2 Figma

Official, two servers.

**Remote.** `https://mcp.figma.com/mcp`, Streamable HTTP. Sign-in with the Figma account in the browser. Figma's page says only clients listed in the Figma MCP catalog can connect; a new client joins a waitlist, with no criteria or timeline given. Source: [Remote server installation](https://developers.figma.com/docs/figma-mcp-server/remote-server-installation/). OAuth details (PKCE, scope `mcp:connect`) come from a third-party post: NV.

- Read tools: `get_design_context`, `get_metadata`, `get_screenshot`, `get_variable_defs`, `get_figjam`, `get_libraries`, `search_design_system`, `get_code_connect_map`, `download_assets`, `whoami`.
- Write tools: `use_figma`, `create_new_file`, `generate_figma_design`, `generate_diagram`, `upload_assets`, `send_code_to_figma`, `add_code_connect_map`, `generate_image`.
- Source: [Tools and prompts](https://developers.figma.com/docs/figma-mcp-server/tools-and-prompts/).
- Limits: View and Collab seats 20 calls per month. Full and Dev seats: Professional 200 per day and 10 per minute; Organization 200 per day and 15 per minute; Enterprise 600 per day and 20 per minute. Write tools are exempt. Source: [Rate limits and access](https://developers.figma.com/docs/figma-mcp-server/rate-limits-access/).

**Desktop.** `http://127.0.0.1:3845/mcp`, served by the Figma desktop app while it runs. Needs a Dev or Full seat on a paid plan. No sign-in step is described. Read tools and Code Connect mapping only; it cannot write to the canvas. Source: [Local server installation](https://developers.figma.com/docs/figma-mcp-server/local-server-installation/).

For this app: the desktop server is reachable today, read-only. Writing into Figma through MCP needs Figma to accept the app into its catalog, or goes through a client Figma already lists.

#### 5.3 Notion

Official, hosted. `https://mcp.notion.com/mcp` (Streamable HTTP). The old `https://mcp.notion.com/sse` retires on 23 February 2027. Source: [Get started with MCP](https://developers.notion.com/docs/get-started-with-mcp).

- Sign-in: OAuth in the browser with PKCE. It supports Dynamic Client Registration and Client ID Metadata Documents, with no approval step, so any client can connect. Access token about 8 hours; refresh token up to 180 days, changed at every refresh. Source: [Build an MCP client](https://developers.notion.com/guides/mcp/build-mcp-client). Redirect rules for desktop apps are not documented (NV).
- Tools named in the docs: `notion-search`, `notion-fetch`, `notion-list-recent-pages`, `notion-list-private-pages`, `notion-query-meeting-notes`, `notion-get-users`, `notion-get-self`; plus groups for comments, creating and organising pages, databases and views, files, calendars. Source: [Supported tools](https://developers.notion.com/guides/mcp/mcp-supported-tools). Exact write tool names: NV on the docs.
- Read and write. Works on every plan; guests cannot connect.
- Limits: 180 requests per minute per connection, 600 on Business and Enterprise. Source: [Rate limits](https://developers.notion.com/guides/mcp/rate-limits).

The open-source local server [makenotion/notion-mcp-server](https://github.com/makenotion/notion-mcp-server) is no longer actively maintained; its README points to the hosted one.

Notion is the easiest first server for a Swift client.

#### 5.4 Google Drive, Gmail, Google Calendar

Google now runs its own remote servers. Status: **Developer Preview**, opened 1 May 2026. Source: [Workspace Updates blog](https://workspaceupdates.googleblog.com/2026/05/agent-tools-and-security-updates-for-workspace-developers.html), [Configure MCP servers](https://developers.google.com/workspace/guides/configure-mcp-servers). The pages show no date; whether it is still a preview today is NV.

- Sign-in: OAuth 2.0 only. No dynamic registration. Whoever connects needs their **own Google Cloud project**, must enable the product's API and its "MCP API", and create an OAuth client marked for an AI agent. For a shipped app that means the app's maker registers with Google, and Google's usual app verification for sensitive scopes applies (the verification point is general Google policy, NV for these servers).
- **Drive**: `search_files`, `list_recent_files`, `read_file_content`, `get_file_metadata`, `get_file_permissions`, `download_file_content`, `create_file`, `copy_file`. Scopes `drive.readonly`, `drive.file`. Source: [Drive MCP server](https://developers.google.com/workspace/drive/api/guides/configure-mcp-server).
- **Gmail**: `search_threads`, `get_thread`, `list_drafts`, `create_draft`, `list_labels`, `label_thread`, `label_message`, `unlabel_thread`, `unlabel_message`. There is no send tool: the person sends the draft from Gmail. Source: [Gmail MCP server](https://developers.google.com/workspace/gmail/api/guides/configure-mcp-server).
- **Calendar**: `list_calendars`, `list_events`, `get_event`, `create_event`, `update_event`, `delete_event`, `respond_to_event`, `suggest_time`. Source: [Calendar MCP server](https://developers.google.com/workspace/calendar/api/guides/configure-mcp-server).
- Cost, quotas, and whether personal gmail.com accounts work: not stated (NV).

The old community-era reference server for Drive sits in an archived repository with no security guarantees: [servers-archived](https://github.com/modelcontextprotocol/servers-archived). Do not use it.

#### 5.5 GitHub

Official: [github/github-mcp-server](https://github.com/github/github-mcp-server), MIT, release v2.1.0 on 3 November 2026.

- Remote: `https://api.githubcopilot.com/mcp/`. Read-only: `https://api.githubcopilot.com/mcp/readonly` or the header `X-MCP-Readonly`. Narrow to a group of tools with `/mcp/x/{toolset}` or `X-MCP-Toolsets`. Source: [remote-server.md](https://github.com/github/github-mcp-server/blob/main/docs/remote-server.md).
- Local: a Go binary or Docker image over stdio, with `--read-only`.
- Sign-in: a personal access token as `Authorization: Bearer` works from any client. OAuth needs the app's maker to register a GitHub App or OAuth App.
- Tool groups: `repos`, `issues`, `pull_requests`, `actions`, `discussions`, `gists`, `notifications`, `projects`, `code_security`, `users`, `orgs` and others.
- Free for all GitHub users; Copilot tools need paid Copilot. Source: [GitHub docs](https://docs.github.com/en/copilot/how-tos/provide-context/use-mcp/set-up-the-github-mcp-server).

A fine-grained, read-only personal token on the read-only address is the safe way to start.

#### 5.6 Slack

Official, remote only: `https://mcp.slack.com/mcp`, Streamable HTTP, no SSE, no Dynamic Client Registration. Source: [Slack MCP server](https://docs.slack.dev/ai/slack-mcp-server/).

- The client must be a registered Slack app. Slack's page: "Only directory-published apps or internal apps may use MCP." A workspace admin must approve it ([admin approval](https://docs.slack.dev/ai/slackbot-mcp-client/admin-approval/)).
- Does: search messages, files, users and channels; read channels and threads; send and schedule messages; create channels; reactions; canvases; lists. Scopes per tool (`search:read.*`, `chat:write`, `channels:history`, …).
- Plan needed and general-availability date: NV.

For one person's own workspace, an *internal* Slack app created in that workspace is the allowed route. For a product sold to others, the app would have to be published in Slack's directory.

#### 5.7 Microsoft 365 and Excel

Official: **Work IQ MCP**, `https://workiq.svc.cloud.microsoft/mcp`, also a local `workiq mcp` command. Source: [Work IQ quickstart](https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/work-iq/mcp/quickstart/github-copilot-cli), [tool reference](https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/work-iq/mcp/tool-reference) (11 November 2026).

- Sign-in: Microsoft Entra ID, as the signed-in user. All scopes need **tenant admin consent**, and an admin must enable Work IQ first. Source: [permissions](https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/work-iq/permissions) (30 October 2026). In practice this is for work and school accounts, not personal ones (personal accounts: NV).
- Tools are generic, over Microsoft Graph paths: `fetch`, `fetch_blob`, `create_entity`, `update_entity`, `delete_entity`, `do_action`, `call_function`, `ask`, `retrieve`, `get_schema`, `search_paths`. Writes are blocked by default until the admin allows them.
- Cost: paid in Copilot Credits; price per call NV.

**Excel**: no official Excel MCP server was found, and nothing official for Excel on the Mac. The closest official route is downloading an `.xlsx` from OneDrive or SharePoint with `fetch_blob` (4 MB by default). Community servers exist (one drives the Excel app, mostly Windows; one edits files without Excel): NV, not recommended without review.

For a single person with a personal Microsoft account, this is the weakest area. Excel on the Mac is better reached the way the app already works (the app's own scripting, or the screen).

#### 5.8 Autodesk Fusion

Official, two servers. Source: [Autodesk help, Fusion MCP overview](https://help.autodesk.com/view/fusion360/ENU/?guid=FMCP-OVERVIEW).

- **Fusion MCP Server (desktop)**: runs inside Fusion at `http://127.0.0.1:27182/mcp` (Streamable HTTP, port can be changed). Turn it on in Preferences > General > API. No sign-in. Works only while Fusion is open with a document. It creates, changes and inspects geometry, sketches and features. Source: [connecting guide](https://help.autodesk.com/cloudhelp/ENU/ADSKMCP-FusionDesktopMcp/files/ADSKMCP_FusionDesktopMcp_connecting_to_the_fusion_mcp_server_html.html).
- **Fusion Data MCP Server (cloud)**: remote, Autodesk account sign-in, for hubs, projects, folders and items. Address, plan and status not published (NV).
- Tool names are not published; they are discovered at connection time.

The desktop server is a good fit for a Swift client: local, no token, and it acts inside the app the user has open. Because it has no sign-in, any program on the Mac can use it while it is on.

#### 5.9 Linear

Official, remote only. `https://mcp.linear.app/mcp` (read and write), `https://mcp.linear.app/mcp/readonly`; `https://mcp.linear.app/sse` is deprecated. Source: [Linear MCP docs](https://linear.app/docs/mcp).

- Sign-in: OAuth 2.1 with Dynamic Client Registration, so any client can connect; or a Linear API key as a Bearer token. Read-only through the `read` scope or a read-only key.
- Does: find, create and update issues, projects and comments. The docs give no tool names (names seen in third-party catalogs: NV).
- No plan requirement found.

#### 5.10 Apple Notes, Reminders, Calendar

No Apple-official MCP server was found. Apple's WWDC 2026 macOS guide does not mention MCP (absence inferred, not every session was searched). Claims of MCP built into macOS are third-party only: NV.

Community local servers, all MIT, all stdio:

- [FradSer/mcp-server-apple-events](https://github.com/FradSer/mcp-server-apple-events): Reminders and Calendar through EventKit (a Swift helper started by Node, `npx`, Node 20+). 238 stars, active in November 2026. Has a `--require-write-confirmation` flag, off by default.
- [mattt/iMCP](https://github.com/mattt/iMCP): a macOS app that offers Messages, Contacts, Reminders and more as a server. About 1,980 stars, active, MIT (GitHub API).
- [krmj22/macos-mcp](https://github.com/krmj22/macos-mcp): adds Notes through scripting. 12 stars.
- [supermemoryai/apple-mcp](https://github.com/supermemoryai/apple-mcp): archived 1 January 2026. Do not use.

Notes has no EventKit-style access; every Notes server uses AppleScript or JXA and needs the Automation permission.

For this app none of these is needed: it already has the system's calendar and reminders access and the apps' own scripting. Calling them directly is shorter, needs no Node, and adds no third-party code.

#### 5.11 Local files

Official reference server: [@modelcontextprotocol/server-filesystem](https://github.com/modelcontextprotocol/servers/tree/main/src/filesystem), MIT, local stdio.

- Run: `npx -y @modelcontextprotocol/server-filesystem /path1 /path2` or Docker. The folders given on the command line are the only ones it may touch.
- Read tools: `read_text_file`, `read_media_file`, `read_multiple_files`, `list_directory`, `directory_tree`, `search_files`, `get_file_info`, `list_allowed_directories`.
- Write tools: `write_file`, `append_file`, `edit_file`, `create_directory`, `move_file`, `copy_file`. No delete tool is listed.
- `--read-only` registers the read tools only.

A native app does not need this: Swift reads and writes files itself, and the app's rule (new files only, never overwrite or delete) is easier to keep in its own code than in a general server that has `write_file` and `move_file`.

#### 5.12 Registries, and how far to trust a listing

**Official MCP Registry**: `https://registry.modelcontextprotocol.io`. In **preview** since 8 September 2025; the API has been frozen at v0.1 since 24 October 2025; no general-availability date found. Source: [About the registry](https://modelcontextprotocol.io/registry/about), [repository](https://github.com/modelcontextprotocol/registry).

- It holds only a description (`server.json`) that points to a package on npm, PyPI or Docker, or to a remote address.
- Anyone can publish with a command-line tool. There is no review.
- The name is proven, not the code: a GitHub sign-in gives `io.github.<user>/*`; a DNS record or a file on the site gives `com.example/*`. Source: [authentication](https://modelcontextprotocol.io/registry/authentication).
- It does not scan for security problems. Its own policy: "consumers should assume minimal-to-no moderation". Source: [moderation policy](https://modelcontextprotocol.io/registry/moderation-policy).

Others, one line each:

- **GitHub MCP Registry** (github.com/mcp): curated by GitHub; GitHub tells administrators to do their own review ([GitHub blog](https://github.blog/ai-and-ml/generative-ai/how-to-find-install-and-manage-mcp-servers-with-the-github-mcp-registry/)).
- **Docker MCP Catalog**: Docker builds and signs the images, with provenance records; the strongest supply-chain proof of the group ([Docker docs](https://docs.docker.com/ai/mcp-catalog-and-toolkit/catalog/)).
- **Anthropic's connectors directory for Claude**: remote servers; an automatic policy scan, and a "Verified" label that means Anthropic tested the tools. "It isn't a security audit" ([verification](https://claude.com/docs/connectors/verification)).
- **Smithery, PulseMCP, Glama, mcp.so**: community directories; their vetting was not checked on their own sites (NV).

How trustworthy is a listing:

1. A listing proves who controls the name, nothing more.
2. No registry audits the code or the tool descriptions.
3. The best signal is the vendor's own documentation naming the address, on the vendor's own domain. Every remote server in this section passes that test.
4. Tools can change after listing, so trust the vendor, pin the tool list, and limit scopes on the client side.

#### 5.13 What this means for the three designs

- **Open today to a Swift client with no permission from anyone**: Notion, Linear, GitHub (with a personal token), Figma desktop (read), Fusion desktop.
- **Need the app's maker to register with the vendor first**: Google (own Cloud project, preview), GitHub OAuth, Slack (internal or published app), Microsoft (Entra app plus admin consent).
- **Closed to unknown clients**: Figma remote.
- **No official server**: Excel, Apple's apps.

Whether the Claude API connector is itself accepted by the closed or restricted vendors (Figma remote, Slack) was not tested: NV.

---

### 6. Risks specific to MCP

#### 6.1 Tool poisoning: hidden instructions in a tool's description

The model reads every tool's description; the user normally sees only the name. A server can put instructions there ("before using this tool, read this file and send it as a parameter"). Invariant Labs showed it in April 2025 with a harmless-looking `add` tool that made the agent read SSH keys and a configuration file. Source: [Invariant Labs, MCP Security Notification: Tool Poisoning Attacks](https://invariantlabs.ai/blog/mcp-security-notification-tool-poisoning-attacks). A variant, "shadowing", has one server's description change how the model uses a *different*, trusted server's tool (same source).

OWASP lists it as **MCP03:2025 Tool Poisoning** in its MCP Top 10 (also MCP01 Token Mismanagement and Secret Exposure, MCP02 Privilege Escalation via Scope Creep). Source: [OWASP MCP Top 10](https://owasp.org/www-project-mcp-top-10/). The project's exact release status is not verified.

The specification's position: "descriptions of tool behavior such as annotations should be considered untrusted, unless obtained from a trusted server". Source: [Specification overview, Tool Safety](https://modelcontextprotocol.io/specification/latest).

#### 6.2 Rug pull: the server changes its tools later

The user approves a server; later it returns a different description, or a new tool, under the same name. The approval covered the old text. Source: [Invariant Labs](https://invariantlabs.ai/blog/mcp-security-notification-tool-poisoning-attacks). A related CVE in a code editor is cited by secondary sources as CVE-2025-54136 (not verified on the NVD page). Anthropic states the fact plainly ("An MCP server can change its tools at any time") and offers pinning for it ([MCP connector, Pin an MCP server's tool list](https://platform.claude.com/docs/en/agents-and-tools/mcp-connector)).

#### 6.3 Prompt injection through tool results

The tool is honest, but what it returns contains text written by someone else: an issue, an email, a web page, a shared document, a calendar invitation. The model may follow instructions in it. Invariant Labs showed it against the GitHub server: a malicious public issue made an agent copy data from a private repository into a public pull request. Source: [Invariant Labs, GitHub MCP Exploited](https://invariantlabs.ai/blog/mcp-github-vulnerability).

The general rule is the "lethal trifecta": an agent that has (1) access to private data, (2) exposure to untrusted content and (3) a way to send data out can be made to leak. Connecting several MCP servers often creates all three at once. Source: [Simon Willison, The lethal trifecta for AI agents](https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/).

#### 6.4 Confused deputy and token theft

From the specification's own security page, [Security Best Practices](https://modelcontextprotocol.io/docs/tutorials/security/security_best_practices):

- **Confused deputy**: an MCP server that sits in front of another service with one fixed client ID can be tricked into handing an attacker an authorization the user gave earlier. This is a server-side fault; the client's defence is to check `iss` and use PKCE.
- **Token passthrough**: a server that accepts tokens not issued for it. Forbidden by the specification.
- **Localhost redirect impersonation** and **mix-up attacks**: another program on the Mac, or a second sign-in service, catches the authorization code. Defences: PKCE, exact redirect matching, the `iss` check.
- **Token theft**: a stolen token works until it expires. With the API connector, the token also passes through Anthropic on every request (section 2.6).

#### 6.5 Over-broad scopes

"An attacker obtains … an access token carrying broad scopes (`files:*`, `db:*`, `admin:*`) that were granted up front because the MCP server exposed every scope in `scopes_supported` and the client requested them all." The page's remedy is a small first scope set and step-up requests for more. Source: [Security Best Practices, Scope Minimization](https://modelcontextprotocol.io/docs/tutorials/security/security_best_practices).

#### 6.6 Local servers run with the user's full rights

"Local MCP servers are binaries that are downloaded and executed on the same machine as the MCP client." Risks listed: arbitrary code execution, no visibility, data exfiltration, data loss. A startup command such as `npx some-package` runs whatever that package contains today. A server left listening on localhost can be reached from a web page by DNS rebinding. Source: [Security Best Practices, Local MCP Server Compromise](https://modelcontextprotocol.io/docs/tutorials/security/security_best_practices).

The page's requirements for a client that installs local servers: show the exact command in full, mark it as dangerous, require explicit approval; and it recommends running servers sandboxed with restricted file and network access.

#### 6.7 What people actually do about it

| Mitigation | What it stops | Where it comes from |
|---|---|---|
| **Pin tool definitions** (store the approved name, description and schema, or a hash; stop and ask if they change) | Rug pulls | Anthropic's `mcp-client-2026-09-15` pinning; Invariant's scanner does the same |
| **Allowlist tools per server**, off by default | Unneeded and destructive tools; fewer tokens | [MCP connector](https://platform.claude.com/docs/en/agents-and-tools/mcp-connector) allowlist pattern |
| **Read-only by default; confirm each write** | Injection turning into action | Specification: "there SHOULD always be a human in the loop with the ability to deny tool invocations"; clients should "show tool inputs to the user before calling the server" ([Tools](https://modelcontextprotocol.io/specification/2026-07-28/server/tools)) |
| **Smallest scopes, step-up later; read-only tokens where the vendor offers them** | Stolen or misused tokens | [Scope Minimization](https://modelcontextprotocol.io/docs/tutorials/security/security_best_practices) |
| **Treat tool results as data, never instructions**; do not let one turn mix private data, untrusted text and an outward-sending tool | Injection through results | [Lethal trifecta](https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/) |
| **Only servers run by the vendor of the tool itself**; fixed list, no "paste any URL" | Malicious servers | Anthropic: "Users should only connect to remote MCP servers they trust" ([Remote MCP servers](https://platform.claude.com/docs/en/agents-and-tools/remote-mcp-servers)) |
| **Prefix tool names with the server**, keep servers separate | Shadowing and name collisions | [Tools, Tool Names](https://modelcontextprotocol.io/specification/2026-07-28/server/tools) |
| **Tokens in the Keychain, per server, keyed by issuer** | Token theft and mix-up | [Client Registration, Authorization Server Binding](https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization/client-registration) |
| **For local servers: pinned versions, show the full command, sandbox** | Supply-chain code | [Local MCP Server Compromise](https://modelcontextprotocol.io/docs/tutorials/security/security_best_practices) |
| **Timeouts, and a log of tool use** | Hung calls; later audit | [Tools, Security Considerations](https://modelcontextprotocol.io/specification/2026-07-28/server/tools) |

One point from Invariant worth keeping: sandboxing a server does **not** stop tool poisoning, because the attack works through the model following text, not through the server's code.

---

### 7. Three designs compared for this app

(a) The API's connector for remote servers. (b) An MCP client in Swift inside the app. (c) A bundled helper process in Node or Python, where `mcp-use` would sit.

| | (a) API connector | (b) Swift client in the app | (c) Bundled Node/Python helper |
|---|---|---|---|
| **Work to build** | Small for the calls: two JSON fields and a beta header, parse three new block types. **Not small overall**: the app still does the whole OAuth sign-in and token refresh itself | Medium: add the official Swift SDK, a sign-in delegate, Keychain token storage, a converter from MCP tools to Claude tools, the tool loop | Large: ship and sign a second runtime (about 100 MB), a protocol between app and helper, start/stop/crash handling, updates. Two languages |
| **What it can reach** | Remote servers on the public internet only, tools only. No local programs, no resources, no prompts | Remote servers (Streamable HTTP) and local stdio servers; tools, resources, prompts, elicitation. Today only servers that still accept protocol 2025-11-25 | Everything, including the newest protocol and the old SSE transport |
| **What data passes through whom** | Anthropic connects to the vendor. Tool definitions and results pass through Anthropic and are kept under its standard retention; **not ZDR-eligible** | The Mac talks to the vendor directly. Results reach Anthropic only as tool results in the normal API call, which the app can filter first (its secrets filter can run on them) | Same as (b), plus a second process on the Mac that holds the data in memory |
| **Where tokens live** | In the app's Keychain, **and sent to Anthropic in every request** | In the Keychain only; sent only to the vendor | In the helper's memory; the Keychain needs a bridge from Swift, or the helper stores them itself |
| **Cost per call** | Tokens only: tool definitions on every request (cacheable, pinnable, deferrable) plus results. No connector fee listed | The same tokens. The app chooses exactly which tools and how much of each result to send, so usually fewer | Same as (b). If `mcp-use`'s agent drives the model, token use is outside the app's control and cost log |
| **Control before a write** | **None per call.** Only allowlist/denylist. The tool has already run when the app sees the block | **Full.** The app's own code sees each call before it runs: it can block, ask for one confirm, log it | Full only if the loop stays in Swift and the helper is a plain client. Lost if the helper runs the agent |
| **Failure modes** | Beta: header and shapes may change. A slow or failing server stalls the whole model response. The app cannot retry one tool. Vendor may refuse Anthropic's servers or require an approved client | SDK is Tier 3, version 0.x, one protocol version behind; a vendor moving to 2026-07-28 only would break it until the SDK catches up. OAuth differences per vendor | Helper crashes, port or pipe problems, runtime security updates, notarization of bundled binaries, the Finder `PATH` problem if not bundled |
| **Fits the app's rules** | Partly. "Phew's own code decides, never the model" and "every action is listed on the card" cannot be kept for writes | Yes. One acting function, per-action log, stop within a second, confirm before what cannot be undone | Poorly. A second place that can act |

#### Recommendation

**Build (b), the Swift client, and use it for remote servers first.**

Reasons, in order of weight:

1. **Control.** The app's rules say its own code, not the model, decides what may be done, that every action is listed, and that anything that cannot be undone or that leaves the Mac waits for one confirm. Only a client inside the app sees a tool call *before* it runs. The connector runs it on Anthropic's side.
2. **Privacy.** With (b) the sign-in tokens stay in the Keychain and go only to the vendor, and the app can run its secrets filter on tool results before any model call. With (a) tokens and results pass through Anthropic and are not ZDR-eligible.
3. **No saving on the hard part.** The connector does not do the sign-in. The OAuth work is the same in (a) and (b), and the Swift SDK already contains it.
4. **Reach.** (b) can later add local servers and resources. (a) never can. This is not theoretical: the Figma desktop server (`http://127.0.0.1:3845/mcp`) and the Fusion desktop server (`http://127.0.0.1:27182/mcp`) are local addresses that only a client on the Mac can reach.

A sensible order to add servers, from section 5: Notion and Linear first (open sign-in, no registration with the vendor), then GitHub with a read-only personal token, then the Fusion and Figma desktop servers. Google, Slack and Microsoft each need the app's maker to register with the vendor before anything works.

How to keep (b) small and safe:

- A **fixed list** of servers run by the tool's own vendor (section 5), each added one at a time. No free "add any server" field in the first version.
- **Remote servers only at first.** They need nothing installed on the Mac. Leave local stdio servers for later, and then prefer compiled binaries over `npx`/`uvx`.
- For Apple's own apps (Calendar, Reminders, Notes) **do not use MCP**: the app already has the system's calendar and reminders access and the apps' own scripting, which are more direct and need no third-party code.
- **Pin** each server's tool list when the user connects it; if it changes, stop and show the change.
- **Allowlist** tools per server. Mark each as read or write in the app's own table (do not trust the server's annotations). Reads run freely; writes go through the one acting function and its confirm rule.
- Tool results are **data, never instructions**, the same rule the app already applies to web pages and pasted text.
- Tokens in the Keychain, one entry per server, smallest scopes.

Two things to check before committing (each is a short test, not research):

1. For every vendor on the list: does its server accept a client speaking protocol **2025-11-25**, and does its sign-in accept an **unknown desktop client** (through a Client ID Metadata Document or Dynamic Client Registration)? Section 5 says what is known. This decides whether (b) works for that vendor at all.
2. Whether the Swift SDK's `HTTPClientTransport` works inside a non-activating menu-bar app's sign-in flow (browser out, loopback redirect back) without taking focus in a way the app's rules forbid. The rules already allow bringing another app forward for a job the user asked for; a browser sign-in is a similar, one-time case, but it is the owner's decision.

**(a) is a reasonable second route, not the main one**: for a read-only server where the vendor only accepts approved clients and Anthropic's connector is one of them, or as a quick experiment to see whether a server is useful before writing Swift for it. If used, send `mcp-client-2026-09-15`, pin the tool list, and allowlist read-only tools.

**(c) is not recommended.** It costs the most, adds a second place that can act, and gives nothing (b) cannot give except the newest protocol version a few months earlier. Keep `mcp-use`'s Inspector as a workbench on the developer side only.

---

### Not verified, in one place

- Whether the MCP connector works with `stream: true` (not stated on its page).
- Whether the connector has a maximum number of servers per request.
- Whether descriptions of disabled tools still count as input tokens.
- Whether the Swift SDK's HTTP client falls back to the old HTTP+SSE transport.
- That Claude Desktop ships its own Node runtime for `.mcpb` bundles.
- The details of App Sandbox rules for child processes (only the Apple page's title and summary were checked).
- CVE-2025-54136 as the identifier for the rug-pull case; the OWASP MCP Top 10's release status.
- Section 5 lists its own unverified points per vendor.


---

## 18.3 Research note: other doors, and agents that start agents

## Ways to act on a Mac beyond MCP, and agents that start agents

Research note, 16 November 2026. Read-only research; nothing in the project was changed.

How to read the source marks:

- **[checked]** means the page was opened during this research, on 16 November 2026.
- **[bundled]** means the fact comes from Anthropic's own Claude API reference that ships with Claude Code (cached 3 November 2026), with the public page it points to. Not opened on the web this session.
- **[not re-checked]** means the fact is long-standing and comes from memory; the link is where to confirm it.
- **[unverified]** means I could not confirm it from a primary source. Treat as a lead, not a fact.

Current system: macOS 27 "Golden Gate", released 14 September 2026 ([9to5Mac, 14 Sep 2026](https://9to5mac.com/2026/09/14/macos-27-golden-gate-now-available-here-is-everything-new/), secondary source). Current models used by the app: `claude-sonnet-5-5` ($2 in / $10 out per million tokens, cache reads $0.10) and `claude-haiku-5-5` ($0.10 in / $0.50 out, for prompts up to 100K tokens) [bundled, [pricing page](https://platform.claude.com/docs/en/about-claude/pricing)].

---

### Part A. Ways to act on a Mac other than MCP and other than clicking

#### A.0 Summary table

| Way | Reaches | User must grant | Reliability | From Swift | Main risk |
|---|---|---|---|---|---|
| Shortcuts (run a shortcut the user made) | Anything a shortcut can do, including other apps' App Intents | Nothing new for running; each shortcut's own permissions | High for what the shortcut does; you cannot build shortcuts for the user | `Process` with `/usr/bin/shortcuts run`, or `shortcuts://` URL, or Apple Events to "Shortcuts Events" | Runs whatever the shortcut contains; the URL route brings Shortcuts to the front |
| App Intents (other apps' actions, directly) | Not open to third-party apps. Only Siri, Spotlight, Shortcuts, widgets call them | n/a | n/a | No public API | n/a |
| AppleScript / JXA / Apple Events | Scriptable apps: Finder, Mail, Calendar, Notes, Reminders, Safari, Music, Keynote, Pages, Numbers, Microsoft Office, Chrome, OmniFocus, Things and others | "Automation" permission, one prompt per target app | High where a dictionary exists; uneven depth per app | `NSAppleScript`, `NSUserAppleScriptTask`, `NSAppleEventDescriptor` | Full power inside the target app (delete mail, send mail) |
| URL schemes, x-callback-url | Apps that publish a scheme (Shortcuts, Things, Bear, Drafts, Obsidian, OmniFocus) | None | Medium: one-way unless x-callback is supported | `NSWorkspace.shared.open(url)` | Usually brings the app to the front; no proof it worked |
| The apps' own web APIs with OAuth | Cloud data of Google, Microsoft, Notion, Slack, GitHub, Linear and others | A sign-in per service, with scopes | High, versioned, rate-limited | `ASWebAuthenticationSession` + `URLSession`; tokens in Keychain | Data leaves and enters by the network; wide scopes; token storage |
| Command-line tools shipped by apps | `shortcuts`, `osascript`, `open`, `mdfind`, `defaults`; `gh`, `git`, `code`, `op` if installed | None beyond what the tool needs | High, text in and out | `Process` | A shell is a wide door; must be a fixed list, never free text |
| Browser automation (WebDriver, CDP, extension) | Web pages, the DOM, forms | Safari: "Allow remote automation". Chrome: a separate profile since Chrome 136. Extension: install plus site access | High on the DOM; no access to the user's signed-in session unless via extension | `safaridriver` over HTTP; WebSocket to Chrome | Signed-in sessions, cookies, prompt injection from page text |
| Claude API computer use tool | Any app on screen, by screenshot and synthetic input | Screen Recording + Accessibility (already held) | Lower and slower than a structured route; improves each model | Messages API; the app runs each action | Acts on what it sees; injection through screen content |
| Claude API browser use tool | A browser viewport: pages, elements, forms, tabs | A browser the app controls | Better than screenshots for web tasks | Messages API; the app runs each action | Same as browser automation |
| Claude API code execution tool | A sandbox on Anthropic's servers. Nothing on the Mac | Nothing | High | Messages API | Whatever is sent into it leaves the Mac |
| Agent Skills | Instructions and scripts loaded only when needed, inside that same sandbox | Nothing | High | Messages API with `container.skills` | Not covered by zero data retention; a skill is like installed software |

#### A.1 App Intents and the Shortcuts app

**What it is.** App Intents is Apple's framework by which an app declares its actions ("intents") and its content ("entities") to the system. Shortcuts, Spotlight, Siri and widgets can then run them.

**What macOS 27 added** ([What's new in macOS 27](https://developer.apple.com/macos/whats-new/) [checked]; [Apple Newsroom, 8 June 2026](https://www.apple.com/newsroom/2026/06/apple-aids-app-development-with-new-intelligence-frameworks-and-advanced-tools/) [checked]; [WWDC26 session 240, "Build intelligent Siri experiences with App Schemas"](https://developer.apple.com/videos/play/wwdc2026/240/) [checked]):

- **App Schemas.** Predefined definitions that Siri understands. An entity conforms with `@AppEntity(schema: .messages.message)`; intents conform to schemas such as `sendMessage` and `draftMessage` in the Messages domain. Apple calls the domains "categories of contracts" between an app and Siri.
- **Entity schemas** put an app's content into the Spotlight semantic index, so Siri can surface it with attribution.
- **Intent schemas** let people act in natural language without the developer defining phrases.
- **On-screen awareness.** Two APIs: `NSUserActivity` for the one main item on screen, and the **View Annotations API** (`.appEntityIdentifier(EntityIdentifier(for:identifier:))`) for several visible items such as rows of a list.
- **App Intents Testing framework**, to test integrations without UI automation.
- **Foundation Models framework** is now one Swift API that can drive Apple's on-device model, Apple's server models, or "cloud models like Claude and Gemini" through a Language Model protocol. This is a way to *call a model*, not a way to act in other apps.
- Xcode 27 accepts MCP tools and any agent that speaks the **Agent Client Protocol (ACP)**. That is for coding in Xcode, not for apps at run time.

**The key finding: all of this points one way.** An app *exposes* its own actions and content *to Siri*. None of the three Apple pages above describes an API by which a third-party app can list or call another app's intents, read another app's annotated on-screen entities, or register as a system assistant. Both Apple pages were checked for this and say nothing of the kind. The older term "assistant schemas" (`AssistantSchemaIntent`, from the 2024 releases) does not appear in the 2026 material; "App Schemas" is the current name. [The exact relation between the two names is unverified.]

Developer-forum reports (anecdotal, not Apple statements) say on-screen awareness is limited to the front app's own content, and that custom intents exposed as Siri tools were not reliably called in a 27.3 beta ([Apple Developer Forums, App Intents tag](https://developer.apple.com/forums/tags/app-intents)) [unverified].

**So the only door for a third-party app is Shortcuts.** A shortcut can contain any app's intents. An outside app can *run* a shortcut that already exists. It cannot create one silently.

Three ways to run a shortcut:

1. **Command line.** `/usr/bin/shortcuts` with subcommands `run`, `list`, `view`, `sign`. `run` takes `-i/--input-path`, `-o/--output-path`, `--output-type`. Apple's guide is written for macOS 27 ([Run shortcuts from the command line](https://support.apple.com/guide/shortcuts-mac/run-shortcuts-from-the-command-line-apd455c82f02/mac)) [checked]. From Swift: `Process`. `shortcuts list` gives the app the user's shortcut names, which it can offer to the model as tools.
2. **URL scheme.** `shortcuts://run-shortcut?name=...&input=text&text=...` ([Run a shortcut using a URL scheme](https://support.apple.com/guide/shortcuts-mac/run-a-shortcut-from-a-url-apd624386f42/mac)), with `x-success`, `x-cancel`, `x-error` callbacks; on success a `result` parameter carries the text output ([Use x-callback-url with Shortcuts](https://support.apple.com/guide/shortcuts-mac/use-x-callback-url-apdcd7f20a6f/mac)) [checked via search summary]. A forum report says this route brings the Shortcuts app to the front ([thread 728047](https://developer.apple.com/forums/thread/728047)) [unverified on macOS 27].
3. **Apple Events.** `tell application "Shortcuts Events" to run the shortcut named "..."` ([WWDC21, Meet Shortcuts for macOS](https://developer.apple.com/videos/play/wwdc2021/10232/)). Runs in the background without opening the Shortcuts app.

**Grants.** Running needs nothing new. A shortcut asks for its own permissions the first time. Route 3 needs the Automation permission for "Shortcuts Events".

**Reliability.** As good as the shortcut. Output is text or a file. Errors come back as an exit code or the `x-error` callback.

**Risk.** A shortcut can do anything, including sending and deleting. The app cannot see inside it before running. Treat each shortcut as "cannot be undone" unless the user marks it safe.

**Worth doing in the other direction too.** If this app declares its own App Intents ("Ask about this window", "Start a research task"), Siri, Spotlight and Shortcuts can call *it*. That costs little and fits the current macOS.

#### A.2 AppleScript, JXA and Apple Events

**What it is.** The oldest and still the deepest way for one Mac app to command another. AppleScript and JavaScript for Automation (JXA) are two languages over the same Apple Events.

**What it reaches** [not re-checked; each app's dictionary is visible in Script Editor, File > Open Dictionary]:

- Apple: Finder, System Events, Mail, Calendar, Contacts, Notes, Reminders, Messages (send only), Safari (tabs, URL, run JavaScript in a page if the user turns on "Allow JavaScript from Apple Events"), Music, TV, Photos, Preview (thin), Keynote, Pages, Numbers, Terminal, Shortcuts Events.
- Third party: Microsoft Word, Excel, PowerPoint, Outlook (classic); Google Chrome and other Chromium browsers (tabs, URL, run JavaScript with the same kind of user switch); OmniFocus, OmniGraffle, Things, BBEdit, DEVONthink, Fantastical, Adobe Photoshop, Illustrator, InDesign.
- **Not scriptable or barely:** most Electron apps (Slack, Notion, Discord, Figma, VS Code, Linear), most Catalyst and SwiftUI-only apps, the new Outlook. For these the routes are the web API, a URL scheme, or the accessibility tree.

**Grants.** macOS shows one prompt per target app ("X wants to control Y") the first time. The app must carry `NSAppleEventsUsageDescription` ([Apple](https://developer.apple.com/documentation/bundleresources/information-property-list/nsappleeventsusagedescription)) and, with the hardened runtime, the `com.apple.security.automation.apple-events` entitlement ([Apple](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.automation.apple-events)) [not re-checked].

**From Swift.** `NSAppleScript` for a script string; `NSUserAppleScriptTask` for a script file run outside the sandbox; `NSAppleEventDescriptor` to build events directly; `osascript -l JavaScript` for JXA. The app already does this.

**Reliability.** High where the dictionary covers the action. It does not take the screen and does not need the app in front. JXA has had no real updates for years and has known gaps; AppleScript is the safer of the two [not re-checked].

**Risk.** A script has the full power of the target app. Model-written scripts must not be run as free text. Keep a fixed set of script templates with typed parameters, and let the app's own code decide the never-act list, as the project rules already require.

#### A.3 URL schemes and x-callback-url

**What it is.** An app registers a scheme (`things:///add?title=...`, `obsidian://open?vault=...`, `bear://x-callback-url/create?...`). Another app opens the URL and the target acts. x-callback-url is a community convention that adds `x-success`, `x-error`, `x-cancel` return addresses ([x-callback-url.com](https://x-callback-url.com/)) [not re-checked].

**Reach.** Apps that publish a scheme: Shortcuts, Things, Bear, Drafts, Obsidian, OmniFocus, Fantastical, Mail (`mailto:`), Maps, FaceTime, Messages (`sms:`), System Settings panes. Each app documents its own.

**Grants.** None.

**From Swift.** `NSWorkspace.shared.open(url, configuration:)`. To receive the callback the app registers its own scheme.

**Reliability.** Medium. Without a callback there is no proof the action happened. Many schemes only *open a draft* rather than complete the act, which is in fact a safe default.

**Risk.** Usually activates the target app, which conflicts with "never takes focus" unless the job needs that app. `NSWorkspace.OpenConfiguration.activates = false` helps but apps may ignore it [not re-checked].

#### A.4 The apps' own web APIs with OAuth

**What it is.** Calling Google (Gmail, Calendar, Drive), Microsoft Graph, Notion, Slack, GitHub, Linear, Todoist directly over HTTPS with a token the user grants.

**Grants.** One sign-in per service with a list of scopes. From Swift: `ASWebAuthenticationSession` for the sign-in, `URLSession` for calls, tokens in the Keychain.

**Reliability.** The highest of all routes: versioned, documented, works with the app closed.

**Cost and risk.** Each service is its own integration and needs a registered OAuth client (Google and Microsoft require app verification for sensitive scopes). It breaks the current rule "calls only the Claude API", since the Mac would talk to other servers. This is the same ground the MCP connectors cover, so it is left to the other researcher.

#### A.5 Command-line tools shipped by apps

**What it is.** Many apps install a command: `shortcuts`, `osascript`, `open`, `mdfind` (Spotlight search), `mdls`, `pbcopy`/`pbpaste`, `qlmanage`, `textutil`, `sips`, `screencapture` from Apple; `gh`, `git`, `code`, `op` (1Password), `obsidian`, `raycast` from others.

**From Swift.** `Process` with a full path and an argument array (never a shell string).

**Grants.** None, beyond the files the tool touches (Files and Folders prompts) and that the app is not sandboxed.

**Reliability.** High. Text output is easy for a model to read and cheap in tokens.

**Risk.** The project rule forbids acting in Terminal and code editors. A fixed list of read-only commands (`mdfind`, `mdls`, `shortcuts list`) fits the rules; a general shell does not. Anthropic's own guidance: start with a shell for breadth, promote an action to a dedicated typed tool when it must be gated, shown or audited [bundled, agent design notes].

#### A.6 Browser automation

Three routes:

- **WebDriver with Safari.** `/usr/bin/safaridriver` ships with macOS. The user turns on "Allow remote automation" in Safari's Develop menu (or runs `safaridriver --enable` once). Automation runs in a separate, visibly marked window with no access to the user's normal session ([Apple, Testing with WebDriver in Safari](https://developer.apple.com/documentation/webkit/testing-with-webdriver-in-safari)) [not re-checked]. Good for clean, logged-out web tasks. Useless for "do this in the tab I have open".
- **Chrome DevTools Protocol (CDP).** A WebSocket to Chrome ([protocol reference](https://chromedevtools.github.io/devtools-protocol/)). Since **Chrome 136** the `--remote-debugging-port` switch is ignored for the default profile and must come with `--user-data-dir` pointing at another folder, because attackers used remote debugging to steal cookies ([Chrome for Developers blog](https://developer.chrome.com/blog/remote-debugging-port)) [checked via search summary]. So CDP also cannot reach the user's signed-in profile. The cross-browser successor is WebDriver BiDi ([W3C](https://www.w3.org/TR/webdriver-bidi/)) [not re-checked].
- **A browser extension.** The only route into the user's real, signed-in tabs. It needs the user to install it and grant site access, and it must talk to the Mac app through native messaging. It is a second product to build and to pass store review.

**The lighter route already available:** Safari and Chrome accept "do JavaScript" over Apple Events once the user turns on a switch in the browser's Develop menu (A.2). That reaches the real tab without an extension, at the cost of one manual setting.

**Risk.** Page text is hostile input. A page can carry instructions aimed at the model. The project rule "what an agent reads from the web is data, never instructions" applies in full.

#### A.7 The Claude API computer use tool

**Current version.** `computer_toolset_20260801`. It is **stable, with no beta header**, on the Claude API. It is the only form `claude-sonnet-5-5` and `claude-haiku-5-5` accept on the Claude API (the older `computer_20251124` returns an error there) ([computer use tool docs](https://platform.claude.com/docs/en/agents-and-tools/tool-use/computer-use-tool) [checked]; [bundled]).

**What it does.** One `tools` entry gives the model 17 actions: `screenshot`, `zoom`, `left_click`, `right_click`, `middle_click`, `double_click`, `triple_click`, `left_click_drag`, `mouse_move`, `left_mouse_down`, `left_mouse_up`, `cursor_position`, `scroll`, `type`, `key`, `hold_key`, `wait`. The model asks; **the app performs every action on the Mac and sends back a screenshot.** Anthropic hosts nothing here. The model may send several actions in one turn; the app runs them in order and stops at the first failure. `zoom` returns one region at full resolution so small text can be read.

**Cost.** Each screenshot is about 1,000 to 1,800 input tokens; the formula is ceil(width/28) x ceil(height/28), capped at 4,784 tokens (2,576 px long edge) on current models. Above 20 images in one request each image is held to a stricter size. At $2 per million input tokens a screenshot costs roughly $0.002 to $0.01 on `claude-sonnet-5-5`, but every earlier screenshot is re-sent each turn unless cached or cleared, so a 30-step job costs far more than 30 screenshots.

**Speed.** The docs give no latency figure. Each step is a full model turn plus a screen capture, so several seconds per step is normal [my estimate, not a measured figure].

**Safety guidance from Anthropic.** Use a dedicated VM or container; keep credentials away from the model; allow-list domains; ask a human before consequential actions; tell end users the risks and get consent. Classifiers scan returned screenshots for injected instructions. The reference setup is a Linux Docker container, not a user's own Mac.

**Compared with reading the Accessibility tree** (what the app does today):

| | Accessibility tree | Computer use (screenshots) |
|---|---|---|
| Input cost | Text; small | 1,000 to 1,800 tokens per look |
| Precision | Exact element, role, label | Pixel coordinates; can miss |
| Speed | Fast | A model turn per step |
| Secure fields | Detectable, so code can refuse | Only visible as pixels |
| Works when | The app exposes a good tree | Always, including canvas apps, games, remote desktops, bad Electron trees |
| Takes the screen | Often not (press actions) | Yes: needs the app in front and moves the pointer |

Outside evidence points to a hybrid: tree first, pixels as a fallback. Microsoft's "Hybrid Computer Use" project reports higher scores and lower cost than screenshot-only on OSWorld 2.0 with model and harness held fixed ([project page](https://microsoft.github.io/Hybrid-Computer-Use/)) [unverified: self-reported, seen only through a search summary].

**Verdict for this app.** Keep the Accessibility tree as the main hand. Computer use is a fallback for windows whose tree is empty. It cannot work in the background, so it is for foreground jobs only.

#### A.8 The Claude API browser use tool

`browser_toolset_20260801`, launched 19 August 2026. One entry gives 27 actions by default (`navigate`, `read_page`, `left_click`, `screenshot` and others), plus four optional ones that are off until enabled (`javascript_exec`, `file_upload`, `read_console`, `read_network`). It reads the page's accessibility tree, elements, forms and tabs rather than only pixels. Like computer use, **the app runs every call against its own browser; nothing runs at Anthropic.** It cannot be called from code execution and is not available in Managed Agents ([browser use tool docs](https://platform.claude.com/docs/en/agents-and-tools/tool-use/browser-use-tool)) [checked via search summary only]. Anthropic's computer use page calls it "the closer fit for tasks that stay inside webpages".

For a Swift app this means building the handlers itself (over `safaridriver`, CDP, or a `WKWebView` the app owns). The SDK helper classes exist only for Python and TypeScript.

#### A.9 Code execution as a tool

**What it is.** A server tool: `{"type": "code_execution_20260521", "name": "code_execution"}`. The model writes Python or shell commands and Anthropic runs them.

**Where it runs.** In an isolated container on Anthropic's servers: 1 CPU, 5 GiB RAM, 5 GiB disk, Python 3.11 with pandas, numpy, matplotlib, pypdf, python-docx, python-pptx, openpyxl and others. **No internet access.** A container can be reused across requests by its ID and expires 30 days after creation [bundled, [code execution tool docs](https://platform.claude.com/docs/en/agents-and-tools/tool-use/code-execution-tool)].

**What it can touch.** Only what the request sends in: text, and files uploaded through the Files API. **It cannot touch the Mac.** Files it makes come back as file IDs to download.

**Cost.** Free when used together with the web search or web fetch tools; otherwise $0.05 per hour after 1,550 free hours per month per organization [bundled].

**Use for this app.** Data work and charts inside a research report; building a formatted PDF, Word or Excel file on the server side. Anything sent there has left the Mac and is kept up to 30 days, so screen captures and Map facts must not go in.

**A local alternative exists.** Anthropic documents "client-side direct execution": give the model a code tool and run its code yourself ([programmatic tool calling docs](https://platform.claude.com/docs/en/agents-and-tools/tool-use/programmatic-tool-calling)) [checked]. On a user's Mac that means running model-written code locally, which the project rules do not allow today.

#### A.10 Files and Agent Skills

**Files API.** Upload once with `POST /v1/files`, then refer to the `file_id` in later requests. Out of beta, no beta header [bundled, [files docs](https://platform.claude.com/docs/en/build-with-claude/files)]. Uploaded files are stored at Anthropic.

**What an Agent Skill is** ([Agent Skills overview](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview)) [checked]. A folder with a `SKILL.md` file (YAML front matter with `name`, max 64 characters, and `description`, max 1,024 characters) plus optional extra Markdown files and scripts. It packages how to do one kind of job.

**How it loads only when needed** ("progressive disclosure"):

| Level | Loaded | Token cost |
|---|---|---|
| 1. Name and description | Always, in the system prompt | about 100 tokens per skill |
| 2. The body of `SKILL.md` | When the model decides the task matches | under 5,000 tokens |
| 3. Extra files and scripts | Only when read or run | none until used; a script's code never enters context, only its output |

**Can a plain Messages API caller use them? Yes, with two conditions.** List the skills in the request's `container` parameter and include the code execution tool, because skills live and run in that server container. Anthropic's ready-made skills are `pptx`, `xlsx`, `docx`, `pdf`. Custom skills are uploaded through `/v1/skills`. Status: stable. The Skills API itself needs no beta header [bundled].

**Limits on the API.** No network access and no installing packages inside the container. Skills are **not eligible for zero data retention**. Custom skills are shared across the whole workspace.

**For this app.** Two separate ideas:

1. *Server-side skills* give a formatted PDF report with no local PDF code, at the price of the report text passing through the server container.
2. *The pattern* is the more useful part, and it needs no server: keep a short list of "how to do X in app Y" notes on the Mac, put only their one-line descriptions in the prompt, and load the full note when the model asks for it through an ordinary tool. That is progressive disclosure done locally. The Agent Skills format is now an open project under the Agentic AI Foundation (22 October 2026; [Linux Foundation press release](https://www.linuxfoundation.org/press/agentic-ai-foundation-announces-four-new-projects-agent-skills-open-responses-openenv-and-opensandbox)) [checked via search summary], so the folder format is a safe one to copy.

---

### Part B. Agents that start agents

#### B.1 The orchestrator and worker pattern, and what the labs measured

**The pattern.** One lead agent reads the request, splits it, starts several workers, each with its own fresh context and its own tools, then combines their reports. Anthropic named it "orchestrator-workers" in [Building effective agents](https://www.anthropic.com/engineering/building-effective-agents) (December 2024) [not re-checked].

**Anthropic's measured numbers** ([How we built our multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system), 13 June 2025) [checked]:

- An agent uses about **4x** the tokens of a chat. A multi-agent system uses about **15x** the tokens of a chat. So multi-agent is roughly **4x a single agent** on this measure.
- A lead on Claude Opus 4 with Claude Sonnet 4 workers beat a single Opus 4 agent by **90.2%** on Anthropic's internal research test.
- Token use alone explained **80%** of the difference in results on the BrowseComp test. In plain words: much of the gain comes from spending more tokens, in parallel.
- Parallel work cut research time by **up to 90%** on complex queries.
- Scaling rules they gave the lead: a simple fact needs 1 agent and 3 to 10 tool calls; a comparison needs 2 to 4 workers with 10 to 15 calls each; complex research needs more than 10 workers.
- Poor fit: "domains that require all agents to share the same context or involve many dependencies between agents are not a good fit for multi-agent systems today". Most coding tasks are in this group.

**Anthropic's later guidance moves toward fewer agents:**

- [When to use multi-agent systems (and when not to)](https://claude.com/blog/building-multi-agent-systems-when-and-how-to-use-them), 23 January 2026 [checked]. Multi-agent builds "typically use **3-10x more tokens** than single-agent approaches for equivalent tasks". Three cases where they win: protecting the lead's context from bulky side work, running independent searches in parallel, and specialization when one agent has 20 or more tools. "The primary benefit of parallelization is thoroughness, not speed." Splitting by role (planner, builder, tester, reviewer) creates a "telephone game"; in one experiment the workers "spent more tokens on coordination than on actual work".
- [Building agents: when to fold subagents into your main agent loop](https://claude.com/resources/articles/building-agents-when-to-fold-subagents-into-your-main-agent-loop), 22 October 2026 [checked]. The newest piece. Across several company deployments, "a single agent with skills" often beat both a one-prompt design and a subagent design on quality, often at lower cost and delay. One customer saw "roughly 2x faster runtime" with the single loop. Keep a subagent only when the single loop measurably degrades from context bloat, when tasks need parallel fresh contexts, or when the agent cannot choose among its tools.

**Outside Anthropic:**

- Cognition, [Don't build multi-agents](https://cognition.com/blog/dont-build-multi-agents), Walden Yan, 12 June 2025 [checked]. Two principles: "Share context, and share full agent traces, not just individual messages" and "Actions carry implicit decisions, and conflicting decisions carry bad results". Workers that cannot see each other make clashing assumptions.
- Google Research and DeepMind, [Towards a science of scaling agent systems](https://research.google/blog/towards-a-science-of-scaling-agent-systems-when-and-why-agent-systems-work/), blog 28 January 2026, paper [arXiv 2512.08296](https://arxiv.org/abs/2512.08296) [checked via search summary]. 180 configurations tested. Independent agents with no central check amplified errors **up to 17.2x**; a central coordinator contained them best. Coordination helps on tasks that split into parallel parts and hurts elsewhere. A widely repeated figure, that every multi-agent variant lost 39 to 70% on sequential reasoning tasks, appeared only in a secondary summary [unverified].

**When it helps:** broad research across many sources; reading that would flood one context; work that truly splits into independent parts.

**When it hurts:** steps that depend on each other; anything that edits shared state; acting on one screen (only one hand can use the pointer); short questions; tight budgets.

**Failure modes seen in practice** (all from the sources above):

- The lead starts far too many workers ("spawning 50 subagents for simple queries").
- Workers duplicate each other because the brief was vague.
- Workers search without end for sources that do not exist.
- The lead waits for the slowest worker; one stuck worker stalls the job.
- Workers make conflicting assumptions and the lead must reconcile them.
- A checker passes work without really testing it ("early victory").
- Wide fan-outs hit API rate limits ([Agent SDK hosting docs](https://code.claude.com/docs/en/agent-sdk/hosting)) [checked].
- Cost: every worker pays again for its own system prompt and tools.

#### B.2 Sub-agents with their own context and tools

**What it is.** A sub-agent is a separate model conversation started by the lead. It starts fresh. It receives only its own system prompt and the brief the lead wrote. Its intermediate tool calls stay inside it; only its final message returns to the lead ([Subagents in the SDK](https://code.claude.com/docs/en/agent-sdk/subagents)) [checked].

**It is a pattern, not a product.** On the Messages API a sub-agent is simply a second `messages` stream with a different `system` and `tools`, started by the app when the lead calls an app-defined tool such as `start_worker`. A Swift app can build this with what it already has.

**What it gives.** A small lead context; workers on a cheaper model; workers that hold fewer tools and so can do less harm.

**What it costs.** The brief is the only thing a worker knows. A weak brief gives a wrong but confident report. Anthropic's Managed Agents reference says the same: "Don't assume shared context" [bundled].

**Maturity.** High. This is how Claude Code, the Agent SDK and Managed Agents all work.

#### B.3 The Claude Agent SDK

**What it is.** Claude Code packaged as a library: the same agent loop, built-in tools (read, write, edit files, run commands, search the web), hooks, permissions, sessions, MCP, skills and sub-agents ([Agent SDK overview](https://code.claude.com/docs/en/agent-sdk/overview)) [checked].

**Languages.** Python (`claude-agent-sdk`, Python 3.10+) and TypeScript (`@anthropic-ai/claude-agent-sdk`, Node.js 18.14+). Nothing else.

**Can a Swift app use it? Only by bundling a runtime.** The SDK is a thin wrapper that "spawns and supervises a `claude` CLI subprocess" and talks to it over standard input and output. Both SDK packages bundle a native Claude Code binary. For any other language the docs say: "run the CLI as a subprocess with the `-p` flag and `--output-format json`" ([hosting](https://code.claude.com/docs/en/agent-sdk/hosting), [overview](https://code.claude.com/docs/en/agent-sdk/overview)) [checked]. So a Swift app would ship that binary inside the app bundle and drive it with `Process`.

**Limits it offers for runaway control** [checked, same subagents page]: depth of nesting (`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`, default 3; set 1 to forbid workers starting workers), workers at once (`CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`, default 20), money (`maxBudgetUsd`, no default limit), turns per worker (`maxTurns`). There is no wall-clock deadline for a session or a worker.

**Size.** About 1 GiB RAM, 5 GiB disk and 1 CPU per running agent as a starting point.

**Terms.** Anthropic's Commercial Terms apply. A product may say "Powered by Claude" but must not look like Claude Code. Sign-in with a claude.ai account is not allowed for third-party products; an API key is required.

**Fit for this app: poor.** It is built around a shell and a working folder of files, which the project rules forbid acting on. It would add a large binary, a second place where the API key lives (an environment variable for the subprocess), its own transcripts written to disk under `~/.claude/projects/`, and its own logs. Each of those collides with a privacy rule. What is worth taking from it is the design: the limit names above, and the rule that only the final message returns to the lead.

There is no official Anthropic client SDK for Swift either; the supported languages are Python, TypeScript, Java, Go, Ruby, C# and PHP, and other languages use raw HTTP [bundled]. The app's own HTTP client is the expected route.

#### B.4 Claude Managed Agents

**What it is.** Anthropic runs the agent loop on its servers and gives each session a cloud container where tools run. Status: **beta** (header `managed-agents-2026-04-01`), on the Claude API ([Managed Agents overview](https://platform.claude.com/docs/en/managed-agents/overview)) [bundled].

**The parts.**

- **Agent**: a saved, versioned configuration (model, system prompt, tools, MCP servers, skills). Made once.
- **Environment**: the container template, including which hosts it may reach.
- **Session**: one run. It streams events; the app sends messages and tool results. A session is durable: it goes idle and can be resumed later.
- **Tools**: a built-in set that runs in the container (shell, file read and write, search, web search, web fetch), plus MCP servers, plus **custom tools that the caller runs** (the session pauses, the app answers).
- **Multi-agent**: `multiagent: {"type": "multiagent_20261001", ...}` gives the lead a roster of sub-agents, each in its own thread with its own model and tools. **Depth above 1 is rejected**: only the lead delegates. There is a limit of 25 child threads. "Dynamic workflows" run many agents in phases [bundled, [multi-agent docs](https://platform.claude.com/docs/en/managed-agents/multiagent-orchestration)].
- **Outcomes**: a separate grader checks the result against a written rubric and sends the agent back until it passes.
- **Memory stores**: files that persist across sessions, with versions (beta header `agent-memory-2026-07-22`).
- **Scheduled deployments**: a cron expression and a time zone; each firing starts a session with no client involved.
- **Vaults**: Anthropic stores credentials and substitutes them at the network edge.

**Pricing model** [bundled, [pricing](https://platform.claude.com/docs/en/about-claude/pricing)]. Three meters: model tokens at each model's normal price; web searches at **$10 per 1,000**; session running time at **$0.08 per hour**. A session can carry a hard **budget** in dollars (`max_list_cost`); at the cap it pauses, it is not destroyed, and one more model request may finish past the cap. In a multi-agent session one budget is shared by all threads.

**What would leave the Mac.** The task's words, every message, every tool result the app sends in, any file attached, anything written to a memory store, and the session history itself, all held on Anthropic's servers for the life of the session. The agent's configuration (the system prompt) is stored there too. Not available: the computer use and browser use toolsets, and tool search, do not work in Managed Agents [checked, on the respective docs pages].

**What it would give this app.** Research that continues with the Mac asleep or shut. Scheduled runs ("every Monday, check X") with no local scheduler. A ready multi-agent harness with a money cap enforced by the platform.

**What it would cost in rules.** The project rules say captures stay in memory on the Mac, the Map lives only on the Mac, and no log holds a task's words. A managed session stores the task's words and the whole transcript on a server. A research task that reads only the web and gets no screen content and no Map facts could fit, with a rule change stated openly. A self-hosted sandbox mode exists (tools run on your own machine while Anthropic runs the loop), but the conversation still lives on the server.

**Maturity.** Beta, moving fast (multi-agent type dated October 2026). Expect the shapes to change.

#### B.5 Agent-to-agent protocols

**A2A (Agent2Agent).** A protocol for one agent to discover and call another agent built by someone else, across companies. Google announced it in April 2025 and gave it to the Linux Foundation on 23 June 2025. IBM's Agent Communication Protocol merged into it in August 2025. **Version 1.0, the first stable specification**, was marked at the one-year point; the project reports over 150 supporting organizations, backers including AWS, Cisco, Google, IBM, Microsoft, Salesforce, SAP and ServiceNow, support in Azure AI Foundry, Copilot Studio and Amazon Bedrock AgentCore, SDKs in Python, JavaScript, Java, Go and .NET, and over 22,000 GitHub stars ([Linux Foundation press release, 9 April 2026](https://www.linuxfoundation.org/press/a2a-protocol-surpasses-150-organizations-lands-in-major-cloud-platforms-and-sees-enterprise-production-use-in-first-year)) [checked]. The release names no production user by name, only industries.

**The foundation around it.** The Agentic AI Foundation (AAIF), under the Linux Foundation, launched 9 December 2025 with MCP (Anthropic), goose (Block) and AGENTS.md (OpenAI). Platinum members: AWS, Anthropic, Block, Bloomberg, Cloudflare, Google, Microsoft, OpenAI. It now also lists A2A among its projects and reports 305 member organizations as of 22 October 2026 ([AAIF](https://aaif.io/), [Linux Foundation press release](https://www.linuxfoundation.org/press/agentic-ai-foundation-surpasses-300-members-in-less-than-one-year)) [checked via search summary]. The exact date A2A moved under AAIF (reported as August 2026) is [unverified].

**Agent Client Protocol (ACP).** A different thing with a similar name: a protocol between an *editor* and a *coding agent*. Xcode 27 accepts any ACP-compatible agent ([Apple Newsroom, 8 June 2026](https://www.apple.com/newsroom/2026/06/apple-aids-app-development-with-new-intelligence-frameworks-and-advanced-tools/)) [checked].

**Honest view of adoption.** A2A is real, stable and backed by the large cloud vendors. Its use is inside companies, connecting agents across departments and vendors. Anthropic's own sub-agent features (Agent SDK, Managed Agents) do not use it; they use plain tool calls. There is no Swift SDK.

**For this app: nothing to build.** A2A solves "my agent must call a stranger's agent over the network". An app for one user on one Mac, whose workers are its own model calls, has no stranger to talk to. Revisit only if the app ever needs to hand a job to an outside agent service.

#### B.6 Long-running and background agents, checkpoints and resumption

**The problem.** A long job outlives one context window, one network connection, one app launch, or the lid being closed.

**What the labs do.**

- Anthropic's research system: "regular checkpoints" plus retry logic, so that after an error the agent can "resume from where the agent was when the errors occurred" rather than start over ([multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system)) [checked].
- [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) (Anthropic, about November 2025) [checked via search summary]: state lives in files outside the model, a progress log plus version history, so a fresh context can pick the work up. A later post, [Harness design for long-running apps](https://www.anthropic.com/engineering/harness-design-long-running-apps) (about March 2026), adds planner and evaluator roles.
- API features for long runs [bundled]: **compaction** (beta `compact-2026-01-12`; the server summarizes old context near a threshold), **context editing** (beta; drops old tool results), **task budgets** (beta `task-budgets-2026-03-13`; a token allowance, minimum 20,000, that the model can see and pace itself against; it is advisory, not a hard stop), and **prompt caching**.
- Agent SDK: sessions can be resumed or forked by ID; transcripts are files on disk.
- Managed Agents: the session itself is the checkpoint, kept on the server.

**What it would give this app.** A research job that survives quitting the app or a dropped connection, and a job the user can pause.

**What a local version needs.** After each finished worker, save that worker's report (the app already keeps a Markdown copy of reports in its own storage) and a small job record: the plan, which parts are done, money spent. On restart, re-run only the unfinished parts. This is a few fields, not a framework. The record holds the task's words, so it belongs in the encrypted store with the reports, never in a log.

**Failure modes.** Resuming into a world that changed (a page moved, a file was edited). A checkpoint that saves the conversation but not what the tools already did, so an action is done twice. For read-only research the second is harmless; for acting it is the main danger.

#### B.7 Tool search and deferred tool loading

**What it is.** Mark tools `defer_loading: true` and add a search tool (`tool_search_tool_regex_20251119` or `tool_search_tool_bm25_20251119`). The model sees only the search tool and the few always-on tools, searches when it needs more, and the matching definitions are loaded at that point ([tool search tool docs](https://platform.claude.com/docs/en/agents-and-tools/tool-use/tool-search-tool)) [checked].

**Facts.** Stable, no beta header, available to a plain Messages API caller, eligible for zero data retention, not billed as a separate tool. Up to 10,000 deferred tools per request. Each search returns 5 tools by default. Anthropic's example: five connected services cost about 55,000 tokens of definitions before any work, and search "typically reduces this by over 85 percent". Tool choice gets worse above 30 to 50 loaded tools. Use it with 10 or more tools or more than 10,000 tokens of definitions; below that it is overhead. Loaded definitions are appended, so the prompt cache survives. The app may also run its own search and return `tool_reference` blocks.

**For this app.** Not needed while the tool list is short. It becomes the right answer when per-app action tools, shortcuts-as-tools and connectors push the list past about 30. It is also the lab's first suggestion *before* splitting into specialist agents.

**Failure mode.** The model does not find a tool whose name and description do not contain the words it searched for. Naming and descriptions matter.

#### B.8 Programmatic tool calling

**What it is.** Instead of one model turn per tool call, the model writes a short Python script that calls the tools in a loop; the script runs in Anthropic's code execution container; only the script's final output goes back into the model's context. When the script calls one of *your* tools, the response pauses and the app answers, as with a normal tool call ([programmatic tool calling docs](https://platform.claude.com/docs/en/agents-and-tools/tool-use/programmatic-tool-calling)) [checked].

**Facts.** Stable. Needs the code execution tool (`code_execution_20260120` or later) and `"allowed_callers"` on each tool. Works with `claude-sonnet-5-5` and `claude-haiku-5-5`. **Not eligible for zero data retention**; container data is kept up to 30 days. A pending call times out after about 4 minutes. It does not work with strict tool schemas, forced tool choice, MCP connector tools, or the computer and browser toolsets.

**Measured by Anthropic:** on a 75-tool agent test, about **38% fewer** billed input tokens with no change in accuracy; across production traffic with 10 to 49 tools, typical savings of 20 to 40%; on a test where each turn makes only one or two calls in sequence, no gain and about **8% more** cost.

**For this app.** A possible later saving for a research worker that makes many searches and filters the results. The intermediate results pass through a server container and are retained, so the same care applies as for code execution. Not for acting on the Mac: each action must be checked on screen before the next, which is exactly the sequential case that gains nothing.

#### B.9 Memory tools

**The Claude API memory tool.** `{"type": "memory_20250818", "name": "memory"}`. A client-side tool: the model issues file commands (`view`, `create`, `str_replace`, `insert`, `delete`, `rename`) on a `/memories` folder, and **the app decides where and how those files are stored** [bundled, [memory tool docs](https://platform.claude.com/docs/en/agents-and-tools/tool-use/memory-tool)]. Helper classes exist for Python, TypeScript and Java only. Anthropic's warning: never store secrets in memory files; the reference code has no access control.

**Managed Agents memory stores.** The server-side version: files mounted into the session container, with version history, kept at Anthropic (beta).

**For this app.** It already has its own encrypted memory with a fixed set of classes and links. The memory tool would give the model free-form file writes, which cuts across the rule that memory writes use only the defined classes. The useful part is narrower: a per-job scratch note that workers and the lead can read and write during one job, stored in the app's encrypted store and deleted when the job ends. That is the "shared file" that the Managed Agents reference recommends for passing facts between workers, without the telephone game.

**Failure modes.** Memory that grows stale and is trusted anyway; injected text from a web page written into memory and obeyed later. Facts from the web should enter long-term memory only by the user's tick, as the app does now.

#### B.10 One table for Part B

| Topic | Maturity (Nov 2026) | Gives this app | Costs | Seen to fail by |
|---|---|---|---|---|
| Orchestrator and workers | Proven for research | Wider, faster research | 3 to 10x tokens of one agent | Too many workers, duplicates, vague briefs |
| Sub-agents with own context | Proven | Small lead context, cheaper workers, fewer tools each | A repeated prompt per worker | Worker knows only its brief |
| Claude Agent SDK | Stable; Python and TypeScript only | Little. A design to copy | A bundled binary, files on disk, second home for the key | No wall-clock limit; built for code and shell |
| Claude Managed Agents | Beta | Runs with the Mac off; schedules; platform money cap | Tokens + $0.08 per session-hour + $10 per 1,000 searches; data on a server | Beta changes; no computer use; rules must change |
| A2A | 1.0 stable; enterprise | Nothing today | n/a | n/a |
| Checkpoints and resume | Pattern, plus API helpers in beta | Jobs survive a quit | Small local record | Doing an action twice |
| Tool search | Stable | Keeps many tools cheap | None extra | Tool not found by its wording |
| Programmatic tool calling | Stable | 20 to 40% fewer tokens on many-call jobs | Server container, 30-day retention | No gain on step-by-step work (+8%) |
| Memory tool | Stable, client-side | A per-job scratch note | Storage code | Stale or injected notes |

---

### Part C. A concrete proposal

#### C.1 The smallest version

Today: one fixed research agent, up to three tasks at once. Proposed: the same task, but the main model may split it.

| Part | What it does | Model | Tools it holds | Runs on |
|---|---|---|---|---|
| **Lead** | Reads the task. Decides: answer alone, or split into 2 to 4 independent questions. Writes one self-contained brief per worker. Later reads the reports and writes the final report | `claude-sonnet-5-5` | `start_workers` (one call, a list of briefs, each with a named tool set and a budget), the memory search, web search and fetch for its own checks | The Mac: one Messages API stream |
| **Worker** (N of them) | Answers exactly one question. Returns a short report in a fixed shape: findings, a source for each, what it could not confirm | `claude-haiku-5-5` for search and read; `claude-sonnet-5-5` only if the brief needs judgment | A **named set** chosen by the lead from a fixed menu: `web` (search + fetch), `map_read`, `url_from_task`. Never an acting tool, never `start_workers` | The Mac: one stream each, in parallel |
| **Checker, step 1** | No model. Code checks each report: every claim has a source; every source is an address a worker actually fetched; nothing exceeds its budget; the shape is valid | none | none | The Mac |
| **Checker, step 2** | One fresh-context call. Sees only the final report, the source list and a short rubric. Marks each claim: supported, not supported, not checked. Must give a reason per mark | `claude-sonnet-5-5` | web fetch only, to open cited pages | The Mac: one stream |
| **Shown to the user** | The final report, with "Not checked" marks kept visible. It waits in the menu bar as now | | | |

Why this shape:

- **The app's code starts the workers, not a framework.** `start_workers` is an ordinary tool. When the lead calls it, the app opens N more Messages API streams. No new dependency, no server, no bundled runtime. The existing provider interface and the existing three-at-once task runner are reused.
- **One split, one level.** The lead may call `start_workers` once per job (a second call only to redo a failed part). Workers cannot start workers. Managed Agents enforces the same rule on its servers ("Depth > 1 is a validation error"); here the app's code enforces it by simply not giving workers the tool.
- **The lead decides whether to split at all, and the default is no.** Anthropic's scaling rule: a simple fact needs one agent and 3 to 10 tool calls. The lead's prompt carries that rule. A task with one question stays a single agent, exactly as today.
- **The named tool set is a menu, not free choice.** The lead names a set; the app's code maps the name to real tools. The model can never invent a capability.
- **Workers share one prompt prefix.** Same system prompt and tool list for every worker of a kind, with the brief placed last, so the prompt cache serves workers 2 to N at the cache-read price.
- **The checker is mostly code.** Anthropic's own reference warns against adding model checkers that redo an answer, and names "marking outputs as passing without thorough testing" as the main failure of checking agents. So the cheap, certain checks are done in code, and the single model check gets a concrete rubric and must justify each mark.

#### C.2 What runs on the Mac and what on a server

| | On the Mac | On Anthropic's servers |
|---|---|---|
| The loop, the plan, starting and stopping workers | Yes | No |
| Limits (count, depth, money, time) | Yes, in the app's code | No |
| The model itself | No | Yes, as today |
| Web search and web fetch | No | Yes, as today (server tools of the Messages API) |
| Reports, job record, memory | Yes, encrypted | No |
| Screen captures | Lead only, once, in memory, as today. Never passed into a worker brief | Sent with the lead's request as today |

Nothing new leaves the Mac compared with today's single research agent. That is the main reason to build it locally first.

Managed Agents is the later option for one thing only: jobs that must run while the Mac is off, or on a schedule. It would need an explicit rule change, because the task's words and transcript would be stored on a server.

#### C.3 Expected cost per job

Illustrative arithmetic, not a measurement. Prices: `claude-sonnet-5-5` $2 / $10 per million tokens, cache reads $0.10; `claude-haiku-5-5` $0.10 / $0.50; web search $10 per 1,000.

| Setup | Assumed work | Rough cost |
|---|---|---|
| **Single agent today** (Sonnet) | 100K fresh input, 300K cached input, 20K output, 20 searches | $0.20 + $0.03 + $0.20 + $0.20 = **about $0.65** |
| **Lead + 4 Haiku workers + checker** | Lead: 60K in, 10K out ($0.22). Each worker: 300K in, 8K out, 15 searches ($0.03 + $0.004 + $0.15 = $0.18; four = $0.74). Checker: 40K in, 3K out ($0.11) | **about $1.10** (1.7x) |
| **Lead + 4 Sonnet workers + checker** | Same token counts, workers on Sonnet (each about $0.48; four = $1.92) | **about $2.25** (3.5x) |

Three things to take from it:

1. In **tokens**, the multi-agent job uses roughly 3 to 4 times as many as the single agent, in line with the labs' 3-10x and 4x figures.
2. In **dollars**, the gap shrinks when workers run on the small model, because the small model is 20 times cheaper per token. The web searches (a cent each) become the largest line.
3. The real numbers must come from the app's own `calls.log` after ten or so real jobs. Until then these are estimates.

#### C.4 The limits, so it cannot run away

All enforced by the app's code. The model is told the limits so it can plan, but it is never trusted to keep them.

| Limit | Proposed value | What happens at the limit |
|---|---|---|
| Workers per job | 4 | `start_workers` with more than 4 briefs is refused with a plain error the lead can read |
| Depth | 1 | Workers do not hold the tool. Nothing to enforce at run time |
| Splits per job | 1, plus one redo of failed parts | A third call is refused |
| Model streams at once, whole app | 6 | Further workers wait in a queue. Keeps under API rate limits |
| Jobs at once | 3, as today | Unchanged |
| Tool calls per worker | 15 (Anthropic's rule: 10 to 15) | The worker is told to write its report now |
| Web searches per worker | `max_uses` of 10 on the search tool, enforced by the API | The tool returns an error result; the worker reports with what it has |
| Money per job | A cap the user sets; default about $2. A quarter is held back for the final report and the check, as the app's reserve already does | No new request starts once spent + reserve reaches the cap. Finished reports are kept. The lead writes the report from what exists and says what is missing |
| Money per worker | Its share of the job cap | The worker is stopped; its partial report is marked partial |
| Time per worker | 5 minutes | Stopped; marked partial |
| Time per job | 15 minutes | As for the money cap |
| Stop | Within one second, as today | Every stream of the job is cancelled together |
| Retries | One, only for a network or overload error | Never a blind retry of a worker that returned a bad report |

Also: a worker's report is **data**. The lead's prompt must say so, and the app should strip anything in a report that imitates a system message, as Claude Code does for its own sub-agents. A web page read by a worker can otherwise pass an instruction up to the lead.

#### C.5 What should NOT be built yet

- **Workers that act on the Mac.** One pointer, one front app. Parallel actors would fight each other, and the project rule already says background agents never click.
- **Workers that start workers.** Depth 1 only.
- **A roster of role agents** (planner, researcher, writer, critic). The labs' own evidence calls this the telephone game.
- **The Agent SDK inside the app.** A bundled binary, transcripts on disk and a second home for the key, for features the app can do in a few hundred lines.
- **Managed Agents.** Not until there is a clear need to run with the Mac off, and a stated rule change.
- **A2A or any agent-to-agent protocol.** No outside agent to talk to.
- **Computer use as the main hand.** A fallback for empty accessibility trees only, later.
- **Programmatic tool calling and server-side Skills.** Both pass data through a server container that is not covered by zero data retention. Measure the plain version first.
- **Tool search.** Not until the tool list passes about 30.
- **A free-form memory tool for workers.** A per-job scratch note at most.
- **An agent that writes new tools or new agents for itself.** "Starts agents by himself" should mean "decides when to split a job among workers of known kinds", not "invents new kinds".

#### C.6 An honest view: where many agents are worse than one good agent

- **Most tasks.** A question with one thread of reasoning gains nothing from a split and pays 3 to 10 times the tokens. Anthropic's newest guidance (October 2026) is that a single agent with skills loaded on demand often beats a subagent design on quality, cost and speed.
- **Anything sequential.** If step two depends on what step one found, parallel workers cannot help, and the hand-off loses detail.
- **Anything that changes things.** Workers that cannot see each other make clashing choices. Acting on the Mac is the clearest case.
- **Trust.** Each hand-off is a summary of a summary. A wrong claim in a worker's report arrives at the lead looking as confident as a right one. Without a central check, errors multiply rather than cancel (Google's measurement: up to 17.2x).
- **Predictable cost.** One agent's spend is one curve. Five agents can each reach their cap.
- **Delay on small jobs.** Planning, briefing and combining add turns. Parallel work only wins when the parts are large.
- **Much of the gain is simply more tokens.** In Anthropic's own analysis, token use explained 80% of the difference. A single agent given a larger budget and a newer model closes part of the gap. Newer models also need the split less: Anthropic notes that more capable models can often evaluate work directly, and that Claude Opus 5 has to be told *not* to over-delegate.

So the right promise is narrow: **for broad research that splits into independent questions, he starts a few workers and checks their work; for everything else he stays one agent.** The lead choosing *not* to split is the feature working, not failing.

#### C.7 Order of building, smallest first

1. `start_workers` as a tool of the existing research agent; workers on `claude-haiku-5-5` with the `web` set; all limits of C.4; the code checker. Measure cost and quality against the single agent on about ten real tasks.
2. The one-call model checker with "Not checked" marks, reusing what the deeper-research mode already shows.
3. A job record so a split job survives quitting the app.
4. Shortcuts as tools: `shortcuts list` gives the names, the user ticks which ones he may run, each becomes a tool. This is the largest gain in reach for the least code, and it stays on the Mac.
5. The app's own App Intents, so Siri, Spotlight and Shortcuts can call it.
6. Only then: weigh Managed Agents for scheduled and Mac-off jobs.

---

### Things I could not verify

- Whether any macOS 27 API lets a third-party app call another app's App Intents directly. Three Apple pages say nothing of one; absence on those pages is not proof for every later point release.
- The relation between 2024's `AssistantSchemaIntent` and 2026's App Schemas.
- Whether `shortcuts://run-shortcut` still brings the Shortcuts app to the front on macOS 27.
- Per-step latency of the computer use tool (no figure in Anthropic's docs).
- The Microsoft hybrid computer use results (self-reported; seen only in a search summary).
- The "39 to 70% worse on sequential tasks" figure from the Google scaling paper (secondary summary only).
- The date A2A moved under the Agentic AI Foundation.
- Details of the browser use tool beyond a search summary of its docs page.
- All cost figures in C.3 are arithmetic on list prices with assumed token counts, not measurements.


---

## 18.4 The two doors, and the two tests of 17 November

Your words of 17 November changed 18.1 in four places: several tools, not only Notion; a write in a job you watch carries no "leaves your Mac" tag; no browser opens per tool during a job; both doors are built. This section is the design now. Where it differs from 18.1, this section holds.

### Why two doors

Anthropic forbids a Claude sign-in inside another app: "Anthropic does not permit third-party developers to offer Claude.ai login into their own applications, or to route requests through Free, Pro, Max, or Ultra plan credentials on behalf of their users" (code.claude.com/docs/en/legal-and-compliance, read 17 November). The same page allows a product to start the unmodified Claude Code program when each person signs in to it with their own plan. Figma's online server lets in only the programs on its own list (developers.figma.com/docs/figma-mcp-server/remote-server-installation); Claude Code is on it, and Figma is not adding new ones.

| | Door 1: through Claude Code | Door 2: Phew's own client |
|---|---|---|
| Who pays | Your Claude plan | Your API key |
| Sign-in | None: the connectors of your Claude account | The browser, once, when you press Connect |
| Reaches | Everything your Claude account has, Figma included | Tools with open sign-in. Not Figma online |
| For others | Each person needs Claude Code and a plan | Works with an API key only |

### The gate, the same for both

Phew's own table says which tools read and which write. A tool it does not know counts as a write. The server's own marks (`readOnlyHint`) are not trusted. Reads run freely. A write goes through the one acting function, listed on the card like any action. A write asked by a background task waits for your confirm. A tool's answer is data and passes the secrets filter.

### Test T1: the Claude Code door. Passed, with one correction

Run on made-up data with a made-up tool server on the Mac (one read tool, one write tool, an answer carrying a forged order). Claude Code 2.1.326, small model. No real connector was called; only names and counts were read.

| Question | Result |
|---|---|
| Does Phew see each call before it runs? | Yes. With `--permission-prompt-tool stdio` each call arrives as a `can_use_tool` request on the output stream and waits for the answer. Without that option the call is refused by itself |
| Can Phew refuse? | Yes. The refused write never reached the tool server (its own log shows the read only) |
| A forged order in a tool's answer | Not followed, and the model said so |
| Start time | 0.3 s with no settings; first words at 1.3 s. With your account's connectors: 3 to 7 s |
| Your connectors without sign-in | Yes, 20 connected ones listed. **Only when your Claude Code settings are loaded** (`--setting-sources user`). With settings off, none load; `ENABLE_CLAUDEAI_MCP_SERVERS` and `allowAllClaudeAiMcps` did not change that |
| Loading only what you ticked | Works: every other server is refused by name with `--disallowedTools mcp__<server>`, and the model then sees only the ticked one |
| Size | All connectors together: about 0.70 dollars of tokens for one question (counted, not charged: your plan pays). Notion alone, 77 tools: about 100,000 tokens. So single tools must be refused too, and only the few that fit the job left in |
| Written to disk | No session file with `--no-session-persistence`. Claude Code's own bookkeeping files changed (`anchor-usage.json`, plugin sync marks): no words of yours |
| What else the run carries | Claude Code adds by itself: the Mac's system details, the date, your account's email, and usage notes from tool servers. Your own instruction file was not seen. Hooks are switched off with `disableAllHooks`, commands with `--disable-slash-commands`, its own tools with `--tools ""` |

**The correction.** The plan said your Claude Code settings would not be loaded. They must be: the connectors arrive only that way. The guards that replace it: hooks off, commands off, Claude Code's own tools off, every server and tool not ticked refused, Phew's own instructions in place of Claude Code's. Plugins you installed in Claude Code still start their own tool servers; they are refused by name.

The command, pinned by a test:

```
claude -p --output-format stream-json --verbose --input-format stream-json
  --no-session-persistence --tools "" --disable-slash-commands
  --setting-sources user --settings '{"disableAllHooks":true}'
  --system-prompt <Phew's own> --permission-prompt-tool stdio
  --disallowedTools <every server and tool not ticked>
```

The environment holds only `PATH`, `HOME`, `USER`, `LOGNAME`, `TMPDIR`. Without `USER` Claude Code says "Not logged in".

### Test T2: Notion's own server (NB.1). Passed

| Question | Result |
|---|---|
| Sign-in for an app it does not know | Yes. `https://mcp.notion.com/register` gave a client id to a made-up name, as a public client (no secret), with a loopback address `http://127.0.0.1:<port>/callback` |
| The flow | Authorization code with PKCE (S256). You signed in once in the browser; the code came back to the Mac |
| A client that speaks 2025-11-25 | Accepted: `initialize` and `tools/list` both answered. The exact version the server answered was not kept (the test's output was cut) |
| Tools | 77. Their definitions are about 251,000 characters, so only the tools that fit the job can be sent |
| The token | Kept in memory only and dropped. Nothing of your Notion was read: the tool list only |

Not tested: the sign-in from inside the menu-bar app (the test ran from a script), a token refresh, a tool call.
