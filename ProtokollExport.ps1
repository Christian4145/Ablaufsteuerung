<#***************************************************************************************************
$Rev:: 2529                                         $: Revision des letzten commit
$Author:: wolfa015                                  $:    Autor des letzten commit
$Date:: 2018-02-28 14:42:57 +0100 (Mi, 28 Feb 2018) $:    Datum des letzten commit
****************************************************************************************************
Dieses Modul exportiert die Tabelle tp_dim_protokoll in eine Excel-Datei

Ubergabeparameter sind:
-SQLSERVER Server
-DB_WORK   Datenbank
**************************************************************************************************#>
param(
	[string]$SQLSERVER = "N2048017\SQL2012"
,	[string]$DB_WORK   = "dev_wolf_01"
)

$d=Get-Location

# Aktuelles Verzeichnis holen
$DirectoryToSaveTo = Split-Path $($MyInvocation.InvocationName) -Parent
$filename = $DirectoryToSaveTo + "\Protokoll.xlsx"
 
# constants. 
$xlCenter=-4108 
$xlTop=-4160 
$xlOpenXMLWorkbook=[int]51 
# and we put the queries in here 
 
# You can replace the SQL 
 
$SQL=@"
SELECT *
FROM dbo.tp_dim_protokoll 
WHERE lauf = ( SELECT lauf
               FROM dbo.tp_dim_protokoll
               WHERE stamp = ( SELECT MAX ( stamp )
                               FROM dbo.tp_dim_protokoll
                             )
             )
ORDER BY stamp DESC, nr DESC;
"@ 
 
# Create a Excel file to save the data
$excel = New-Object -Com Excel.Application #open a new instance of Excel 
#$excel.Visible = $True #make it visible (for debugging) 
$wb = $Excel.Workbooks.Add() #create a workbook 
$ws = $wb.Worksheets.Item(1)

$qt = $ws.QueryTables.Add( "OLEDB;Provider=SQLOLEDB.1;Integrated Security=SSPI;Persist Security Info=True;Initial Catalog=" + $DB_WORK + ";Data Source=" + $SQLSERVER, $ws.Range("A1"), $SQL ) 

# and execute it 
if ($qt.Refresh()) #if the routine works OK 
    { 
    $ws.Activate() 
    $ws.Select() 
    $excel.Rows.Item(1).HorizontalAlignment = $xlCenter 
    $excel.Rows.Item(1).VerticalAlignment = $xlTop 
    #$excel.Rows.Item("1:1").Font.Name = "Calibri" 
    #$excel.Rows.Item("1:1").Font.Size = 11 
    $excel.Rows.Item("1:1").Font.Bold = $true 
    #$Excel.Columns.Item(1).Font.Bold = $true 
    } 

if (test-path $filename ) { rm $filename } #delete the file if it already exists 
$wb.SaveAs($filename,  $xlOpenXMLWorkbook) #save as an XML Workbook (xslx)

$wb.Saved = $True   # flag it as being saved 
$wb.Close()         # close the document 
$Excel.Quit()       # and the instance of Excel 
$wb    = $Null      # set all variables that point to Excel objects to null 
$ws    = $Null      # makes sure Excel deflates 
$Excel = $Null