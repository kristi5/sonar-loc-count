#!/bin/bash
#set -x
#**************************************************************************#
#                                                                          #
#  @project     : LoC Counting bash Scripts                                #
#  @package     :                                                          #
#  @subpackage  : gitlab                                                   #
#  @access      :                                                          #
#  @paramtype   : connectionToken,groupName or path_project                #
#  @argument    :                                                          #
#  @description : Get Number ligne of Code in GitLab DevOPS                #
#  @usage : ./gitlab_com.sh <token> <groupName>                            #                                                              
#                                                                          #
#                                                                          #
#                                                                          #
#  @version 1.01                                                           #
#                                                                          #
#**************************************************************************#


if [ $# -lt 2 ]; then
    echo "Usage: `basename $0` <token> <groupName> "
    exit
fi

# Set Variables token, groupName, Namespace, BaseAPI
# Namespace values : <0> = Browse the groupName - <1> = Browse SubgroupName or Project
#--------------------------------------------------------------------------------------#
connectionToken=$1
groupname=$2


if [[ "$2" =~ .*"/".* ]]; then 
       Namespace=0
    else 
       Namespace=1
fi

#BaseAPI="https://gitlab.com/api/v4"
BaseAPI=$3

#--------------------------------------------------------------------------------------#

source ./set_common_variables.sh


# Test if request for for 1 Project or more Project in GroupName
     # If you have more than 100 repos Change Value of parameter page=Number_of_page
     # 1 Page = 100 repos max
     # Example for 150 repos :
     #  GetAPI="orgs/$org/repos?per_page=100&page=2"
if [ $Namespace -eq 1 ]; then
        groupname1=` echo $groupname|$SED s/'\/'/'%2f'/g`
        GetAPI="/projects/$groupname1"
        jq_args="\"\(.name):\(.id):\(.http_url_to_repo)\""

    else  
	  groupname1=` echo $groupname|$SED s/'\/'/'%2f'/g`
	  GetAPI="/groups/$groupname1/projects?per_page=100&page=1&include_subgroups=true&archived=false&visibility=internal&order_by=last_activity_at&sort=desc&simple=true"
          jq_args=".[] | \"\(.name):\(.id):\(.path_with_namespace):\(.http_url_to_repo)\""
fi

echo $GetAPI

# Get List of Repositories : get Name , ID and http_url_to_repo
curl --header "PRIVATE-TOKEN: $connectionToken" $BaseAPI$GetAPI|jq -r ''"${jq_args}"''| while IFS=: read -r Name ID Pathwithnamespace Repourl;

do
  echo "-----------------------------------------------------------------"
  echo -e "Repository Number :$i  Name : $Name id : $ID path: $Pathwithnamespace"
# Get List of Branches
   
   # Replace space by - in Repository name for created local file
   NameFile=` echo $Name|$SED s/' '/'-'/g`
   branchRegex="%5Emain%24%7C%5Emaster%24"
   branchesAPI="$BaseAPI/projects/$ID/repository/branches?per_page=100&regex=$branchRegex"
   echo $branchesAPI

    #url encoded reges for branch names ^main$|^master$|(^release-(14[.]5|15[.][0-9]?)[.]([0-9]?|x)$)
   branchRegex="%5Emain%24%7C%5Emaster%24%7C%28%5Erelease-%2814%5B.%5D5%7C15%5B.%5D%5B0-9%5D%3F%29%5B.%5D%28%5B0-9%5D%3F%7Cx%29%24%29"
   branchesAPI="$BaseAPI/projects/$ID/repository/branches?per_page=100&regex=$branchRegex"

   curl  --header "PRIVATE-TOKEN: $connectionToken" $branchesAPI | jq -r '.[].name' | while read -r BrancheName ;
    do
        # Replace / or space by - in Branche Name for created local file
        BrancheNameF=` echo $BrancheName|$SED s/'\/'/'-'/g|$SED s/' '/'-'/g`
        
        LISTF="${NameFile}_${BrancheNameF}.cloc"
        echo -e "\n       Branche Name : $BrancheName\n"

        # Format Clone URL : cut <https://> string
        CLONE="${Repourl:8}"

        # Create Commad Git clone 
        git clone https://oauth2:${connectionToken}@$CLONE --depth 1 --branch $BrancheName $NameFile

        excludedLangs="XML,HTML,YAML,SQL,CSS,SCSS,Go"

        # Run Analyse : run cloc on the local repository
        if [ -s $EXCLUDE ]; then
          cloc $NameFile --force-lang-def=sonar-lang-defs.txt --report-file=${LISTF} --exclude-lang=$excludedLangs --exclude-dir=$(tr '\n' ',' < .clocignore) --timeout 0 --sum-one
        else
           cloc $NameFile --force-lang-def=sonar-lang-defs.txt --report-file=${LISTF} --timeout 0 --sum-one
        fi   
    
       # Delete Directory projet
        /bin/rm -r $NameFile
       
        $SED -i "1i\Report for project ${Name} / ${BrancheName}\n" $LISTF

    done   

# Generate reports

    echo -e "\nBuilding final report for projet $NameFile : $NameFile.txt"
    echo "-----------------------------------------------------------------------------------------------------------------------" 

    # BRTAB2 : array with branche Name , The index is number max of cloc 
    # NBTAB1 : array with number max of cloc by branche
  
    ([ `printf *.cloc` != '*.cloc' ] || [ -f '*.txt' ]) &&  for j in `ls -la *.cloc|awk '{print $9}'`; do  CMD1=`cat $j |grep SUM:|awk '{print $5}'`;BRTAB2["$CMD1"]=${j%?????};NBTAB1+="$CMD1 ";cat $j >>  $NameFile.txt;done && /bin/rm *.cloc || echo ""

    # Find 
    IFS=' ' NBRCLOC=( $NBTAB1 )
    IFS=$'\n' sorted=( $(sort -nr <<<"${NBRCLOC[*]}") )
    INDEX01=${sorted[0]}

    if [ -z "$INDEX01" ]; then 
                MESSAGE01="0"
                MESSAGE02="No"
                INDEX01=0  

        else 
            MESSAGE01="$INDEX01"
            SEA="${NameFile}_"
            MESSAGE02=`echo ${BRTAB2[${INDEX01}]}| $SED s/$SEA/''/g`
    fi      

     printf "The maximum lines of code in the < %s > project is : < %' .f > for the branch : < %s >\n" "${NameFile}" "${MESSAGE01}" "${MESSAGE02}"
     echo -e "\n---------------------------------------------------------------------------------------------------------------------" >> $NameFile.txt
     printf "\nThe maximum lines of code in the < %s > project is : < %' .f > for the branch : < %s >\n" "${NameFile}" "${MESSAGE01}" "${MESSAGE02}" >> $NameFile.txt
     echo -e "-----------------------------------------------------------------------------------------------------------------------" >> $NameFile.txt 

    # set Nbr Loc by Project in File cpt.txt
    echo "${INDEX01}" >> $NBCLOC
    echo "${INDEX01},${NameFile},${Pathwithnamespace}" >> $NBCLOCNAME
    
    LISTF=""
    NBTAB1=()
    BRTAB2=()
    let "i=i+1"
    
done 

# Generate Gobal report
while read line  
do   
   cpt=$(expr $cpt + $line)
done < $NBCLOC

#/bin/rm $NBCLOC

echo -e "\n-------------------------------------------------------------------------------------------"
printf "The maximum lines of code on the repository is : < %' .f > result in <Report_global.txt>\n" "${cpt}"
echo -e "\n-------------------------------------------------------------------------------------------"

echo -e "-------------------------------------------------------------------------------------------\n" > Report_global.txt
printf "The maximum lines of code on the repository is : < %' .f > result in <Report_global.txt>\n" "${cpt}" >> Report_global.txt
echo -e "---------------------------------------------------------------------------------------------" >> Report_global.txt
