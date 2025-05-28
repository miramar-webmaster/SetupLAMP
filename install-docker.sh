#!/bin/bash
#Installs the Docker engine.
#requires functions.sh
#SCRIPTID: b6153465-48c2-440a-964f-427c7aca895c

arrScriptsLoaded+=("b6153465-48c2-440a-964f-427c7aca895c")
[[ "${arrScriptsLoaded[@]}" =~ "6581a047-37eb-4384-b15d-14478317fb11" ]] || source functions.sh

function setupDockerRepository 
{
#    [[ "$debug" == "Y" ]] && echo "*** Entering function: ${FUNCNAME[0]}"
#    local _result=0

#    if [ "$nopackages" == "Y" ]; then
#        echo "Skipping docker install (nopackages is TRUE)"
#        return 0
#    fi

    echo Installing Docker Repositories.

    #Add git repository to get the very latest version of git.
    #This will automatically update the apt database.
    sudo add-apt-repository ppa:git-core/ppa
	sudo apt update

    #Add Docker's GPG Key
    sudo apt install ca-certificates curl gnupg lsb-release
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod 444 /etc/apt/keyrings/docker.asc

    #Add the repositories
   echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    sudo apt update
    sudo groupadd docker
    sudo usermod -a -G docker $USER

    [[ "$debug" == "Y" ]] && echo "*** Exiting function: ${FUNCNAME[0]}"
}
