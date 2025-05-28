#!/bin/bash
#This is the functions library for the setuplamp.sh script.
#Add all needed packages using addPackage, then call installPackages
#SCRIPTID: 6581a047-37eb-4384-b15d-14478317fb11


#Global variables.
aptPackages=""		#Global list of packages to install
arrScriptsLoaded+=("6581a047-37eb-4384-b15d-14478317fb11")

repository="git@github.com:miramar-webmaster/miraweb2024"

function isScriptLoaded
{
  _result=0	#0=false/Not loaded
  if [[ "${arrScriptsLoaded[@]}" =~ "$1" ]]; then
    _result=1
  fi
  return $_result
}

function scriptsLoaded
{
  for script in "${arrScriptsLoaded[@]}"
  do
    echo $script
  done
}

function showhelp
{
  echo 'Usage: setuplamp.sh then follow prompts'
  #TODO: Rewrite help file ************************
  cat setuplamp-help.txt
  exit 1
}

function isInstalled()
{
  packagename=$1

  PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $packagename | grep "install ok installed")

  if [ "" == "$PKG_OK" ]; then
    return 0 #False
  else
    return 1 #Less false
  fi
}

#Adds a single package to list of packages to install
function addPackage
{
  pkg=$1
  status=0

  isInstalled $pkg &> /dev/null
  if [ "$?" == "0" ]; then
    echo "Adding package: $pkg"
    #Add a space between package names
    #[[ "$pkg" != ""  ]] && $pkg="$pkg "
    aptPackages+=" $1"	
  else
    echo "Package already installed: $pkg"
    status=-1
  fi
  return $status
}

#Adds a space-delimited list of packages to the global list
function addPackages
{
  packages=$1
  ilist=""	#list of already installed packages

  if [ "$packages" == "" ]; then
    echo "ERROR: addPackages called with empty list!  The Earth will now plunge directly into the Sun."
    exit 1
  fi

  for package in $packages
  do
    addPackage $package
    [[ $? -ne 0 ]] && ilist="$ilist $package"
  done
  echo; echo
  if [ "$ilist" != "" ]; then
    echo "The following packages were already installed:$ilist"
  fi
}

#Installs packages.  Packages must be added to global list via addPackage(s) functions.
#Arg1 = cacheonly setting
function installPackages
{
  [[ "$debug" == "Y" ]] && echo "*** Entering function: ${FUNCNAME[0]}"

  _aptArgs=""	#Arguments for the apt command
  _msg="Installing: "

  #Check for cache-only option
  _aptArgs="-y"
  if [ "$_cacheOnly" == "Y" ]; then
    _aptArgs+=" --download-only"
    _msg="Caching: "
  fi

  #Install using global variable that has been put through the addPackage process
  if [ "$nopackages" == "Y" ]; then
    echo "Skipping package installs."
    return 0
  else
    if [ "$aptPackages" != "" ]; then
      echo "$_msg [$aptPackages]"
      sudo apt install $_aptArgs $aptPackages
      local _result=$?
      if [ $_result != 0 ]; then
        echo "Error installing packages."
        exit 1
      fi
    else
      echo "Nothing to install."
    fi
  fi

  [[ "$debug" == "Y" ]] && echo "*** Exiting function: ${FUNCNAME[0]}"
}
   
function getPassword()
{
  read -sp "$1" $2
  echo
}
#TODO: Can it still be done this way? Is there a better way?
#Must pass password as first argument.
function setupShare()
{
	[[ "$debug" == "Y" ]] && echo "*** Entering function: ${FUNCNAME[0]}"

	if [ "$setupshare" == "Y" ]
	then
          pw=$1
          for path in "/root/.cifs" "/mnt/backup"
	  do
	    sudo sh -c "if [ ! -d $path ]; then sudo mkdir $path; fi"
          done

	  echo "username=backup" >> sdmiramar-backups
	  echo "domain=ics_miramar" >> sdmiramar-backups
	  echo "password=$pw" >> sdmiramar-backups
	  sudo mv sdmiramar-backups /root/.cifs
	  sudo chmod -R 700 /root/.cifs

	  if ! grep -q "#SCRIPTID: 6581a047-37eb-4384-b15d-14478317fb11" /etc/fstab 
	  then
	    cat fstab | sudo tee -a /etc/fstab
	    sudo mount -a
	  fi
	else
	  echo "Skipping share setup."
	fi

	[[     "$debug" == "Y" ]] && echo "*** Exiting function: ${FUNCNAME[0]}"

}

function addHosts()
{
  if ! grep -q "#SCRIPTID: 6581a047-37eb-4384-b15d-14478317fb11" /etc/hosts
  then
    cat hosts | sudo tee -a /etc/hosts
  fi
}

