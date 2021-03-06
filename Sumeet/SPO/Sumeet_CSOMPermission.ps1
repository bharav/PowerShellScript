Clear-Host
$host.Runspace.ThreadOptions = "ReuseThread"
Add-PsSnapin Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue
Add-Type -Path "C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions\16\ISAPI\Microsoft.SharePoint.Client.dll"
Add-Type -Path "C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions\16\ISAPI\Microsoft.SharePoint.Client.Runtime.dll"
Add-Type -Path "C:\Program Files\SharePoint Client Components\16.0\Assemblies\Microsoft.Online.SharePoint.Client.Tenant.dll"
$pLoadCSOMProperties=(get-location).ToString()+"\Load-CSOMProperties.ps1"
. $pLoadCSOMProperties
$siteexclusion = (get-location).ToString()+"\siteexclusion.csv"

$properties=@{SiteUrl='';SiteTitle='';ListTitle='';Type='';RelativeUrl='';ParentGroup='';MemberType='';MemberName='';MemberLoginName='';Roles='';}; 
$UserInfoList=""; 
$RootWeb=""; 
$RootSiteTitle="";
$ExportFileDirectory = (get-location).ToString();
#OutPut and Log Files
$todayDateTime = Get-Date -format "yyyyMMMdd_hhmmss"
$exportFilePath = Join-Path -Path $ExportFileDirectory -ChildPath $([string]::Concat("Tenant-Permissions_",$todayDateTime,".csv"));


$TenantAdminUrl = Read-Host -Prompt "Enter Tenant Admin URL: ";
$Username =  Read-Host -Prompt "Enter userName for tenant admin: ";
$password = Read-Host -Prompt "Enter password for tenant admin: " -AsSecureString ;
$loginName = Read-Host -Prompt "Enter loginName for user to check for: ";
$DeleteUser = Read-Host -Prompt "Enter Yes/No if user should be removed;"
$NavigateItemLevel = Read-Host -Prompt "Enter Yes/No if script need to be run on item level;"



#Initialization of Permission Object

Function PermissionObject($_object,$_type,$_relativeUrl,$_siteUrl,$_siteTitle,$_listTitle,$_memberType,$_parentGroup,$_memberName,$_memberLoginName,$_roleDefinitionBindings)
{
    $permission = New-Object -TypeName PSObject -Property $properties; 
    $permission.SiteUrl =$_siteUrl; 
    $permission.SiteTitle = $_siteTitle; 
    $permission.ListTitle = $_listTitle; 
    $permission.Type = $_type; 
    $permission.RelativeUrl = $_relativeUrl; 
    $permission.MemberType = $_memberType; 
    $permission.ParentGroup = $_parentGroup; 
    $permission.MemberName = $_memberName; 
    $permission.MemberLoginName = $_memberLoginName; 
    $permission.Roles = $_roleDefinitionBindings -join ","; 

   ## Write-Host  "Site URL: " $_siteUrl  "Site Title"  $_siteTitle  "List Title" $_istTitle "Member Type" $_memberType "Relative URL" $_RelativeUrl "Member Name" $_memberName "Role Definition" $_roleDefinitionBindings -Foregroundcolor "Green";
    return $permission;
}

