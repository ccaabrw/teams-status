# teams-status

Scripts to query and set your own Microsoft Teams presence through Microsoft
Graph, with PowerShell and Bash versions.

## Setup

Use PowerShell 7 and install the Microsoft Graph authentication module:

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
```

Run the scripts from this directory. Each script uses interactive delegated
sign-in with your Microsoft 365 account; no passwords or tokens are stored in
these scripts. Querying requires `Presence.Read`, and setting or resetting
requires `Presence.ReadWrite`. Your organization's consent policies may require
administrator approval. The account must have access to Microsoft Teams.

## Usage

```powershell
# Return the signed-in user's effective presence (availability and activity).
./Get-TeamsPresence.ps1

# Set a preferred status for one hour (the default).
./Set-TeamsPresence.ps1 -Status Busy

# Specify a positive duration in hours:minutes:seconds.
./Set-TeamsPresence.ps1 -Status DoNotDisturb -Duration '02:00:00'

# Appear offline.
./Set-TeamsPresence.ps1 -Status Offline

# Clear the preference and let Teams determine presence automatically.
./Set-TeamsPresence.ps1 -Reset

# Preview without signing in or changing presence.
./Set-TeamsPresence.ps1 -Status Away -WhatIf
```

Supported statuses: `Available`, `Busy`, `DoNotDisturb`, `BeRightBack`, `Away`,
and `Offline` (sent to Graph with activity `OffWork`). `-Reset` cannot be
combined with `-Status` or `-Duration`.

Setting uses Graph's **user-preferred presence**, not an application presence
session. The preference expires after the duration or can be cleared with
`-Reset`. Keep Teams signed in: without an active presence session, Graph may
report Offline. Teams aggregates presence signals, so the queried effective
presence may differ from the preference, and updates may take time to appear.
Successful set/reset requests normally return no output; authentication and API
errors stop the script. Use `Disconnect-MgGraph` when finished to end the
Graph sign-in in the current PowerShell process.

## Linux (Bash)

Install `curl` and `jq`, then run the scripts from any directory:

```bash
# Return the signed-in user's effective presence.
./get-teams-presence.sh

# Opt in to saving and reusing an access token.
./get-teams-presence.sh --cache-token
./set-teams-presence.sh --status Busy --cache-token

# Set a preferred status for one hour (the default).
./set-teams-presence.sh --status Busy

# Specify a positive duration in hours:minutes:seconds.
./set-teams-presence.sh --status DoNotDisturb --duration 02:00:00

# Appear offline, or clear the preference.
./set-teams-presence.sh --status Offline
./set-teams-presence.sh --reset

# Preview without signing in or changing presence.
./set-teams-presence.sh --status Away --what-if
```

The Bash scripts use Microsoft Graph's device-code sign-in with the Microsoft
Graph PowerShell public client application. Follow the displayed sign-in
instructions in a browser. Querying requires `Presence.Read`; setting or
resetting requires `Presence.ReadWrite`. Organization consent policies may
require administrator approval. By default, no passwords or tokens are persisted;
the access token is briefly held in memory and written to a mode-restricted temporary
header file for the Graph request. Temporary files are removed when the script
exits.

Pass `--cache-token` on each invocation to save and reuse an access token locally.
Tokens are stored as plaintext in `${XDG_CACHE_HOME:-$HOME/.cache}/teams-status`,
with directory permissions `700` and file permissions `600`. Protect this directory
like a password; anyone who can read a token can use it until it expires.
Separate `Presence.Read.json` and `Presence.ReadWrite.json` files prevent reusing
a query-only token for a write operation. Missing, invalid, or expired tokens
(including tokens within 60 seconds of expiry) trigger device-code sign-in again.
No refresh tokens are stored. Omit the option to ignore the cache, or delete these
files to remove cached credentials (for example, when switching accounts or after
a token is revoked). `--what-if` does not read or write the cache.

API reference: [get presence](https://learn.microsoft.com/en-us/graph/api/presence-get?view=graph-rest-1.0),
[set preferred presence](https://learn.microsoft.com/en-us/graph/api/presence-setuserpreferredpresence?view=graph-rest-1.0),
and [clear preferred presence](https://learn.microsoft.com/en-us/graph/api/presence-clearuserpreferredpresence?view=graph-rest-1.0).