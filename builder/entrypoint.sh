#!/bin/bash
#
# builder
# Script Metadata & Description
#
# Options Format:
# The SCRIPT_OPTS is an array who's keys are as follows,
#   <regex>:<varname>
#
# The first part before the colon is a standard Regex to match against
# the given options, i.e. (-d|--date)
#
# The second part is the key used as the variable name. This name will be exported
# as OPTS_<varname>, i.e. OPTS_DATE
#
# A complete example of this: (-d|--date):DATE
#
# @author: Will Salemé <william.saleme@gmail.com>
# @license: GNU v3
# @date: March 12, 2016
##
SCRIPT_NAME="builder"
SCRIPT_FILE="${0}"
SCRIPT_VER="1.0"
SCRIPT_OPTS=("(-p|--path):PATH" "(-r|--repo):REPO" "(-d|--db):DB" "(-e|--extension):EXT")
SCRIPT_CATCHALL="false"

# const vars
EXTRACTOR_REPO_URL='https://github.com/AnotherMangos/extractor'
MANGOSD_REPO_URL='https://github.com/AnotherMangos/mangosd'
REALMD_REPO_URL='https://github.com/AnotherMangos/realmd'


# Print Usage for CLI
function _help () {
    echo -e "${SCRIPT_NAME}\n"
    echo -e "-v|--version  To display script's version"
    echo -e "-h|--help     To display script's help\n"
    echo -e "Available commands:\n"
    echo -e "methods       To display script's methods"
    _available-methods
    exit 0
}

# Print CLI Version
function _version () {
    echo -e "${SCRIPT_NAME}" 1>&2
    echo -en "Version " 1>&2
    echo -en "${SCRIPT_VER}"
    echo -e "" 1>&2
    exit 0
}

# List all the available public methods in this CLI
function _available-methods () {
    METHODS=$(declare -F | grep -Eoh '[^ ]*$' | grep -Eoh '^[^_]*' | sed '/^$/d')
    if [ -z "${METHODS}" ]; then
        echo -e "No methods found, this is script has a single entry point." 1>&2
    else
        echo -e "${METHODS}"
    fi
    exit 0
}

# Dispatches CLI Methods
function _handle () {
    METHOD=$(_available-methods 2>/dev/null | grep -Eoh "^${1}\$")
    if [ "x${METHOD}" != "x" ]; then ${METHOD} ${@:2}; exit 0
    else
        # Call a Catch-All method
        if [ "${SCRIPT_CATCHALL}" == "yes" ]; then _catchall ${@}; exit 0
        # Display usage options
        else echo -e "Method '${1}' is not found.\n"; _help; fi
    fi
}

# Generate Autocomplete Script
function _generate-autocomplete () {
    SCRIPT="$(printf "%s" ${SCRIPT_NAME} | sed -E 's/[ ]+/-/')"
    ACS="function __ac-${SCRIPT}-prompt() {"
    ACS+="local cur"
    ACS+="COMPREPLY=()"
    ACS+="cur=\${COMP_WORDS[COMP_CWORD]}"
    ACS+="if [ \${COMP_CWORD} -eq 1 ]; then"
    ACS+="    _script_commands=\$(${SCRIPT_FILE} methods)"
    ACS+="    COMPREPLY=( \$(compgen -W \"\${_script_commands}\" -- \${cur}) )"
    ACS+="fi; return 0"
    ACS+="}; complete -F __ac-${SCRIPT}-prompt ${SCRIPT_FILE}"
    printf "%s" "${ACS}"
}


#
# User Implementation Begins
#
# Catches all executions not performed by other matched methods
function _catchall () {
    exit 0
}

function _load_build_path () {
    BUILD_PATH="/mnt"

    if [ "$OPTS_PATH" != "" ]
    then
        BUILD_PATH="$OPTS_PATH"
    fi

    if [ ! -d "$BUILD_PATH" ]
    then
        echo "Invalid path: $BUILD_PATH"
        exit 1
    fi
    BUILD_PATH=$(realpath $BUILD_PATH)
}

function _load_build_repository () {
    BUILD_REPOSITORY=""

    if [ "$OPTS_REPO" != "" ]
    then
        BUILD_REPOSITORY="$OPTS_REPO"
    else
        echo "No build repository specified. Look at the 'help' method."
        exit 1
    fi
}

function _load_db_repository () {
    DB_REPOSITORY=""

    if [ "$OPTS_DB" != "" ]
    then
        DB_REPOSITORY="$OPTS_DB"
    else
        echo "No DB repository specified. Look at the 'help' method."
        exit 1
    fi
}