function addBashAliases()
{
  if [ ! -f ~/.bash_aliases ] || ! grep -q "#SCRIPTID: c177481e-790d-4354-a596-c7aae6b0d152" ~/.bash_aliases
  then
    echo "Copying bash_aliases."
    cat bash_aliases.sh >> ~/.bash_aliases
  fi
}

#This function handles the skipLAMP/LAMPonly flags.
##Arg1 = cacheonly flag

function ubuntuAddPackages()
{
  # Housekeeping packages
  packages="samba cifs-utils"
  # PHP and all needed extensions
  packages="$packages php8.1 php8.1-mysqli php8.1-mysqlnd php8.1-imap php8.1-xml php8.1-xmlreader php8.1-xmlwriter php8.1-xmlrpc php8.1-curl php8.1-gd php8.1-imagick php8.1-cli php8.1-ctype php8.1-gettext php8.1-dev php8.1-imap php8.1-mbstring php8.1-opcache php-memcached php8.1-readline php8.1-soap php8.1-zip php8.1-intl php8.1-bz2 php8.1-shmop php8.1-dom php-zip"
  # MySQL
  packages="$packages mysql-server-8.0 mysql-client-8.0"
  # Apache
  packages="$packages apache2 libapache2-mod-php8.1"
  # Set default password for MySQL so install script does not hang in the middle waiting for user input.
  sudo debconf-set-selections <<< "mysql-server mysql-server/root_password select $mysql_pass"
  sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again select $mysql_pass"
  cp my.cnf ~/.my.cnf
  sudo sed -i "s|\$PWD|${mysql_pass}|g" ~/.my.cnf
  sudo chmod 600 ~/.my.cnf
    
  addPackages "$packages"            
}

function setupEmail()
{
  # Installs Sendmail for prod, otherwise Mailhog
  if [$env == 'prod']; then
    addPackage sendmail
  elif [ $env == 'dev' || $env == 'stage' ]; then
    sudo apt-get install golang-go
    mkdir ~/gocode
    echo "export GOPATH=$HOME/gocode" >> ~/.profile
    source ~/.profile
    go install github.com/mailhog/MailHog@latest
    go install github.com/mailhog/mhsendmail@latest
    sudo cp ~/gocode/bin/MailHog /usr/local/bin/mailhog
     sudo cp ~/gocode/bin/mhsendmail /usr/local/bin/mhsendmail
  fi
}

#Install PPA for node.js
function setupNodeRepository()
{
  #If node version is not specified, use system default repository and just add npm
  #If we add only npm after changing repository, we get dependency errors.
  if [ "$nodeVersion" == "" ]; then
    addPackage "npm"
    return 0
  fi

  echo "Installing node.js version: $nodeVersion"     
  nodeVersion="setup_$nodeVersion.x"
  url="https://deb.nodesource.com/$nodeVersion"
  wget -q -O nodePrep.sh $url
  if [ $? != 0 ]; then
    echo "Error setting up PPA for node.js, therefore surrender."
    exit 1
  fi

  #This avoids a chmod to make the file executable
  cat nodePrep.sh | sudo -E bash -
  rm nodePrep.sh

  #Don't add npm, as the new repository installs npm as part of nodejs.
  addPackage "nodejs"
}

function setupPHPRepository
{
  php_repo="ppa:ondrej/php"
  sudo add-apt-repository $php_repo # Press enter when prompted.
  sudo apt update
}

function configureDocker()
{
  sudo apt update
  sudo groupadd docker
  sudo usermod -a -G docker $USER
}

function configureGit
{
	git config --global --bool core.autocrlf false
	git config --global --bool core.safecrlf false
	git config --global --bool core.ignorecase false
	git config --global --bool pull.rebase true
	git config --global --bool color.ui true
	git config --global diff.renames copies
	git config --global alias.a "apply --index"
	git config --global core.excludesfile ~/.gitignore
}