##Function to get the unique permission
Function QueryUniquePermissionsByObject($_web,$_object,$_Type,$_RelativeUrl,$_siteUrl,$_siteTitle,$_listTitle)
{
		try
		{
		  $_permissions =@();
		  Load-CSOMProperties -object $_object -propertyNames @("RoleAssignments") ;
		  $ctx.ExecuteQuery() ;
		  foreach($roleAssign in $_object.RoleAssignments)	{
		      $RoleDefinitionBindings=@(); 
		      Load-CSOMProperties -object $roleAssign -propertyNames @("RoleDefinitionBindings","Member");
		      $ctx.ExecuteQuery() ;
		      $roleAssign.RoleDefinitionBindings|%{ 
		      Load-CSOMProperties -object $_ -propertyNames @("Name");
		      $ctx.ExecuteQuery() ;
		      $RoleDefinitionBindings += $_.Name; 
		    }
		 
		    $MemberType = $roleAssign.Member.GetType().Name; 
		    $collGroups = "";
		      if($_Type  -eq "Site")
		      {
		          $collGroups = $_web.SiteGroups;
		          $ctx.Load($collGroups);
		          $ctx.ExecuteQuery() ;
		      }

		   if($MemberType -eq "Group" -or $MemberType -eq "User")
		    { 
		 
		        Load-CSOMProperties -object $roleAssign.Member -propertyNames @("LoginName","Title");
		        $ctx.ExecuteQuery() ;    
		   
		        $MemberName = $roleAssign.Member.Title; 
		        $MemberLoginName = $roleAssign.Member.LoginName;    
				
			        if($MemberType -eq "User")
			        {
			         $ParentGroup = "NA";
			        }
			        else
			        {
			         $ParentGroup = $MemberName;
			        }
					#Check for the username provided
				 	if($MemberLoginName -like "*"+$loginName+"*")
					{
				        $_permissions += (PermissionObject $_object $_Type $_RelativeUrl $_siteUrl $_siteTitle $_listTitle $MemberType $ParentGroup $MemberName $MemberLoginName $RoleDefinitionBindings); 
						
						#Delete user if user selected to remove user permission
						if($DeleteUser.ToLower() -eq "yes")
						{
							Write-Host "Removing user permissio"
							$roleAssign.RoleDefinitionBindings.RemoveAll();;
							$roleAssign.update();
							$ctx.ExecuteQuery() ;
						}
						
					}
		     		if($_Type  -eq "Site" -and $MemberType -eq "Group")
				       {
				          foreach($group in $collGroups)
				          {
				            if($group.Title -eq $MemberName)
				             {
					              $ctx.Load($group.Users);
					              $ctx.ExecuteQuery() ;  
					               ##Write-Host "Number of users" $group.Users.Count;
					              $group.Users|%{ 
						              Load-CSOMProperties -object $_ -propertyNames @("LoginName");
						              $ctx.ExecuteQuery() ; 
									  #Check you username provided
						           	  if($_.LoginName -like "*"+$loginName+"*"){
						              $_permissions += (PermissionObject $_object "Site" $_RelativeUrl $_siteUrl $_siteTitle "" "GroupMember" $group.Title $_.Title $_.LoginName $RoleDefinitionBindings); 
						                  ##Write-Host  $permissions.Count
										  #Delete user if user selected to remove user permission
										  if($DeleteUser.ToLower() -eq "yes")
										  {
										  		Write-Host "Removing user permissio"
												$group.Users.Remove($_);
												$group.Update();
												$_web.Update();
												$ctx.ExecuteQuery() ; 
										  }
					                 }
				               }
				          }
				       }
		        }
		     }
		      
		   }
		  return $_permissions;
	}
		catch [System.Exception]
		{
		    write-host -f red $_.Exception.ToString()   
		}
}