function _load_extension () {
    EXTENSION=""

    if [ "$OPTS_EXT" != "" ]
    then
        EXTENSION="$OPTS_EXT"
    else
        echo "No extension specified. Look at the 'help' method."
        exit 1
    fi
}

function _load_config () {
    if [ ! -f "$BUILD_PATH/config" ]
    then
        echo "Configuration file not found. Please use the 'init' method before using this command !"
        exit 1
    fi
    . $BUILD_PATH/config
}

function _wait_sql() {
    echo "Waiting database..."
    while ! (echo "SELECT 1" | mysql -u$USERNAME -h $DB_HOST -P $DB_PORT -p$PASSWORD > /dev/null 2> /dev/null); do sleep 1; done
    echo "Database is available !"
}

function init () {
    _load_build_path
    _load_build_repository
    _load_db_repository
    _load_extension
    cd $BUILD_PATH && \
    echo "[CLONE]" && \
    git clone $BUILD_REPOSITORY ./mangos && \
    git clone $DB_REPOSITORY ./db && \
    echo "[CONFIG GENERATION]" && \
    cd ./db && \
    rm -f ./InstallFullDB.config && \
    (./InstallFullDB.sh > dev/null  || true )&& \
    mv InstallFullDB.config base.config && \
    echo -e ". ./base.config\n. ../config" > InstallFullDB.config && \
    cd .. && \
    echo 'EXTENSION="'$EXTENSION'"' > config && \
    echo 'DB_HOST="127.0.0.1"' >> config && \
    echo 'DB_PORT="3306"' >> config && \
    echo 'USERNAME="root"' >> config && \
    echo 'PASSWORD="password"' >> config && \
    echo 'REALM_HOST="127.0.0.1"' >> config && \
    echo "Init complete ! You can now update the config file to match you configuration" || \
    echo "Init error ! Look at the 'help' method or open an issue for more information."
    exit 0
}

