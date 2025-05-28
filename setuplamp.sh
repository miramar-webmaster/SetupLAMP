#!/bin/bash

[[ "${arrScriptsLoaded[@]}" =~ "6581a047-37eb-4384-b15d-14478317fb11" ]] || source functions.sh
[[ "${arrScriptsLoaded[@]}" =~ "c177481e-790d-4354-a596-c7aae6b0d152" ]] || source bash_aliases.sh
[[ "${arrScriptsLoaded[@]}" =~ "b6153465-48c2-440a-964f-427c7aca895c" ]] || source install-docker.sh


#Set global defaults.

debug="Y"
hostname=$(hostname)
LAMPonly="N"

while true; do
  #read -p "Set up LAMP without Drupal? (y/N): " -n 1 -r response
read -e -i "N" -p "Are you sure? [y/N] " response  echo
  if [[ "$response" =~ ^[Yy]$ ]]
  then
    echo "Yes"
    break
  elif [[ "$response" =~ ^[Nn]$ ]]
  then
    echo "No"
    break
  elif [[ -z "$response" ]]
  then
    echo "Default: No"
    response="N"
    break
  else
    echo "Invalid input. Try again."
  fi
done

LAMPonly=$response

if [ $LAMPonly = "N" ]
then
  echo "What environment are you creating? 
      1)Development
      2)Staging
      3)Production"

  THIS_SELECTION=
  until [ "${THIS_SELECTION^}" == 1 ] || [ "${THIS_SELECTION^}" == 2 ] || [ "${THIS_SELECTION^}" == 3 ]; do
    read -n1 -p "Select 1, 2, or 3: "  THIS_SELECTION
    THIS_SELECTION=${THIS_SELECTION^}
    echo;
  done 

  case "${THIS_SELECTION}" in
      1) env="dev" ;;
      2) env="stage" ;;
      3) env="prod" ;;
      *) echo other ;;
  esac

  read -p "Git repository containing the Drupal site [miraweb2024]: " repository
  repository=${repository:-git@github.com:miramar-webmaster/miraweb2024}
  echo $repository

  read -p "Drupal database name [sdmc]: " drupal_db
  drupal_db=${drupal_db:-sdmc}
  echo $drupal_db
  
  read -p "Drupal database user [drupal]: " drupal_user
  drupal_user=${drupal_user:-drupal}
  echo $drupal_user
  
  default_password=$(tr -dc 'A-Za-z0-9!?%=' < /dev/urandom | head -c 10)

  read -p "Drupal database password [a random one will be generated]: " drupal_pass
  drupal_pass=${default_password:-default_password}
  echo "Drupal password is " $drupal_pass

  read -p "Password for backup share: " sharePW
  sharePW=${default_password:-default_password}
fi

until read -r -p "MySQL Root password (REQUIRED): " mysql_pass && test "$mysql_pass" != ""; do
  continue
done

#Add the docker repositories, generate package list then cache & exit
#NOTE: the script to setup the Node.js PPA will run apt-get update
setupDockerRepository
setupNodeRepository
setupPHPRepository
setupEmail
ubuntuAddPackages

# Install base packages 
installPackages
configureDocker
configureGit
installComposer
cleanupInstall
if [ $LAMPonly == "N" ]; then
  echo "Creating bash aliases..."
  addBashAliases
  createProjectDirs
  echo "Stopping apache."
  sudo apache2ctl stop &> /dev/null
  if [ $env == "dev" ]; then
    setupVSCode
  fi
  #echo "Waiting for restoreArchiveProc ($restoreArchiveProc) to finish..."
  #wait $restoreArchiveProc

  #Set the database backup filename if not already provided...
  #We must do this here since the untar is ran in the background...
  # TODO: Uncomment the following when ready to develop database logic 
  #pushd $HOME/web-projects/backup
  #echo "Checking for sdmiramar.sql in $PWD"
  #if [ -f sdmiramar.sql ] && [ "$dbfilename" = "UNK" ]; then
#	dbfilename=`realpath sdmiramar.sql`
#	echo "set DB Filename to $dbfilename"
 # fi
  #popd
  #initDatabases #& initDatabasesProc=$!
  # END todo
  configureProjects & configProjectsProc=$!
  configureDrupalSettings
fi
		
  #wait $installComposerProc
		
  echo "***************************************************************"
  sg docker "docker pull memcached"
  sg docker "docker run --name memcache --restart always -p 11211:11211 -d memcached"
  echo "***************************************************************"
		
  #Wait for any outstanding stuff to finish
  echo "Waiting for any background jobs to complete..."
  wait #$configProjectsProc $restoreDatabaseProc
  configure_apache
  sudo apache2ctl restart



