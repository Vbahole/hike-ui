# script to run right after enabling linux on chromebook
# paste to the linux files drive
# chmod +x linux-recovery.sh
# ./linux-recovery.sh

sudo apt-get update
sudo apt-get install git
wget -qO - https://packagecloud.io/AtomEditor/atom/gpgkey | sudo apt-key add
sudo sh -c 'echo "deb [arch=amd64] https://packagecloud.io/AtomEditor/atom/any/ any main" > /etc/apt/sources.list.d/atom.list'
sudo apt-get upgrade
sudo apt-get update
sudo apt-get install atom
mkdir projects
