#Requires -Modules Microsoft.Graph.Authentication

[CmdletBinding()]
param()

Connect-MgGraph -Scopes 'Presence.Read' -ContextScope Process -NoWelcome -ErrorAction Stop
Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/me/presence' -OutputType PSObject -ErrorAction Stop