function configure_apache()
{
  wait #debug; ensure nothing else running in BG to avoid overlapped text
  #Ensure server is stopped
  echo "Configuring Apache..."
  sudo apache2ctl stop &> /dev/null
	
  #enable needed modules
  sudo a2enmod ssl rewrite &> /dev/null

  # The items below are customizations for a Drupal dev/stage/prod installation
  echo 'Customizing default LAMP for Drupal dev/stage/prod installation.'
	
  addHosts 

  #sudo cp 101-dev.conf   /etc/apache2/sites-available
  #sudo cp 102-stage.conf /etc/apache2/sites-available
  #sudo cp 103-prod.conf  /etc/apache2/sites-available

  #sudo sed -i "s|\/\$HOME|${HOME}|g" /etc/apache2/sites-available/101-dev.conf
  #sudo sed -i "s|\/\$HOME|${HOME}|g" /etc/apache2/sites-available/102-stage.conf
  #sudo sed -i "s|\/\$HOME|${HOME}|g" /etc/apache2/sites-available/103-prod.conf

  #sudo a2ensite 101-dev 102-stage 103-prod &> /dev/null

   self_sign '/etc/apache2' '/CN=*'
	
   if [ $LAMPonly == "N" ]; then
     sitenum=100
     conffile=$sitenum-$env.conf
     filename=/etc/apache2/sites-available/$conffile
     servername=$site.loc

     sudo cp $env.conf  $filename
     sudo sed -i "s|\/\$home|${HOME}|g" $filename
     sudo sed -i "s|\/\$site|/$site|g" $filename
     sudo sed -i "s|\$servername|$servername|g" $filename
     sudo sed -i "s|\$env|$site|g" $filename
		
     sudo a2ensite $conffile &> /dev/null
	
     conffile=$sitenum-$site-ssl.conf
     filename=/etc/apache2/sites-available/$conffile
     servername=$site.loc

     sudo cp env.ssl.conf  $filename
     sudo sed -i "s|\/\$home|${HOME}|g" $filename
     sudo sed -i "s|\/\$site|/$site|g" $filename
     sudo sed -i "s|\$servername|$servername|g" $filename
     sudo sed -i "s|\$env|$site|g" $filename

     sudo a2ensite $conffile &> /dev/null
  fi
}	

# Generate an SSL certificate (self-signed).
# self_sign(path, subj) where path is the path to create the ssl certificate directory, and subj are certificate parameters (openssl -subj parameter)
function self_sign()
{
  echo "Generating certificate."

  path=$1/ssl
  subj=$2
  privkey=$path/privkey.key
  pubkey=$path/pubkey.crt
	
  sudo sh -c "if [ ! -d $path ]; then mkdir $path; chmod 700 $path; fi"
  sudo sh -c "if [ -f $privkey ]; then rm $privkey; fi"
  sudo sh -c "if [ -f $pubkey ]; then rm $pubkey; fi"
	
  sudo openssl req -x509 -nodes -newkey rsa:2048 -days 365 -subj $subj -keyout $privkey -out $pubkey &> /dev/null

  sudo chmod 600 $path/privkey.key $path/pubkey.crt
}

function installComposer()
{
  [[ "$debug" == "Y" ]] && echo "*** Entering function: ${FUNCNAME[0]}"

  echo "Installing Composer..."
  #Install composer version 1 using the --1 option
  #url="https://getcomposer.org/download/latest-2.x/composer.phar"
  url="https://getcomposer.org/installer"
  curl -sS $url -o /tmp/composer-setup.php
  HASH=`curl -sS https://composer.github.io/installer.sig`
  echo $HASH
  php -r "if (hash_file('SHA384', '/tmp/composer-setup.php') === '$HASH') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo  PHP_EOL;"
  local _result=$?

  if [[ $_result != 0 ]]; then
    if [[ ! -f installer ]]; then
      echo "Error downloading composer installer, and no cached copy exists. Exiting"
      exit 1
    else
      echo "Error downloading composer installer.  Using a cached copy."
    fi
  fi

  sudo php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer
	
  [[ "$debug" == "Y" ]] && echo "*** Exiting function: ${FUNCNAME[0]}"
}

function cleanupInstall()
{
  sudo update-alternatives --set php /usr/bin/php8.1
}

# Install Visual Studio for development environment
function setupVSCode()
{
  # Add Microsoft GPG key
  wget https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
  sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg

  # Get the repository
  echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" |     sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
  rm packages.microsoft.gpg

  # Perform the install
  sudo apt update
  sudo apt install code
}

function createProjectDirs()
{
  [[ "$debug" == "Y" ]] && echo "*** Entering function: ${FUNCNAME[0]}"

  echo "Configuring project directories..."
  if [ -d $HOME/web-projects ]; then
    echo "Directory exists!"; jobs
    read -e -N 1 -p 'web-projects directory exists!  Delete? [y/N]? ' ans
    if [[ $ans =~ [Yy] ]]; then		
      echo "Deleting old web-projects."			
      sudo chown -R $USER:$USER $HOME/web-projects	
      # Don't delete backup directory to keep files symlinks working.
      for env in dev stage prod
      do
        rm -rf $HOME/web-projects/$env
      done
    else
      [[ "$debug" == "Y" ]] && echo "*** Exiting function: ${FUNCNAME[0]}"
      return
    fi
  fi

   #Make project directories -- including intermediate directories.
   #Need to create all the way to "files" so we can automate symlink to files later
   if [ ! -d $HOME/web-projects/backup/files ]
   then
     echo "Making project directories"
     mkdir -p $HOME/web-projects/backup/files
   fi

   [[ "$debug" == "Y" ]] && echo "*** Exiting function: ${FUNCNAME[0]}"	
}

