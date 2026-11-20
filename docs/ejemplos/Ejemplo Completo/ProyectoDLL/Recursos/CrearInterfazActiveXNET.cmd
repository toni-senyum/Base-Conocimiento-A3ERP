rem "C:\Program Files (x86)\Microsoft SDKs\Windows\v7.0A\Bin\tlbimp" "C:\Program Files (x86)\A3\A3erp\interface\a3ERPActiveX.tlb" /out:$(ProjectDir)a3ERPActiveX.dll

"C:\Program Files (x86)\Microsoft SDKs\Windows\v7.0A\Bin\tlbimp" "C:\Program Files (x86)\A3\A3erp\interface\a3ERPActiveX.tlb" /out:..\a3ERPActiveXNET.dll
"C:\Program Files (x86)\Microsoft SDKs\Windows\v7.0A\Bin\tlbimp" "C:\Program Files (x86)\A3\A3erp\interface\a3ERPExtensibilityServices.tlb" /out:..\a3ERPExtensibilityServicesNET.dll

pause