#Function to query permission on web object 
Function QueryUniquePermissions($_web)
 {
 try{
		  ##query list, files and items unique permissions
		  $permissions =@();
		  
		  $siteUrl = $_web.Url; 
		 
		  $siteRelativeUrl = $_web.ServerRelativeUrl; 
		  Write-Host "Started check permission on web " +  $_web.Title + " Url" + $siteUrl ;
		 
		  $siteTitle = $_web.Title; 

		  Load-CSOMProperties -object $_web -propertyNames @("HasUniqueRoleAssignments");
		  $ctx.ExecuteQuery()
		 ## See more at: https://www.itunity.com/article/loading-specific-values-lambda-expressions-sharepoint-csom-api-windows-powershell-1249#sthash.2ncW42CM.dpuf
		 #Get Site Level Permissions if it's unique  
		 
		  if($_web.HasUniqueRoleAssignments -eq $True){ 
		     $permissions += (QueryUniquePermissionsByObject $_web $_web "Site" $siteRelativeUrl $siteUrl $siteTitle "");
		    }
		   
		    #Get all lists in web
		  $ll=$_web.Lists
		  $ctx.Load($ll);
		  $ctx.ExecuteQuery()

		  Write-Host "Number of lists" + $ll.Count
		  $icount = 0;

		  foreach($list in $ll)
		  {      
		    Load-CSOMProperties -object $list -propertyNames @("RootFolder","Hidden","HasUniqueRoleAssignments");
		    $ctx.ExecuteQuery()
		 
		    $listUrl = $list.RootFolder.ServerRelativeUrl; 
		  	Write-Host "Started check permission on list with Url" + $listUrl ;
		    #Exclude internal system lists and check if it has unique permissions 
		 
		    if($list.Hidden -ne $True)
		    { 
		      Write-Host $list.Title  -Foregroundcolor "Yellow"; 
		      $listTitle = $list.Title; 
		    #Check List Permissions 

		    if($list.HasUniqueRoleAssignments -eq $True)
		    { 
			   Write-Host "List has unique permission " + $listUrl ;
		       $Type = $list.BaseType.ToString(); 
		       $permissions += (QueryUniquePermissionsByObject $_web $list $Type $listUrl $siteUrl $siteTitle  $listTitle);
		 	   if($NavigateItemLevel.ToLower() -eq "yes")
			   {
			       if($list.BaseType -eq "DocumentLibrary")
			       { 
			            #TODO Get permissions on folders 
			           $rootFolder =  $list.RootFolder;
			           $listFolders = $rootFolder.Folders;
			           $ctx.Load($rootFolder);
			           $ctx.Load( $listFolders);
			       
			           $ctx.ExecuteQuery() ;
			   
			           #get all items 

			            $spQuery =  New-Object Microsoft.SharePoint.Client.CamlQuery
			            $spQuery.ViewXml = "<View>
			                    <RowLimit>2000</RowLimit>
			                </View>"
			            ## array of items
			             $collListItem = @();

			            do
			            {
			                $listItems = $list.GetItems($spQuery);
			                $ctx.Load($listItems);
			                $ctx.ExecuteQuery() ;
			                $spQuery.ListItemCollectionPosition = $listItems.ListItemCollectionPosition
			                foreach($item in $listItems)
			                {
			                    $collListItem +=$item 
			                }
			            }
			            while ($spQuery.ListItemCollectionPosition -ne $null)

			            Write-Host  $collListItem.Count 

			            foreach($item in $collListItem) 
			            {
			                Load-CSOMProperties -object $item -propertyNames @("File","HasUniqueRoleAssignments");
			                $ctx.ExecuteQuery() ;  
			        
			                Load-CSOMProperties -object $item.File -propertyNames @("ServerRelativeUrl");
			                $ctx.ExecuteQuery() ;  

			                $fileUrl = $item.File.ServerRelativeUrl; 
			 
			                $file=$item.File; 
			 				Write-Host "Started check permission on item with id" + $item.id ;
			                if($item.HasUniqueRoleAssignments -eq $True)
			                { 
			                  $Type = $file.GetType().Name; 
							  Write-Host "Item with Id " + $item.id + " has unique permission";
			                  $permissions += (QueryUniquePermissionsByObject $_web $item $Type $fileUrl $siteUrl $siteTitle $listTitle);
			                } 
			             } 
			        } 
				}
		    } 
			else
			{
			 if($NavigateItemLevel.ToLower() -eq "yes")
			   {
				 if($list.BaseType -ne "DocumentLibrary")
			       {
						$spQuery =  New-Object Microsoft.SharePoint.Client.CamlQuery
			            $spQuery.ViewXml = "<View>
			                    <RowLimit>2000</RowLimit>
			                </View>"
			            ## array of items
			             $collListItem = @();

			            do
			            {
			                $listItems = $list.GetItems($spQuery);
			                $ctx.Load($listItems);
			                $ctx.ExecuteQuery() ;
			                $spQuery.ListItemCollectionPosition = $listItems.ListItemCollectionPosition
			                foreach($item in $listItems)
			                {
			                    $collListItem +=$item 
			                }
			            }
			            while ($spQuery.ListItemCollectionPosition -ne $null)

			            Write-Host  $collListItem.Count 

			            foreach($item in $collListItem) 
			            {
			                Load-CSOMProperties -object $item -propertyNames @("File","HasUniqueRoleAssignments");
			                $ctx.ExecuteQuery() ;  
			        
			                Load-CSOMProperties -object $item.File -propertyNames @("ServerRelativeUrl");
			                $ctx.ExecuteQuery() ;  

			                $fileUrl = $item.File.ServerRelativeUrl; 
			 
			                $file=$item.File; 
			 				Write-Host "Started check permission on item with id" + $item.id ;
			                if($item.HasUniqueRoleAssignments -eq $True)
			                { 
			                  $Type = $file.GetType().Name; 
							  Write-Host "Item with Id " + $item.id + " has unique permission";	
			                  $permissions += (QueryUniquePermissionsByObject $_web $item $Type $fileUrl $siteUrl $siteTitle $listTitle);
			                } 
			             }
					}
				 elseif($list.BaseType -eq "DocumentLibrary")
			       { 
			           #TODO Get permissions on folders 
			           $rootFolder =  $list.RootFolder;
			           $listFolders = $rootFolder.Folders;
			           $ctx.Load($rootFolder);
			           $ctx.Load( $listFolders);
			       
			           $ctx.ExecuteQuery() ;
			   
			           #get all items 

			            $spQuery =  New-Object Microsoft.SharePoint.Client.CamlQuery
			            $spQuery.ViewXml = "<View>
			                    <RowLimit>2000</RowLimit>
			                </View>"
			            ## array of items
			             $collListItem = @();

			            do
			            {
			                $listItems = $list.GetItems($spQuery);
			                $ctx.Load($listItems);
			                $ctx.ExecuteQuery() ;
			                $spQuery.ListItemCollectionPosition = $listItems.ListItemCollectionPosition
			                foreach($item in $listItems)
			                {
			                    $collListItem +=$item 
			                }
			            }
			            while ($spQuery.ListItemCollectionPosition -ne $null)

			            Write-Host  $collListItem.Count 

			            foreach($item in $collListItem) 
			            {
			                Load-CSOMProperties -object $item -propertyNames @("File","HasUniqueRoleAssignments");
			                $ctx.ExecuteQuery() ;  
			        
			                Load-CSOMProperties -object $item.File -propertyNames @("ServerRelativeUrl");
			                $ctx.ExecuteQuery() ;  

			                $fileUrl = $item.File.ServerRelativeUrl; 
			 
			                $file=$item.File; 
			 				Write-Host "Started check permission on item with id" + $item.id ;
			                if($item.HasUniqueRoleAssignments -eq $True)
			                { 
			                  $Type = $file.GetType().Name; 
							  Write-Host "Item with Id " + $item.id + " has unique permission";		
			                  $permissions += (QueryUniquePermissionsByObject $_web $item $Type $fileUrl $siteUrl $siteTitle $listTitle);
			                } 
			             } 
			        } 
				}
			}
		   }
		  }
		 return  $permissions;
 	}
	catch [System.Exception]
	{
	    write-host -f red $_.Exception.ToString()   
	}
}
Function Get-SPOSubWebs($ctx,$RootWeb){
	try{
			$Webs = $RootWeb.Webs
			$ctx.Load($Webs)
			$ctx.ExecuteQuery()
	 		$localPermission=@();
	        ForEach ($sWeb in $Webs)
	        {
	            Write-Output "Scanning web with title" $sWeb
				$localPermission = QueryUniquePermissions($sWeb);
	            Get-SPOSubWebs -ctx $ctx -RootWeb $sWeb
	        }
			return ($subPermissions + $localPermission)
	    }
		 catch [System.Exception]
	    {
	        write-host -f red $_.Exception.ToString()   
	    }  
	}
	
	


