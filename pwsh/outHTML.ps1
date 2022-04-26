$HtmlStyle = @"
<style>
body {
	font-family:Arial, Helvetica, sans-serif;
	margin:10px;
	padding:10px;
	background-color:#EBE8ED;}
table {
	font-family:Arial, Helvetica, sans-serif;
	font-size:1.0em;
	line-height:1.0em;
	font-weight:normal;
	color:#342a3e;
	background-color:#EBE8ED;
	width:100%;
	padding:5px;
	Border:3px;
	Border-collapse: collapse;
	border-style:solid;
	border-color:#342a3e;}
th {
	font-family:Arial, Helvetica, sans-serif;
	font-size:0.95em;
	font-weight:bold;
	background-color:#FFCC00;
	width:auto;
	margin:1px;
	padding:3px;
	Border:1px;
	border-style:solid;
	border-color:#342a3e;}
td {
	font-family:Arial, Helvetica, sans-serif;
	font-size:0.9em;
	font-weight:normal;
    white-space: pre-wrap;
    word-wrap: break-word;
	background-color:#EBE8ED;
	width:auto;
	margin:1px;
	padding:3px;
	Border:1px;
	border-style:solid;
	border-color:#342a3e;}
.footer { 
    margin:1px;
	padding-top:20px;
    padding-left:3px;
    padding-rght:3px;
    font-size:0.9em;
}
</Style>
"@

function out-HtmlPage {
    [CmdletBinding()]
    param (
        [string]$Title="Out-HtmlPage v1.0",
        [Parameter(Mandatory = $true,ValueFromPipeline = $true)]
        [Object[]]$Body,
        [string]$Footer
    )     

    Begin {
        $HTMLHead = "<Title>$STitle</Title> `n $HTMLStyle"
        $Now = [DateTime]::now
        $HTML = "<h2>Html Page Viewer @ $now </h2>`n"
        $HTML +="<div>`n"
        $HTMLFooter = "</div>`n<div class=footer>$Footer</div>"
        $buffer = @()
    }
    Process {
        Write-host "body $($Body)"
        $buffer += $Body
    }
    End {
        #Generate the HTML Report
        $HTMLOut = $Buffer | Convertto-HTML  -head $HTMLHead -precontent $HTML -PostContent $HTMLFooter
        $HTMLOut | Set-Content -Path "/tmp/myfile.html"
        invoke-item "/tmp/myfile.html"
    }
}

function test-pipe {
    Param (
        [Parameter(Mandatory,ValueFromPipeline = $true)]
        [Object[]]$InputObject
    )

    Begin {
        # Need to collect the Pipeline for the Body
        $body = [System.Collections.Generic.List[Object]]::new()
    }
    Process {
        # Process Pipe
        write-host "Pipe $($_)"
        $body.Add($_)
    }
    End {
        return $body
    }
    
}
