###############
###VARIABLES###
###############
# Clears LogArray
$logArray = @()
# Clears DisabledUsers Variable
$disabledUser = @()
# Variable for filename
$logDate = Get-Date -f MMddyyyy
# Variable for 90days
$90days = (Get-Date).adddays(-90)
# OU Variable for Disabled OU
$OUDisabled =  '# [NAME OF OU FOR DISBALED USERS]'
# Log file for list of disabled users
$logFinal = "# [NAME OF LOG FILE THAT CONTAINS A LIST OF ALL DISABLED USERS]"
# Log file for group membership
$logGrpMem = "# {NAME OF LOG FILE THAT SAVES INACTIVE USER'S GROUP MEMBERSHIP]"

##########################
###FINDS INACTIVE USERS###
##########################
$inactive = get-qaduser | where {$_.lastlogontimestamp -lt $90days} | select-object samaccountname,lastlogon,lastlogontimestamp | sort-object samaccountname
# CONVERTS OLDUSER HASH TO AN ARRAY
$alloldusers = @()
foreach ($User in $inactive){
$alloldusers += ($user).samaccountname
}

#######################################
###REMOVES ALREADY DISABLED ACCOUNTS###
#######################################
$oldusers = $alloldusers
foreach($user in $oldusers){
if((get-qaduser $user).accountisdisabled -eq $true){
$oldusers = @($oldusers | ? {$_ -ne $user})}
}

###########################
###LOGS GROUP MEMBERSHIP###
###########################
# CREATES NEW FOLDER BASED ON THE DATE FOR GROUP MEMBERSHIP
new-item $LogGrpMem -type directory
# VARIABLE FOR NEWLY CREATED FOLDER
$dir = $LogGrpMem
# DOCUMENTS GROUP MEMBERSHIP
foreach($user in $oldusers){
$name = @()
$name = get-qaduser $user | get-qadmemberof | select-object groupname,DN
$name | export-csv $("$dir\" + $user + ".csv") -NoTypeInformation
}

##############################################
###GETS VARIABLE FOR DISABLED USER ACCOUNTS###
##############################################
$gad = @()
foreach($person in $oldusers){
$given = get-aduser $person
$gad += $given
}

###############################################
###MOVES AND DISABLES INACTIVE USER ACCOUNTS###
###############################################
# LOOPS ADDING DESCRIPTION, DISABLING ACCOUNT AND LOGGING
ForEach ($DisabledUser in $gad) {
# SETS USER's 'DESCRIPTION' AS A DATE
  set-aduser $DisabledUser -Description ((get-date).toshortdatestring())
# DISABLES USER'S ACCOUNT
  Disable-ADAccount $DisabledUser
# MOVES USER TO 'DISABLED' OU
  Move-ADObject -identity $DisabledUser –TargetPath $OUDisabled
# LOGGING
	$obj = New-Object PSObject

    $obj | Add-Member -MemberType NoteProperty -Name "Name" -Value $DisabledUser.name

    $obj | Add-Member -MemberType NoteProperty -Name "samAccountName" -Value $DisabledUser.samaccountname

    $obj | Add-Member -MemberType NoteProperty -Name "DistinguishedName" -Value $DisabledUser.DistinguishedName

    $obj | Add-Member -MemberType NoteProperty -Name "Status" -Value 'Disabled'
	
	$obj | Add-Member -MemberType NoteProperty -Name "Date" -value ((get-date).toshortdatestring())

    $LogArray += $obj  
} 

###################################
###REMOVES USER GROUP MEMBERSHIP###
###################################
foreach ($User in $oldusers){
(Get-Qaduser $user).memberof | Get-Qadgroup | Where {$_.name -ne "Domain Users"} | Remove-Qadgroupmember -member $User
}

############################################################
###SAVES LOG FILE FOR ALL DISABLED INACTIVE USER ACCOUNTS###
############################################################
$logarray | export-csv $LogFinal -NoTypeInformation