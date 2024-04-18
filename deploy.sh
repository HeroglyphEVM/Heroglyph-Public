#!/bin/bash
source .env

get_env_value() {
    grep "^$1=" .env | cut -d= -f2-
}

script_directory="script/deploy"
is_simulation=false

# This is overkill since the forge script already checks for builds. 
# However, I once encountered an issue where I deployed an old version of the build. 
# Therefore, it is better to play it safe.
forge build --force

echo "is Simulation?"
    select use_simulation in "yes" "no"; do
        case $use_simulation in
            yes ) is_simulation=true; break;;
            no ) break;;
        esac
    done
    echo

while true; do
    RPC_URL="missing url" 

    #
    # Get Endpoints / Network from Foundry.toml
    #

    # Extract rpc_endpoints keys from the TOML file
    endpoints=$(awk '/\[rpc_endpoints\]/ {flag=1; next} /\[/{flag=0} flag && !/^$/{print $1}' foundry.toml)

    # Convert the endpoints to an array
    IFS=$'\n' read -r -d '' -a endpoint_array <<<"$endpoints"

    echo "Please select an RPC endpoint:"
    select network in "${endpoint_array[@]}"; do
        if [ -n "$network" ]; then
            # Extract the value of the selected key from the environment variables
            RPC_URL=$(awk -v key="$network" -F' *= *' '$1 == key {gsub(/"/, "", $2); print $2; exit}' foundry.toml)

            # Check if the value contains ${} pattern
            if [[ "$RPC_URL" =~ \$\{.*\} ]]; then
                RPC_URL=$(echo "$RPC_URL" | sed 's/\${//;s/}//') 
                RPC_URL=$(get_env_value "$RPC_URL")
            fi
            break
        else
            echo "Invalid selection. Please try again."
        fi
    done
    echo

    #
    # Create missing json deployment file
    #

    file="./deployment/"$network".json"

    if [ -e "$file" ]; then
        echo "$file found"
    else
        touch "$file"
        echo "$file created."
    fi
    echo

    #
    # Select a script from ./script/deploy/
    #

    files=("$script_directory"/*)

    echo "Select a script"
    select script_name in "${files[@]}"; do
        break
    done
    echo

    #
    # Confirmation
    #

    echo "Configuration:" 
    echo "  RPC: $RPC_URL" 
    echo "  Network: $network" 
    echo "  Script Name: $script_name"
    echo "  Is Simulation: $is_simulation"
    echo
    echo "Continue?"
    select answer in "yes" "no"; do
        case $answer in
            yes ) deploying=true; break;;
            no ) exit;;
        esac
    done
    echo

    #
    # Deployment
    #

    if $is_simulation; then
        make simulate-deploy SCRIPT_NAME=$script_name RPC=$RPC_URL NETWORK=$network
    else
        make deploy SCRIPT_NAME=$script_name RPC=$RPC_URL NETWORK=$network
    fi

    #
    # Repeat
    #

    echo "Deploy Something else?"
    select answer in "yes" "no"; do
        case $answer in
            yes ) break;;
            no ) exit;;
        esac
    done
    echo

done