# Compile the several binaries
function compile () {
    _load_build_path
    cd $BUILD_PATH && \
    echo "[COMPILATION]" && \
    mkdir -p ./build && \
    cd ./build && \
    cmake ../mangos -DCMAKE_INSTALL_PREFIX=\../mangos/run -DBUILD_EXTRACTORS=ON -DPCH=1 -DDEBUG=0 -DBUILD_PLAYERBOT=ON && \
    make && \
    make install && \
    cd .. && \
    mv ./mangos/run/* $BUILD_PATH/ && \
    mv ./mangos/src/game/AuctionHouseBot/ahbot.conf.dist.in $BUILD_PATH/etc/ahbot.conf &&\
    mv ./mangos/src/game/PlayerBot/playerbot.conf.dist.in $BUILD_PATH/etc/playerbot.conf &&\
    echo "Compilation complete !" || \
    echo "Compilation error ! Look at the 'help' method or open an issue for more information."
    exit 0
}

# init the db following the current configuration
function init-db () {
    _load_build_path
    _load_config
    _wait_sql
    cd $BUILD_PATH && \
    echo "[INIT DB]" && \
    mysql -u$USERNAME -h $DB_HOST -P $DB_PORT -p$PASSWORD < ./mangos/sql/create/db_create_mysql.sql && \
    mysql -u$USERNAME -h $DB_HOST -P $DB_PORT -p$PASSWORD "$EXTENSION"mangos < ./mangos/sql/base/mangos.sql && \
    for sql_file in $(ls ./mangos/sql/base/dbc/original_data/*.sql) ;
        do mysql -u$USERNAME -h $DB_HOST -P $DB_PORT -p$PASSWORD "$EXTENSION"mangos < $sql_file ;
    done && \
    for sql_file in $(ls ./mangos/sql/base/dbc/cmangos_fixes/*.sql) ;
        do mysql -u$USERNAME -h $DB_HOST -P $DB_PORT -p$PASSWORD "$EXTENSION"mangos < $sql_file ;
    done && \
    mysql -u$USERNAME -h $DB_HOST -P $DB_PORT -p$PASSWORD "$EXTENSION"characters < ./mangos/sql/base/characters.sql && \
    mysql -u$USERNAME -h $DB_HOST -P $DB_PORT -p$PASSWORD "$EXTENSION"realmd < ./mangos/sql/base/realmd.sql && \
    echo "UPDATE realmlist SET address = '$REALM_HOST' WHERE id = 1;" | mysql -u$USERNAME -h $DB_HOST -P $DB_PORT -p$PASSWORD "$EXTENSION"realmd && \
    cd ./db && \
    ./InstallFullDB.sh && \
    echo "Init DB success !" || \
    echo "Init DB error ! Look at the 'help' method or open an issue for more information."
}

# clone a repository in the build PATH
function _clone () {
    cd $BUILD_PATH && \
    git clone --no-checkout $1 tmp && \
    mv tmp/.git . && \
    rmdir tmp && \
    git reset --hard HEAD &&\
    cd - || \
    exit 1
}

# remove the repository cloned in the build PATH
function _clean_repo () {
    cd $BUILD_PATH && \
    git checkout --orphan tmp &&\
    git rm -rf . &&\
    rm -rf .git &&\
    cd - || \
    exit 1
}

function help () {
    case $1 in
        *)
            echo "Usage: $0 help METHOD"
            exit 0
            ;;
    esac
    exit 0
}

function build-extractor () {
    _load_build_path
    _load_config
    _clone $EXTRACTOR_REPO_URL

    cd $BUILD_PATH && \
    just create $EXTENSION ./bin/tools

    _clean_repo
}

#
# User Implementation Ends
# Do not modify the code below this point.
#
# Main Method Switcher
# Parses provided Script Options/Flags. It ensures to parse
# all the options before routing to a metched method.
#
# `<script> generate-autocomplete` is used to generate autocomplete script
# `<script> methods` is used as a helper for autocompletion scripts
ARGS=(); EXPORTS=(); while test $# -gt 0; do
    OPT_MATCHED=0; case "${1}" in
        -h|--help) OPT_MATCHED=$((OPT_MATCHED+1)); _help ;;
        -v|--version) OPT_MATCHED=$((OPT_MATCHED+1)); _version ;;
        methods) OPT_MATCHED=$((OPT_MATCHED+1)); _available-methods ;;
        generate-autocomplete) _generate-autocomplete ;;
        *) # Where the Magic Happens!
        if [ ${#SCRIPT_OPTS[@]} -gt 0 ]; then for OPT in ${SCRIPT_OPTS[@]}; do SUBOPTS=("${1}"); LAST_SUBOPT="${1}"
        if [[ "${1}" =~ ^-[^-]{2,} ]]; then SUBOPTS=$(printf "%s" "${1}"|sed 's/-//'|grep -o .); LAST_SUBOPT="-${1: -1}"; fi
        for SUBOPT in ${SUBOPTS[@]}; do SUBOPT="$(printf "%s" ${SUBOPT} | sed -E 's/^([^-]+)/-\1/')"
        OPT_MATCH=$(printf "%s" ${OPT} | grep -Eoh "^.*?:" | sed 's/://')
        OPT_KEY=$(printf "%s" ${OPT} | grep -Eoh ":.*?$" | sed 's/://')
        OPT_VARNAME="OPTS_${OPT_KEY}"
        if [ -z "${OPT_VARNAME}" ]; then echo "Invalid Option Definition, missing VARNAME: ${OPT}" 1>&2; exit 1; fi
        if [[ "${SUBOPT}" =~ ^${OPT_MATCH}$ ]]; then
            OPT_VAL="${OPT_VARNAME}"; OPT_MATCHED=$((OPT_MATCHED+1))
            if [[ "${SUBOPT}" =~ ^${LAST_SUBOPT}$ ]]; then
            if [ -n "${2}" -a $# -ge 2 ] && [[ ! "${2}" =~ ^-+ ]]; then OPT_VAL="${2}"; shift; fi; fi
            if [ -n "${!OPT_VARNAME}" ]; then OPT_VAL="${!OPT_VARNAME};${OPT_VAL}"; fi
            declare "${OPT_VARNAME}=${OPT_VAL}"
            EXPORTS+=("${OPT_VARNAME}")
            if [[ "${SUBOPT}" =~ ^${LAST_SUBOPT}$ ]]; then shift; fi
        fi; done; done; fi ;;
    esac # Clean up unspecified flags and parse args
    if [ ${OPT_MATCHED} -eq 0 ]; then if [[ ${1} =~ ^-+ ]]; then
        if [ -n ${2} ] && [[ ! ${2} =~ ^-+ ]]; then shift; fi; shift
    else ARGS+=("${1}"); shift; fi; fi
done
EXPORTS_UNIQ=$(echo "${EXPORTS[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')
for EXPORT in ${EXPORTS_UNIQ[@]}; do if [[ ${!EXPORT} == *";"* ]]; then
    TMP_VAL=(); for VAL in $(echo ${!EXPORT} | tr ";" "\n"); do TMP_VAL+=("${VAL}"); done
    eval ''${EXPORT}'=("'${TMP_VAL[@]}'")'
fi; done; _handle ${ARGS[@]}; exit 0