function configureNPM()
{
	[[ "$debug" == "Y" ]] && echo "*** Entering function: ${FUNCNAME[0]}"
	local _projectdir=$1/docroot/themes/custom/sdmc
	pushd $_projectdir
	echo "Running npm install then build."
	npm install 	#> /dev/null 2>&1
	npm run build 	#> /dev/null 2>&1
	popd
	[[ "$debug" == "Y" ]] && echo "*** Exiting function: ${FUNCNAME[0]}"	
}

function configureProjects()
{
	[[ "$debug" == "Y" ]] && echo "*** Entering function: ${FUNCNAME[0]}"

	projectdir=$HOME/web-projects

	if [ ! -d $projectdir ]
	then
		#Get the dev directory configured fully, then copy it to prog/stage
		# 1. Clone
		# 2. Checkout Production
		# 3. Composer install
		# 4. Configure npm stuff
		# 5. Create linked files directory


		#Link files directory to restored archive
		echo "Cloning website repository..."
		git clone $repository $projectdir

		#Now go to tip of production and get all dependencies
		pushd $projectdir > /dev/null
		git checkout Production
		composer install --no-dev # > /dev/null 2>&1 # & p1=$!
		cd $projectdir/dev/docroot/themes/custom/sdmc
		configureNPM $projectdir/dev # & p2=$!
		popd > /dev/null

		#Now symlink the files directory to the files dir in the backup area:
		
	# TODO: Uncomment the following when ready for database
		#filedir=$projectdir/dev/docroot/sites/default/files
		#[[ -d $filedir ]] && rmdir $filedir
		#ln -s                 $projectdir/backup/files $filedir
        # END todo
		#echo "Waiting for composer/npm processes to finish..."
		#wait $p1 $p2
	fi

	[[ "$debug" == "Y" ]] && echo "*** Exiting function: ${FUNCNAME[0]}"
}

function configureDrupalSettings() # WORK NEEDED
{
	[[ "$debug" == "Y" ]] && echo "*** Entering function: ${FUNCNAME[0]}"

	local _env
	for _env in dev stage prod
	do
          echo "Creating: $_dir"
          [ ! -d $_dir ] && mkdir $_dir
          settingsfile=$_dir/$_env.settings.php
          sed "s|\$drupal_db|$drupal_db|" $_env.settings.php > $settingsfile
          sed -i "s|\$drupal_user|${drupal_user}|" $settingsfile
          sed -i "s|\$drupal_password|${drupal_password}|" $settingsfile
          sed -i "s|\$env|${_env}|" $settingsfile
	done
	[[ "$debug" == "Y" ]] && echo "*** Exiting function: ${FUNCNAME[0]}"
}


#Restore an archive into the web-projects/backup directory
function restoreArchive
{
	[[ "$debug" == "Y" ]] && echo "*** Entering function: ${FUNCNAME[0]}"

	local _file=$1
	local _restoredir=$HOME/web-projects/backup

	if [ -f $_file ]
	then
		_file=`realpath $_file`
		pushd $_restoredir > /dev/null
		echo "Restoring: $_file..."
		tar -xzf $_file
		if [ $? != 0 ]; then
			echo "Failed to untar $_file."
			popd
			return 5
		fi
		sudo chown -R www-data:www-data $_restoredir/files
		
		#We cannot set the database backup filename here since this is probably
		#being run as a background process

		popd > /dev/null
		
	else
		echo "Archive is gone, like tears in rain..."
		exit 1
	fi

	[[ "$debug" == "Y" ]] && echo "*** Exiting function: ${FUNCNAME[0]}"
}

function initDatabases()
{
	[[ "$debug" == "Y" ]] && echo "*** Entering function: ${FUNCNAME[0]}"

	if [ "$drupal_db" = "" ] || [ "$drupal_db" = "UNK" ]; then
		echo "No database to restore."
	else

		echo
		echo "Creating and restoring databases from: $drupal_db..."
		sed "s|\$d8user|${d8user}|" createdb.sql > cdb.sql
		sed -i "s|\$d8password|${d8password}|" cdb.sql
		
		mysql -u root --password=$mysql_pass < cdb.sql
		rm cdb.sql

		#gunzip -c $drupal_db > sdmiramar.sql
		echo "Restoring $drupal_db..."	
		mysql -u root --password=$mysql_pass d8dev < $drupal_db &> /dev/null & p1=$!
		mysql -u root --password=$mysql_pass d8prod < $drupal_db &> /dev/null & p2=$!
		mysql -u root --password=$mysql_pass d8stage < $drupal_db &> /dev/null & p3=$!
		
	fi
	[[ "$debug" == "Y" ]] && echo "*** Exiting function: ${FUNCNAME[0]}"
}

function setupContainers
{

  echo "***************************************************************"
  sg docker "docker pull memcached"
  sg docker "docker run --name memcache --restart always -p 11211:11211 -d memcached"
  echo "***************************************************************"
}

