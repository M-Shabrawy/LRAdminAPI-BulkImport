Function TrustAllCerts
{
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Ssl3, [Net.SecurityProtocolType]::Tls, [Net.SecurityProtocolType]::Tls11, [Net.SecurityProtocolType]::Tls12
}

Function Get-FileName($initialDirectory)
{  
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.Title = "Select Users file to import, file format it should be First,Middle,Last,Username"
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = "Comm-Separtaed (*.csv)| *.csv"
    $OpenFileDialog.ShowDialog() | Out-Null
    $FileName = $OpenFileDialog.filename
    if($FileName -eq "")
    {
        exit 1
    }
    else
    {
        return $FileName
    }
}


Function Get-CSV($CSVFileName)
{
    try
    {
        $CSV = Import-Csv -Path $CSVFileName
        return $CSV
     }
     catch
     {
        Write-Error "Exception $_.Exception.Message"
        exit 1
     }
}

Function BuildJSON
{
    param(
        [string]$first,
        [string]$middle,
        [string]$last,
        [string]$username,
        [string]$title
    )
    $GUID = [guid]::NewGuid()
    $source = @()
    $source += [pscustomobject]@{
        "AccountName" = "$first $middle $last"
        "IAMName" = "CSV"
    }
    $identifiers = @()
    $identifiers += [pscustomobject]@{
        "identifierType" = "Login"
        "value" = "$username"
        "recordStatus"= "New"
    }

    $accounts = @()
    $accounts += [pscustomobject]@{
        "thumbnailPhoto" = ""
        "vendorUniqueKey" = $GUID
        "hasOwnerIdentity" = $true
        "hasSameRootEntityAsTarget" = $true
        "isPrimary" = $true
        "accountType" = "Custom"
        "login" = "$username"
        "nameFirst" = "$first"
        "nameMiddle" = "$middle"
        "nameLast"= "$last"
        #"company" = ""
        #"department" = "string"
        "title" = "$title"
        #"manager" = "string"
        #"addressCity" = "string"
        #"domainName" = "string"
        "identifiers" = $identifiers
    }

    $JSONDoc = [pscustomobject]@{
        "friendlyName" = "API"
        "accounts" = $accounts
    }

    $JSON = ($JSONDoc | ConvertTo-Json -Depth 5)
    #Write-Host $JSON
    return $JSON
}



##Main
$token = Read-Host -Prompt "Please input API Token genrated from Client Console"

$PMHost = Read-Host -Prompt "Please input PM Host IP/Name (localhost) to keep default hit Enter"
if($PMHost -eq "")
{
    $apiUrl = "http://localhost:8505"
}
else
{
    $apiUrl = "https://" + $PMHost + ":8501"
    TrustAllCerts
}
Write-Host $apiUrl

write-host "Please select CSV file CSV, file format it should be First,Middle,Last,Username"
$CSVFileName = Get-FileName([System.IO.Directory]::GetCurrentDirectory())
$CSVDoc = Get-CSV($CSVFileName)

#Write-Host $CSVDoc.Count

#Invoke-WebRequest -Uri http://$apiURL/lr-admin-api/identities/$id/ -Headers @{"Authorization" = "Bearer $token"} -ContentType "application/json" -Method GET -UseBasicParsing

foreach ($Entry in $CSVDoc)
{
    [string]$F = $($Entry.Firstname)
    [string]$M = $($Entry.Middlename)
    [string]$L = $($Entry.Lastname)
    [string]$U = $($Entry.Username)
    [string]$T = $($Entry.Title)
    
    $IdJSON = BuildJSON $F $M $L $U $T
    
    Write-Host $IdJSON
    #Add Identity to default Entity
    $result = Invoke-WebRequest -Uri $apiURL/lr-admin-api/identities/bulk?entityID=1 -Headers @{"Authorization" = "Bearer $token"} -ContentType 'application/json' -Method Post -Body $IdJSON
    
    Write-host $result 
}
