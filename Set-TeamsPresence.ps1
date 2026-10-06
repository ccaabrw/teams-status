#Requires -Modules Microsoft.Graph.Authentication

[CmdletBinding(DefaultParameterSetName = 'Set', SupportsShouldProcess)]
param(
    [Parameter(Mandatory, ParameterSetName = 'Set')]
    [ValidateSet('Available', 'Busy', 'DoNotDisturb', 'BeRightBack', 'Away', 'Offline')]
    [string]$Status,

    [Parameter(ParameterSetName = 'Set')]
    [ValidateScript({ $_ -gt [TimeSpan]::Zero })]
    [TimeSpan]$Duration = [TimeSpan]::FromHours(1),

    [Parameter(Mandatory, ParameterSetName = 'Reset')]
    [switch]$Reset
)

if ($PSCmdlet.ParameterSetName -eq 'Reset') {
    if (-not $Reset) {
        throw 'Use -Reset to clear the preferred presence.'
    }
    $operation = 'clearUserPreferredPresence'
    $body = '{}'
    $action = 'Reset Teams presence'
}
else {
    $activities = @{
        Available    = 'Available'
        Busy         = 'Busy'
        DoNotDisturb = 'DoNotDisturb'
        BeRightBack  = 'BeRightBack'
        Away         = 'Away'
        Offline      = 'OffWork'
    }
    $availability = if ($Status -ieq 'Offline') { 'Offline' } else { $activities[$Status] }
    $operation = 'setUserPreferredPresence'
    $body = @{
        availability       = $availability
        activity           = $activities[$Status]
        expirationDuration = [System.Xml.XmlConvert]::ToString($Duration)
    } | ConvertTo-Json
    $action = "Set Teams presence to $availability for $Duration"
}

if ($PSCmdlet.ShouldProcess('Signed-in Microsoft Teams user', $action)) {
    Connect-MgGraph -Scopes 'Presence.ReadWrite' -ContextScope Process -NoWelcome -ErrorAction Stop
    Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/me/presence/$operation" -Body $body -ContentType 'application/json' -ErrorAction Stop
}
