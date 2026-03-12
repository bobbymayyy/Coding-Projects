function Invoke-PingSweep {
    param(
        [string]$Subnet = "192.168.1",
        [int]$Start = 1,
        [int]$End = 254
    )

    $Start..$End | ForEach-Object {
        $ip = "$Subnet.$_"
        if (Test-Connection -ComputerName $ip -Count 1 -Quiet -ErrorAction SilentlyContinue) {
            [PSCustomObject]@{
                IP = $ip
                Status = "Up"
            }
        }
    }
}

Invoke-PingSweep -Subnet "192.168.1"