#Definition of the function that gets the list of site collections in the tenant using CSOM
Function Get-SPOTenantSiteCollectionsPermission($TenantAdminUrl,$Username,$password)
{
    try
    {    
        Write-Host "----------------------------------------------------------------------------"  -foregroundcolor Green
        Write-Host "Getting the Tenant Site Collections" -foregroundcolor Green
        Write-Host "----------------------------------------------------------------------------"  -foregroundcolor Green
        #SPO Client Object Model Context
        $spoCtx = New-Object Microsoft.SharePoint.Client.ClientContext($TenantAdminUrl) 
        $spoCredentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($Username, $password)  
        $spoCtx.Credentials = $spoCredentials
        $spoTenant= New-Object Microsoft.Online.SharePoint.TenantAdministration.Tenant($spoCtx)
        $spoTenantSiteCollections=$spoTenant.GetSiteProperties(0,$true)
        $spoCtx.Load($spoTenantSiteCollections)
        $spoCtx.ExecuteQuery()
        #We need to iterate through the $spoTenantSiteCollections object to get the information of each individual Site Collection
        foreach($spoSiteCollection in $spoTenantSiteCollections){
			#array storing permissions
			$Permissions = @(); 
			If (Test-Path $siteexclusion){
				$checkForExclusion = Import-Csv $siteexclusion | Where-Object {$_.SiteUrl -eq $spoSiteCollection.Url} 
			}
			else
			{
				$checkForExclusion = $null
			}
			if($checkForExclusion.SiteUrl -eq $null)
			{
				Write-Host "Url: " $spoSiteCollection.Url " - Template: " $spoSiteCollection.Template " - Owner: "  $spoSiteCollection.Owner
	            $ctx = New-Object Microsoft.SharePoint.Client.ClientContext($spoSiteCollection.Url) 
	        	$spoCredentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($Username, $password)  
	       		$ctx.Credentials = $spoCredentials
	            $rootWeb = $ctx.Web
			    $ctx.Load($rootWeb)
			    $ctx.ExecuteQuery()
	     	    #Root Web of the Site Collection 
	  		    $RootSiteTitle = $rootWeb.Title; 
			    $RootWebUrl = $RootWeb.Url;
			    $RootWeb = $rootWeb; 
	            #root web , i.e. site collection level
			    $Permissions += QueryUniquePermissions($RootWeb);
				$Permissions += Get-SPOSubWebs -ctx $ctx -RootWeb $RootWeb;
				$existingData=@();
				If (Test-Path $exportFilePath){
				  	$existingData = Import-CSV -Path $exportFilePath ;
					Remove-Item -Path $exportFilePath -Force
					Write-Host "Export File Path is:" $exportFilePath
		   		    Write-Host "Number of lines exported is :" $Permissions.Count
					($existingData+$Permissions)|Select SiteUrl,SiteTitle,Type,RelativeUrl,ListTitle,MemberType,MemberName,MemberLoginName,ParentGroup,Roles|Export-CSV -Path $exportFilePath -NoTypeInformation;
				}
				Else{
					Write-Host "Export File Path is:" $exportFilePath
		   		    Write-Host "Number of lines exported is :" $Permissions.Count
					$Permissions|Select SiteUrl,SiteTitle,Type,RelativeUrl,ListTitle,MemberType,MemberName,MemberLoginName,ParentGroup,Roles|Export-CSV -Path $exportFilePath -NoTypeInformation;
				}
				
				
				$ctx.Dispose();
			}
			else
			{
				Write-Host Site Collection with Url $spoSiteCollection.Url will not be sanned as it was excluded
			}
        }
		
   		#$Permissions|Select SiteUrl,SiteTitle,Type,RelativeUrl,ListTitle,MemberType,MemberName,MemberLoginName,ParentGroup,Roles|Export-CSV -Path $exportFilePath -NoTypeInformation;
        $spoCtx.Dispose()
    }
    catch [System.Exception]
    {
        write-host -f red $_.Exception.ToString()   
    }    
}	

Get-SPOTenantSiteCollectionsPermission -TenantAdminUrl $TenantAdminUrl -Username $Username -password $password
	
	


   