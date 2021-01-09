#!/bin/bash
SERVICE_NAME=$1;
SOLUTION_NAME="vtb.${SERVICE_NAME}Service"

PROJECT_API="${SOLUTION_NAME}.Api"
PROJECT_BUSINESS_LOGIC="${SOLUTION_NAME}.BusinessLogic"
PROJECT_DATA_ACCESS="${SOLUTION_NAME}.DataAccess"
PROJECT_DOMAIN="${SOLUTION_NAME}.Domain"
PROJECT_SERVICE="${SOLUTION_NAME}.Service"
_DIRNAME="`dirname \"$0\"`"
_BASEDIR="`(cd \"${_DIRNAME}/..\" && pwd)`"
_SLN_ABSOLUTE_DIR="${_BASEDIR}/${SOLUTION_NAME}";

C_INFO="\033[0;32m"
C_WARNING="\033[0;31m"
C_TEXT="\033[0m"
C_SEPARATOR="########################################################################################################################"

echo -e ""
echo -e $C_SEPARATOR
echo -e ""
echo -e "Creating service named: \t${C_INFO}${SERVICE_NAME}${C_TEXT}"
echo -e ""
echo -e $C_SEPARATOR
echo -e ""

echo -e "Basedir: \t\t${C_INFO}${_BASEDIR}${C_TEXT}"
echo -e "Solution name: \t\t${C_INFO}${SOLUTION_NAME}${C_TEXT}"

echo -e ""
echo -e "Project names:"
echo -e "\t- ${C_INFO}${PROJECT_API}${C_TEXT}"
echo -e "\t- ${C_INFO}${PROJECT_BUSINESS_LOGIC}${C_TEXT}"
echo -e "\t- ${C_INFO}${PROJECT_DATA_ACCESS}${C_TEXT}"
echo -e "\t- ${C_INFO}${PROJECT_DOMAIN}${C_TEXT}"
echo -e "\t- ${C_INFO}${PROJECT_SERVICE}${C_TEXT}"

echo -e ""
echo -e "Solution directory ${C_INFO}${_SLN_ABSOLUTE_DIR}${C_TEXT}";

if [[ -d $_SLN_ABSOLUTE_DIR ]]
then
    echo -e "${C_WARNING}Solution directory exists! If you proceed, it will be wiped first.${C_TEXT}"
fi

echo -e ""
echo $C_SEPARATOR
echo -e ""

while true; do

    read -p "Do you want to continue? (Y/N)" B_CONTINUE

    case $B_CONTINUE in
        [Yy]* ) break;;
        [Nn]* ) exit;;
        *) echo -e "Type Y or N";;
    esac
done


rm -rf $_SLN_ABSOLUTE_DIR

echo -e "Creating solution dir"
mkdir $_SLN_ABSOLUTE_DIR

echo -e "Creating empty solution"
dotnet new sln -n $SOLUTION_NAME -o $_SLN_ABSOLUTE_DIR

function create_project {
    PROJECT_TYPE=$1
    PROJECT_NAME=$2
    TESTS_PROJECT_NAME="${PROJECT_NAME}.Tests"
    TESTS_PROJECT_TYPE="nunit"
        
    echo -e ""
    echo -e "Creating project ${C_INFO}$PROJECT_NAME${C_TEXT} of type ${C_INFO}$PROJECT_TYPE${C_TEXT}"
    dotnet new $PROJECT_TYPE -n $PROJECT_NAME -o "${_SLN_ABSOLUTE_DIR}/${PROJECT_NAME}"
    add_project_to_solution $PROJECT_NAME

    echo -e ""
    echo -e "Creating test project ${C_INFO}$TESTS_PROJECT_NAME${C_TEXT} of type ${C_INFO}$TESTS_PROJECT_TYPE${C_TEXT}"
    dotnet new nunit -n $TESTS_PROJECT_NAME -o "${_SLN_ABSOLUTE_DIR}/${TESTS_PROJECT_NAME}"
    add_project_to_solution $TESTS_PROJECT_NAME

    add_reference $PROJECT_NAME $TESTS_PROJECT_NAME
}

function add_reference {
    echo ""
    echo -e "Adding reference ${C_INFO}${1}${C_TEXT} -> ${C_INFO}${2}${C_TEXT}"
    dotnet add "${_SLN_ABSOLUTE_DIR}/${1}" reference "${_SLN_ABSOLUTE_DIR}/${2}"
}

function add_project_to_solution {
    PROJECT_TO_ADD=$1
    echo ""
    echo -e "Adding ${C_INFO}${PROJECT_TO_ADD}${C_TEXT} to solution"
    dotnet sln "${_SLN_ABSOLUTE_DIR}/${SOLUTION_NAME}.sln" add "${_SLN_ABSOLUTE_DIR}/${PROJECT_TO_ADD}"
}

create_project web $PROJECT_API &
create_project classlib $PROJECT_BUSINESS_LOGIC &
create_project classlib $PROJECT_DATA_ACCESS &
create_project classlib $PROJECT_DOMAIN &
create_project console $PROJECT_SERVICE

echo -e ""
echo -e $C_SEPARATOR
echo -e ""
echo -e "${C_INFO}Creating references between projects${C_TEXT}"
echo -e ""

add_reference $PROJECT_API $PROJECT_BUSINESS_LOGIC
add_reference $PROJECT_API $PROJECT_DOMAIN

add_reference $PROJECT_SERVICE $PROJECT_BUSINESS_LOGIC
add_reference $PROJECT_SERVICE $PROJECT_DOMAIN

add_reference $PROJECT_BUSINESS_LOGIC $PROJECT_DATA_ACCESS
add_reference $PROJECT_DATA_ACCESS $PROJECT_DOMAIN

echo -e ""
echo -e $C_SEPARATOR
echo -e ""
echo -e "${C_INFO}Make sure solution builds${C_TEXT}"

PWD=pwd
cd ${_SLN_ABSOLUTE_DIR}

dotnet restore
dotnet build
dotnet test

cd $PWD

echo -e "${C_INFO}"
echo $C_SEPARATOR
echo -e ""

echo -e "All done. 🎉"

echo -e ""
echo $C_SEPARATOR
echo -e "${C_TEXT}"