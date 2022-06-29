$DTD = @'
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
'@

$HTMLStyle = @'
body {
	font-family:Arial, Helvetica, sans-serif;
	margin:10px;
	padding:10px;
    font-size:1.0em;
	line-height:1.0em;
	font-weight:normal;
	background-color:#white}
table {
    font-family: Arial, Helvetica, sans-serif;
    border-collapse: collapse;
    background-color:#fcfcfc;
    width: 100%;}
td, th {
    border: 1px solid #ddd;
    white-space: nowrap;
    padding: 5px;}
tr:nth-child(even) {
    background-color: #d1d1d1}
tr:hover {
    background-color: #3db5e6;}    
th {
    padding-top: 12px;
    padding-bottom: 12px;
    text-align: left;
    background-color: #185a7d;
    color: white;
  }
.logentry {
    white-space: pre-wrap;
    word-wrap: break-word;
    word-break: break-all !important;}
footer { 
    margin:1px;
	padding-top:20px;
    padding-left:3px;
    padding-rght:3px;
    font-size:1.1em;}
'@

<#Classmap works like so - Add a Key-Value pair to the ClassMap
  Key is the property name (in the example above the message Property)
  Value is the classname in the style sheet HereString (in the example above logentry)
  So now all properties names message will be assigned class logentry
#>
$ClassMap = @{}
$ClassMap.Add("message","logentry")
$ClassMap.Add("output","logentry")

function test-pipe {
    Param (
        [Parameter(Mandatory,ValueFromPipeline = $true)]
        [Object[]]$InputObject
    )

    Begin {
        # Need to collect the Pipeline for the Body
        if ($InputObject) {Write-Host "Have a Named Input Object"}
        $body = [System.Collections.Generic.List[Object]]::new()
    }
    Process {
        # Process Pipe
        write-host "Pipe $($InputObject)"
        $InputObject | Foreach-Object {$body.Add($_)}
    }
    End {
        write-Host "Pipeline object $($body.count)"
        return $body
    }
    
}

Function Out-HtmlPage { 
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true,ValueFromPipeline = $true)]
        [Object[]]$InputObject,
        [String]$Title,
        [String]$Style=$Script:HtmlStyle,
        [Hashtable]$ClassMap=$Script:ClassMap,
        [Object]$Footer="MorpheusData.com Out-HTMLPage",
        [String]$Path=$null
    )

    Begin {
        $html = [System.Text.StringBuilder]::new()
        #Transitional DocType
        [void]$html.AppendLine($Script:DTD)
        #Head
        [void]$html.AppendLine('<head>')
        [void]$html.AppendFormat('<title>{0}</title>',$Title).AppendLine()
        [void]$html.AppendFormat('<style type="text/css">{0}</style>',$Style).AppendLine()
        [void]$html.AppendLine('</head>')
        [void]$html.AppendLine('<body>')
        [void]$html.AppendLine('<div>')
        [void]$html.AppendFormat('<h2>{0} @ {1}</h2>',$Title,[DateTime]::now).AppendLine()

        # Need to collect the Pipeline for the Body
        $TableData= [System.Collections.Generic.List[Object]]::new()
    }
    Process {
        # Collect the Pipe
        $InputObject | Foreach-Object {$TableData.Add($_)}
    }
    End {
        $table = Make-HTMLTable -InputObject $TableData -ClassMap $ClassMap
        [void]$html.Append($table).AppendLine()
        [void]$html.AppendLine('</div>')
        [void]$html.AppendFormat('<div><footer>{0}</footer></div>',$Footer).AppendLine()
        [void]$html.AppendLine('</body>')
        [void]$html.AppendLine('</html>')
        #Generate the HTML Report
        if (-Not $Path) {
            if ([Environment]::OSVersion.Platform -eq [PlatformId]::Unix) {
                $Path = Join-Path -Path ([Environment]::GetEnvironmentVariable("HOME")) -ChildPath "outhtmlpage.html"
            } else {
                $Path = Join-Path -Path ([Environment]::GetEnvironmentVariable("TEMP")) -ChildPath "outhtmlpage.html"
            }
        }
        $html.ToString() | Set-Content -Path $Path
        invoke-item $Path
    }
}

Function Make-HTMLTable {
    [CmdletBinding()]
    Param (
        [Object]$InputObject,
        [string[]]$Headers=@(),
        [Hashtable]$ClassMap=$Script:ClassMap
    )
    #Create html table with optional headers (must match number of columns)
    #If InputObject property is a valid key in $ClassMap the specified class is used for that cell

    #Make <table>
    #make <thead><Tr><td> etx
    #make <tbody>
    #make <tr><td></td> .... </tr>
    #make </tbody>
    #make </table>

    $Properties = $InputObject | Select-Object -First 1 | Foreach-Object {$_.PSObject.Properties.Name}
    if (-Not $Headers) {
        $Headers = $Properties
    }

    #Use a StringBuilder class 
    $html = [System.Text.StringBuilder]::new()
    #<table>
    [void]$html.AppendLine('<table>')
    [void]$html.Append('<thead>')
    [void]$html.Append('<tr>')
    $Headers | Foreach-Object {[void]$Html.AppendFormat('<th>{0}</th>',$_)}
    [void]$html.Append('</tr>').AppendLine()
    [void]$html.AppendLine('</thead>')
    [void]$html.AppendLine('<tbody>')

    # Construct the table body from the InputObject.
    # Each Cell can be assigned a class by looking up property name in $ClassMap
    foreach ($item in $InputObject) {
        [void]$html.Append('<tr>')
        foreach ($property in  $item.PSObject.Properties) {
            $class = if ($ClassMap.contains($property.name)) {$ClassMap.item($property.name)} else {$null}
            if ($property.value) {
                $cell = [System.Web.HttpUtility]::HtmlEncode($property.value)
                if ($class) {
                    [void]$html.AppendFormat('<td class="{1}">{0}</td>',$cell,$class)
                } else {
                    [void]$html.AppendFormat('<td>{0}</td>',$cell)
                }
            } else {
                if ($class) {
                    [void]$html.AppendFormat('<td class="{1}"></td>',$cell,$class)
                } else {
                    [void]$html.AppendFormat('<td></td>',$cell)
                }
            }
        }
        [void]$html.AppendLine('</tr>') 
    }
    [void]$html.AppendLine('</tbody>')
    [void]$html.AppendLine('</table>')
    return $html.ToString()
}