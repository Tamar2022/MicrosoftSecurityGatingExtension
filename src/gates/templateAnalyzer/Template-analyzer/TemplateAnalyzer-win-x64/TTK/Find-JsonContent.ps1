﻿function Find-JsonContent
{
    <#
    .Synopsis
        Finds content within a json object
    .Description
        Recursively finds content within a json object
    #>
    param(
    # The input object
    [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
    [PSObject]
    $InputObject,

    # The key (the name of the property) we're finding.
    [Parameter(Mandatory=$true,ParameterSetName='Key',Position=0,ValueFromPipelineByPropertyName=$true)]
    [Parameter(Mandatory=$true,ParameterSetName='KeyValue',Position=0,ValueFromPipelineByPropertyName=$true)]
    [string]
    $Key,

    # The value we're trying to find.
    [Parameter(Mandatory=$true,ParameterSetName='KeyValue',Position=1,ValueFromPipelineByPropertyName=$true)]
    [PSObject]
    $Value,

    # If set, will find values like the wildcard.
    [Parameter(ParameterSetName='Key',ValueFromPipelineByPropertyName=$true)]
    [Parameter(ParameterSetName='KeyValue',ValueFromPipelineByPropertyName=$true)]
    [switch]
    $Like,

    # If set, will find values that match the regular expression.
    [Parameter(ParameterSetName='Key',ValueFromPipelineByPropertyName=$true)]
    [Parameter(ParameterSetName='KeyValue',ValueFromPipelineByPropertyName=$true)]
    [switch]
    $Match,

    # If set, will find values that are not like a wildcard.
    [Parameter(ParameterSetName='Key',ValueFromPipelineByPropertyName=$true)]
    [Parameter(ParameterSetName='KeyValue',ValueFromPipelineByPropertyName=$true)]
    [switch]
    $NotLike,

    # If set, will find values that do not match a regular expression.
    [Parameter(ParameterSetName='Key',ValueFromPipelineByPropertyName=$true)]
    [Parameter(ParameterSetName='KeyValue',ValueFromPipelineByPropertyName=$true)]
    [switch]
    $NotMatch,

    # A list of parent objects.  This parameter will be passed recursively.
    [PSObject[]]
    $Parent,

    # The maximum depth to search
    [Uint32]
    $Depth,

    # The name of the current property.  This parameter will be passed recursively.
    [string[]]
    $Property)

    begin {
        $OutputMatch = {
            param([Parameter(Mandatory)][PSObject]$in)

            $OutObject = [Ordered]@{}
            foreach ($prop in $in.psobject.properties) {
                $OutObject[$prop.Name] = $prop.Value
            }
            $OutObject['ParentObject'] = $parent
            $OutObject['PSTypeName']   = 'JSON.Content'
            $OutObject['PropertyName'] = if ($property) {$Property[-1] -replace '^\[\d+\]\.'}
            $OutObject['JSONPath']     = @(
                $np =0
                foreach ($p in $property) {
                    if ($p.StartsWith('[') -or -not $np) {
                        $p
                    } else {
                        ".$p"
                    }
                    $np++
                }) -join ''
            [PSCustomObject]$OutObject
        }
    }

    process {
        $mySplat = @{} + $PSBoundParameters
        $mySplat.Remove('InputObject')
        if (-not $InputObject) { return }


        $index = -1
        $originalProperty = @() + $Property       
        foreach ($in in $InputObject) {
            if (-not $in) { continue }
            $index++
            if ($in -is [string] -or $in -is [int] -or $in -is [bool] -or
                $in -is [double] -or $in -is [long] -or $in -is [float]) {
                continue
            }

            if ($PSCmdlet.ParameterSetName -eq 'KeyValue') {
                if ($in.psobject.properties.item($key)) {
                    if (($like -and $in.$key -like $Value) -or
                        ($Match -and $in.$key -match $Value) -or
                        ($NotLike -and $in.$key -notlike $Value) -or
                        ($NotMatch -and $in.$key -notmatch $Value) -or
                        ($in.$key -eq $Value -and -not ($NotLike -or $NotMatch))) {


                        if ($InputObject -is [Collections.IList] -and $Property) {                             
                            $property += "[$index]"
                        }
                        $property += $key
                        
                        . $outputMatch $in

                        $property = $originalProperty
                    }
                }
            } elseif ($PSCmdlet.ParameterSetName -eq 'Key') {
                $propertyNames = @(foreach ($_ in $in.psobject.properties) { $_.Name })
                if (($Like -and $propertyNames -like $key) -or
                    ($Match -and $propertyNames -match $key) -or
                    ($propertyNames -eq $key -and -not ($NotLike -or $NotMatch)))
                {
                    $matchingKeys =
                        @(if ($like) {
                            $propertyNames -like $key
                        } elseif ($match) {
                            $propertyNames -match $key
                        } else {
                            $key
                        })
                    $propertyList = @() + $Property
                    foreach ($k in $matchingKeys) {
                        if ($InputObject -is [Collections.IList] -and $Property) {
                            $property += "[$index].$($k)"
                        } else {
                            $property += $k
                        }
                        
                        . $OutputMatch $in
                        $property = $propertyList
                    }
                }
                elseif (
                    ($NotMatch -and $propertyNames -notmatch $Key) -or
                    ($NotLike -and $propertyNames -notlike $Key)
                )
                {
                    . $OutputMatch $in
                }
            }


            if ($parent -contains $in) {
                continue
            }
            $mySplat.Parent = @($in) + $Parent

            if ($depth -and $mySplat.Parent.Length -ge $Depth) {
                continue
            }

            if ($in -is [Object[]]) {

                Find-JsonContent @mySplat -InputObject $in
            } else {
                $propertyAndIndex =
                    @(if ($Property) {
                        $property
                    }
                    if ($InputObject -is [Collections.IList]) {
                        "[$index]"
                    })
                foreach ($prop in $in.psobject.properties) {
                    if (-not $prop.Value) { continue }
                    if ($prop.Name -like 'parent*') { continue }
                    $mySplat.Property = $propertyAndIndex + $prop.Name


                    Find-JsonContent @mySplat -InputObject $prop.Value
                }

                
            }
        }
    }
}

# SIG # Begin signature block
# MIInrQYJKoZIhvcNAQcCoIInnjCCJ5oCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAnQ51EIxgdjwhb
# a3rreBaZ89HrFYyRUbitw86/KS1BXqCCDYEwggX/MIID56ADAgECAhMzAAACUosz
# qviV8znbAAAAAAJSMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjEwOTAyMTgzMjU5WhcNMjIwOTAxMTgzMjU5WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDQ5M+Ps/X7BNuv5B/0I6uoDwj0NJOo1KrVQqO7ggRXccklyTrWL4xMShjIou2I
# sbYnF67wXzVAq5Om4oe+LfzSDOzjcb6ms00gBo0OQaqwQ1BijyJ7NvDf80I1fW9O
# L76Kt0Wpc2zrGhzcHdb7upPrvxvSNNUvxK3sgw7YTt31410vpEp8yfBEl/hd8ZzA
# v47DCgJ5j1zm295s1RVZHNp6MoiQFVOECm4AwK2l28i+YER1JO4IplTH44uvzX9o
# RnJHaMvWzZEpozPy4jNO2DDqbcNs4zh7AWMhE1PWFVA+CHI/En5nASvCvLmuR/t8
# q4bc8XR8QIZJQSp+2U6m2ldNAgMBAAGjggF+MIIBejAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUNZJaEUGL2Guwt7ZOAu4efEYXedEw
# UAYDVR0RBEkwR6RFMEMxKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVyYXRpb25zIFB1
# ZXJ0byBSaWNvMRYwFAYDVQQFEw0yMzAwMTIrNDY3NTk3MB8GA1UdIwQYMBaAFEhu
# ZOVQBdOCqhc3NyK1bajKdQKVMFQGA1UdHwRNMEswSaBHoEWGQ2h0dHA6Ly93d3cu
# bWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY0NvZFNpZ1BDQTIwMTFfMjAxMS0w
# Ny0wOC5jcmwwYQYIKwYBBQUHAQEEVTBTMFEGCCsGAQUFBzAChkVodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY0NvZFNpZ1BDQTIwMTFfMjAx
# MS0wNy0wOC5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG9w0BAQsFAAOCAgEAFkk3
# uSxkTEBh1NtAl7BivIEsAWdgX1qZ+EdZMYbQKasY6IhSLXRMxF1B3OKdR9K/kccp
# kvNcGl8D7YyYS4mhCUMBR+VLrg3f8PUj38A9V5aiY2/Jok7WZFOAmjPRNNGnyeg7
# l0lTiThFqE+2aOs6+heegqAdelGgNJKRHLWRuhGKuLIw5lkgx9Ky+QvZrn/Ddi8u
# TIgWKp+MGG8xY6PBvvjgt9jQShlnPrZ3UY8Bvwy6rynhXBaV0V0TTL0gEx7eh/K1
# o8Miaru6s/7FyqOLeUS4vTHh9TgBL5DtxCYurXbSBVtL1Fj44+Od/6cmC9mmvrti
# yG709Y3Rd3YdJj2f3GJq7Y7KdWq0QYhatKhBeg4fxjhg0yut2g6aM1mxjNPrE48z
# 6HWCNGu9gMK5ZudldRw4a45Z06Aoktof0CqOyTErvq0YjoE4Xpa0+87T/PVUXNqf
# 7Y+qSU7+9LtLQuMYR4w3cSPjuNusvLf9gBnch5RqM7kaDtYWDgLyB42EfsxeMqwK
# WwA+TVi0HrWRqfSx2olbE56hJcEkMjOSKz3sRuupFCX3UroyYf52L+2iVTrda8XW
# esPG62Mnn3T8AuLfzeJFuAbfOSERx7IFZO92UPoXE1uEjL5skl1yTZB3MubgOA4F
# 8KoRNhviFAEST+nG8c8uIsbZeb08SeYQMqjVEmkwggd6MIIFYqADAgECAgphDpDS
# AAAAAAADMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0
# ZSBBdXRob3JpdHkgMjAxMTAeFw0xMTA3MDgyMDU5MDlaFw0yNjA3MDgyMTA5MDla
# MH4xCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMT
# H01pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTEwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQCr8PpyEBwurdhuqoIQTTS68rZYIZ9CGypr6VpQqrgG
# OBoESbp/wwwe3TdrxhLYC/A4wpkGsMg51QEUMULTiQ15ZId+lGAkbK+eSZzpaF7S
# 35tTsgosw6/ZqSuuegmv15ZZymAaBelmdugyUiYSL+erCFDPs0S3XdjELgN1q2jz
# y23zOlyhFvRGuuA4ZKxuZDV4pqBjDy3TQJP4494HDdVceaVJKecNvqATd76UPe/7
# 4ytaEB9NViiienLgEjq3SV7Y7e1DkYPZe7J7hhvZPrGMXeiJT4Qa8qEvWeSQOy2u
# M1jFtz7+MtOzAz2xsq+SOH7SnYAs9U5WkSE1JcM5bmR/U7qcD60ZI4TL9LoDho33
# X/DQUr+MlIe8wCF0JV8YKLbMJyg4JZg5SjbPfLGSrhwjp6lm7GEfauEoSZ1fiOIl
# XdMhSz5SxLVXPyQD8NF6Wy/VI+NwXQ9RRnez+ADhvKwCgl/bwBWzvRvUVUvnOaEP
# 6SNJvBi4RHxF5MHDcnrgcuck379GmcXvwhxX24ON7E1JMKerjt/sW5+v/N2wZuLB
# l4F77dbtS+dJKacTKKanfWeA5opieF+yL4TXV5xcv3coKPHtbcMojyyPQDdPweGF
# RInECUzF1KVDL3SV9274eCBYLBNdYJWaPk8zhNqwiBfenk70lrC8RqBsmNLg1oiM
# CwIDAQABo4IB7TCCAekwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFEhuZOVQ
# BdOCqhc3NyK1bajKdQKVMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1Ud
# DwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFHItOgIxkEO5FAVO
# 4eqnxzHRI4k0MFoGA1UdHwRTMFEwT6BNoEuGSWh0dHA6Ly9jcmwubWljcm9zb2Z0
# LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcmwwXgYIKwYBBQUHAQEEUjBQME4GCCsGAQUFBzAChkJodHRwOi8vd3d3Lm1p
# Y3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcnQwgZ8GA1UdIASBlzCBlDCBkQYJKwYBBAGCNy4DMIGDMD8GCCsGAQUFBwIB
# FjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2RvY3MvcHJpbWFyeWNw
# cy5odG0wQAYIKwYBBQUHAgIwNB4yIB0ATABlAGcAYQBsAF8AcABvAGwAaQBjAHkA
# XwBzAHQAYQB0AGUAbQBlAG4AdAAuIB0wDQYJKoZIhvcNAQELBQADggIBAGfyhqWY
# 4FR5Gi7T2HRnIpsLlhHhY5KZQpZ90nkMkMFlXy4sPvjDctFtg/6+P+gKyju/R6mj
# 82nbY78iNaWXXWWEkH2LRlBV2AySfNIaSxzzPEKLUtCw/WvjPgcuKZvmPRul1LUd
# d5Q54ulkyUQ9eHoj8xN9ppB0g430yyYCRirCihC7pKkFDJvtaPpoLpWgKj8qa1hJ
# Yx8JaW5amJbkg/TAj/NGK978O9C9Ne9uJa7lryft0N3zDq+ZKJeYTQ49C/IIidYf
# wzIY4vDFLc5bnrRJOQrGCsLGra7lstnbFYhRRVg4MnEnGn+x9Cf43iw6IGmYslmJ
# aG5vp7d0w0AFBqYBKig+gj8TTWYLwLNN9eGPfxxvFX1Fp3blQCplo8NdUmKGwx1j
# NpeG39rz+PIWoZon4c2ll9DuXWNB41sHnIc+BncG0QaxdR8UvmFhtfDcxhsEvt9B
# xw4o7t5lL+yX9qFcltgA1qFGvVnzl6UJS0gQmYAf0AApxbGbpT9Fdx41xtKiop96
# eiL6SJUfq/tHI4D1nvi/a7dLl+LrdXga7Oo3mXkYS//WsyNodeav+vyL6wuA6mk7
# r/ww7QRMjt/fdW1jkT3RnVZOT7+AVyKheBEyIXrvQQqxP/uozKRdwaGIm1dxVk5I
# RcBCyZt2WwqASGv9eZ/BvW1taslScxMNelDNMYIZgjCCGX4CAQEwgZUwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMQITMwAAAlKLM6r4lfM52wAAAAACUjAN
# BglghkgBZQMEAgEFAKCBrjAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgSax75veU
# xwwvnnebowyeDXL3hW6LTp7Yk1K6Prhem5IwQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQARoq1/807fPsd4KSDtof4GDR8PmdotItEhUiFu0Gb3
# DzfSwpsFJROXZhBFNpXtITPa7PtuS9mh8hRUjbVkpw8V15U97t/F9b3SaMzuM+F+
# zuA1vgZ9iR2gUHIWsTm5DV/QhTSLorhzU/2xE2Th1sJ6aSQ6L0DNrrYnBeav/1Bz
# +47Y4pEJvMMryY7n3r48yzGpkvEZt3uqUEH/4D67WuCvvPtiatE7FEuISzhnSywy
# Jjh0yw31JKg9X4rYB2YpnvVO/elE/HlRnnn4H2nYMO02w4f4c8WXtXiSvD1K721B
# EQk55QeO3xzjSxC+QkyFhWtYq57zZ7dik1LjEeRA2xrNoYIXDDCCFwgGCisGAQQB
# gjcDAwExghb4MIIW9AYJKoZIhvcNAQcCoIIW5TCCFuECAQMxDzANBglghkgBZQME
# AgEFADCCAVUGCyqGSIb3DQEJEAEEoIIBRASCAUAwggE8AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIEllWbD8ceKd+amx1YXXHOE9xjJrc8pRW4Vy2rxz
# LxAWAgZisbkcM4oYEzIwMjIwNzEzMjE1NjMxLjc4NlowBIACAfSggdSkgdEwgc4x
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKTAnBgNVBAsTIE1p
# Y3Jvc29mdCBPcGVyYXRpb25zIFB1ZXJ0byBSaWNvMSYwJAYDVQQLEx1UaGFsZXMg
# VFNTIEVTTjowQTU2LUUzMjktNEQ0RDElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUt
# U3RhbXAgU2VydmljZaCCEV8wggcQMIIE+KADAgECAhMzAAABpzW7LsJkhVApAAEA
# AAGnMA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNo
# aW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29y
# cG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEw
# MB4XDTIyMDMwMjE4NTEyMloXDTIzMDUxMTE4NTEyMlowgc4xCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVy
# YXRpb25zIFB1ZXJ0byBSaWNvMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjowQTU2
# LUUzMjktNEQ0RDElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2Vydmlj
# ZTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAO0jOMYdUAXecCWm5V6T
# RoQZ4hsPLe0Vp6CwxFiTA5l867fAbDyxnKzdfBsf/0XJVXzIkcvzCESXoklvMDBD
# a97SEv+CuLEIooMbFBH1WeYgmLVO9TbbLStJilNITmQQQ4FB5qzMEsDfpmaZZMWW
# gdOjoSQed9UrjjmcuWsSskntiaUD/VQdQcLMnpeUGc7CQsAYo9HcIMb1H8DTcZ7y
# Ae3aOYf766P2OT553/4hdnJ9Kbp/FfDeUAVYuEc1wZlmbPdRa/uCx4iKXpt80/5w
# oAGSDl8vSNFxi4umXKCkwWHm8GeDZ3tOKzMIcIY/64FtpdqpNwbqGa3GkJToEFPR
# 6D6XJ0WyqebZvOZjMQEeLCJIrSnF4LbkkfkX4D4scjKz92lI9LRurhMPTBEQ6pw3
# iGsEPY+Jrcx/DJmyQWqbpN3FskWu9xhgzYoYsRuisCb5FIMShiallzEzum5xLE4U
# 5fuxEbwk0uY9ZVDNVfEhgiQedcSAd3GWvVM36gtYy6QJfixD7ltwjSm5sVa1voBf
# 2WZgCC3r4RE7VnovlqbCd3nHyXv5+8UGTLq7qRdRQQaBQXekT9UjUubcNS8ZYeZw
# K8d2etD98mSI4MqXcMySRKUJ9OZVQNWzI3LyS5+CjIssBHdv19aM6CjXQuZkkmlZ
# OtMqkLRg1tmhgI61yFC+jxB3AgMBAAGjggE2MIIBMjAdBgNVHQ4EFgQUH2y4fwWY
# LjCFb+EOQgPz9PpaRYMwHwYDVR0jBBgwFoAUn6cVXQBeYl2D9OXSZacbUzUZ6XIw
# XwYDVR0fBFgwVjBUoFKgUIZOaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jcmwvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3Js
# MGwGCCsGAQUFBwEBBGAwXjBcBggrBgEFBQcwAoZQaHR0cDovL3d3dy5taWNyb3Nv
# ZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENB
# JTIwMjAxMCgxKS5jcnQwDAYDVR0TAQH/BAIwADATBgNVHSUEDDAKBggrBgEFBQcD
# CDANBgkqhkiG9w0BAQsFAAOCAgEATxL6MfPZOhR91DHShlzal7B8vOCUvzlvbVha
# 0UzhZfvIcZA/bT3XTXbQPLnIDWlRdjQX7PGkORhX/mpjZCC5J7fD3TJMn9ZQQ8MX
# nJ0sx3/QJIlNgPVaOpk9Yk1YEqyItOyPHr3Om3v/q9h5f5qDk0IMV2taosze0JGl
# M3M5z7bGkDly+TfhH9lI03D/FzLjjzW8EtvcqmmH68QHdTsl84NWGkd2dUlVF2aB
# WMUprb8H9EhPUQcBcpf11IAj+f04yB3ncQLh+P+PSS2kxNLLeRg9CWbmsugplYP1
# D5wW+aH2mdyBlPXZMIaERJFvZUZyD8RfJ8AsE3uU3JSd408QBDaXDUf94Ki3wEXT
# tl8JQItGc3ixRYWNIghraI4h3d/+266OB6d0UM2iBXSqwz8tdj+xSST6G7ZYqxat
# Ezt806T1BBHe9tZ/mr2S52UjJgAVQBgCQiiiixNO27g5Qy4CDS94vT4nfC2lXwLl
# hrAcNqnAJKmRqK8ehI50TTIZGONhdhGcM5xUVeHmeRy9G6ufU6B6Ob0rW6LXY2qT
# LXvgt9/x/XEh1CrnuWeBWa9E307AbePaBopu8+WnXjXy6N01j/AVBq1TyKnQX1nS
# MjU9gZ3EaG8oS/zNM59HK/IhnAzWeVcdBYrq/hsu9JMvBpF+ZEQY2ZWpbEJm7ELl
# /CuRIPAwggdxMIIFWaADAgECAhMzAAAAFcXna54Cm0mZAAAAAAAVMA0GCSqGSIb3
# DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4G
# A1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIw
# MAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAx
# MDAeFw0yMTA5MzAxODIyMjVaFw0zMDA5MzAxODMyMjVaMHwxCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1l
# LVN0YW1wIFBDQSAyMDEwMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA
# 5OGmTOe0ciELeaLL1yR5vQ7VgtP97pwHB9KpbE51yMo1V/YBf2xK4OK9uT4XYDP/
# XE/HZveVU3Fa4n5KWv64NmeFRiMMtY0Tz3cywBAY6GB9alKDRLemjkZrBxTzxXb1
# hlDcwUTIcVxRMTegCjhuje3XD9gmU3w5YQJ6xKr9cmmvHaus9ja+NSZk2pg7uhp7
# M62AW36MEBydUv626GIl3GoPz130/o5Tz9bshVZN7928jaTjkY+yOSxRnOlwaQ3K
# Ni1wjjHINSi947SHJMPgyY9+tVSP3PoFVZhtaDuaRr3tpK56KTesy+uDRedGbsoy
# 1cCGMFxPLOJiss254o2I5JasAUq7vnGpF1tnYN74kpEeHT39IM9zfUGaRnXNxF80
# 3RKJ1v2lIH1+/NmeRd+2ci/bfV+AutuqfjbsNkz2K26oElHovwUDo9Fzpk03dJQc
# NIIP8BDyt0cY7afomXw/TNuvXsLz1dhzPUNOwTM5TI4CvEJoLhDqhFFG4tG9ahha
# YQFzymeiXtcodgLiMxhy16cg8ML6EgrXY28MyTZki1ugpoMhXV8wdJGUlNi5UPkL
# iWHzNgY1GIRH29wb0f2y1BzFa/ZcUlFdEtsluq9QBXpsxREdcu+N+VLEhReTwDwV
# 2xo3xwgVGD94q0W29R6HXtqPnhZyacaue7e3PmriLq0CAwEAAaOCAd0wggHZMBIG
# CSsGAQQBgjcVAQQFAgMBAAEwIwYJKwYBBAGCNxUCBBYEFCqnUv5kxJq+gpE8RjUp
# zxD/LwTuMB0GA1UdDgQWBBSfpxVdAF5iXYP05dJlpxtTNRnpcjBcBgNVHSAEVTBT
# MFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNodHRwOi8vd3d3Lm1pY3Jv
# c29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5odG0wEwYDVR0lBAwwCgYI
# KwYBBQUHAwgwGQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGG
# MA8GA1UdEwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAU1fZWy4/oolxiaNE9lJBb186a
# GMQwVgYDVR0fBE8wTTBLoEmgR4ZFaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3Br
# aS9jcmwvcHJvZHVjdHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMuY3JsMFoGCCsG
# AQUFBwEBBE4wTDBKBggrBgEFBQcwAoY+aHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3BraS9jZXJ0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcnQwDQYJKoZIhvcN
# AQELBQADggIBAJ1VffwqreEsH2cBMSRb4Z5yS/ypb+pcFLY+TkdkeLEGk5c9MTO1
# OdfCcTY/2mRsfNB1OW27DzHkwo/7bNGhlBgi7ulmZzpTTd2YurYeeNg2LpypglYA
# A7AFvonoaeC6Ce5732pvvinLbtg/SHUB2RjebYIM9W0jVOR4U3UkV7ndn/OOPcbz
# aN9l9qRWqveVtihVJ9AkvUCgvxm2EhIRXT0n4ECWOKz3+SmJw7wXsFSFQrP8DJ6L
# GYnn8AtqgcKBGUIZUnWKNsIdw2FzLixre24/LAl4FOmRsqlb30mjdAy87JGA0j3m
# Sj5mO0+7hvoyGtmW9I/2kQH2zsZ0/fZMcm8Qq3UwxTSwethQ/gpY3UA8x1RtnWN0
# SCyxTkctwRQEcb9k+SS+c23Kjgm9swFXSVRk2XPXfx5bRAGOWhmRaw2fpCjcZxko
# JLo4S5pu+yFUa2pFEUep8beuyOiJXk+d0tBMdrVXVAmxaQFEfnyhYWxz/gq77EFm
# PWn9y8FBSX5+k77L+DvktxW/tM4+pTFRhLy/AsGConsXHRWJjXD+57XQKBqJC482
# 2rpM+Zv/Cuk0+CQ1ZyvgDbjmjJnW4SLq8CdCPSWU5nR0W2rRnj7tfqAxM328y+l7
# vzhwRNGQ8cirOoo6CGJ/2XBjU02N7oJtpQUQwXEGahC0HVUzWLOhcGbyoYIC0jCC
# AjsCAQEwgfyhgdSkgdEwgc4xCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVyYXRpb25zIFB1ZXJ0byBSaWNv
# MSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjowQTU2LUUzMjktNEQ0RDElMCMGA1UE
# AxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaIjCgEBMAcGBSsOAwIaAxUA
# wH7vHimSAzeDLN0qzWNb2p2vRH+ggYMwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEG
# A1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWlj
# cm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFt
# cCBQQ0EgMjAxMDANBgkqhkiG9w0BAQUFAAIFAOZ5N+QwIhgPMjAyMjA3MTMxNjI0
# MDRaGA8yMDIyMDcxNDE2MjQwNFowdzA9BgorBgEEAYRZCgQBMS8wLTAKAgUA5nk3
# 5AIBADAKAgEAAgIaeAIB/zAHAgEAAgIRZzAKAgUA5nqJZAIBADA2BgorBgEEAYRZ
# CgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIBAAIDB6EgoQowCAIBAAIDAYagMA0G
# CSqGSIb3DQEBBQUAA4GBAJQNrdW44mK2oDMrM9wGYwm+5m1Kgu5/27HNHr96zPrZ
# 8y5H4sTPCV4jdtUO0+vuLVN3dBGVXHVtM9hVhL4OGlDln6TRXqNh23BmJZwWOGAL
# 0qspfP190tze0TgTmqcjx0fHLKTvSSEyaAbv87ZbkZQD32+vqYLJr2CidQMcj2Cj
# MYIEDTCCBAkCAQEwgZMwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0
# b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3Jh
# dGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMA
# AAGnNbsuwmSFUCkAAQAAAacwDQYJYIZIAWUDBAIBBQCgggFKMBoGCSqGSIb3DQEJ
# AzENBgsqhkiG9w0BCRABBDAvBgkqhkiG9w0BCQQxIgQgC1b2Su2a6JJVCcXzAmon
# 6nKhwbZan6JEdRidVubbvJgwgfoGCyqGSIb3DQEJEAIvMYHqMIHnMIHkMIG9BCBH
# 8H/nCZUC4L0Yqbz3sH3w5kzhwJ4RqCkXXKxNPtqOGzCBmDCBgKR+MHwxCzAJBgNV
# BAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29m
# dCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAABpzW7LsJkhVApAAEAAAGnMCIEIBro
# NKcx9QY+Qq6Igdw6+RygsOPJRjFqFOtjmPkwxVjCMA0GCSqGSIb3DQEBCwUABIIC
# AHhMu6b6byaNPnDz1cxRwFgBEyzB5kfkf67iJFfUMGnmBoRtYRqN+c56uavThjkH
# 1IS2wJu11msZm0uyAYhXLSpkU8FT2BDqNpmr2zM3fYFAKMY+WoF8p/AVovvkM7BE
# BjRMB90mDytDN1b5G081BCdTNg3j3tyJgizz/9UUC/RKqNXpDdWWYluPa/9HR6/d
# 5bJ3qZ0tVCg7CCNRShhEIVlB/SbdBMuG3mvTYhg5aI/whRyTtm00HQqdcuIu8b0N
# FUpwXRNZoQ3nSmk/3AJuv3ElDQPSs44VJLBrPRb0Gvb7zpl8mI7th8SF5Dz9zemB
# g4XtUEl/OxckUwQ/+qX5wXL9NzJ5My51+qQ5m9HtMF0cxeSodveF8DYstM/j+wkZ
# Oe6DWR/28Z3XaDj757IU2fx1Z8hFbRGOpU1JBmGqPsbD4oaLQXNKoxxQxTGvzT4X
# XlKoH6XfvYjjCbrZEEsOOJMoRQ33Rx1iSU6DMSnzj0MYxJc1QcbXjij8S0JuL9rn
# roWveQyeJybEIov2njpixgMW+z64wC0rCliCagdm0oBzXaNOSvu5+l2Tf6FxPJWg
# sSwqK6o7JoBhFv6noQs7l01sEJPJfDxrZFcD5dc2vPvYVA7bebdoBAVfsWmrcHQq
# T3rbbzaPO91vnPq4S8Rt83pIV0jdmc75nXAF7PrUeg5f
# SIG # End signature block