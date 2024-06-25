#!/bin/bash
#
# Developed by Ricardo Barantini
# Contact ricardobarantini@protonmail.com
#

nodejs.sh(){
    # Show options
    echo -e "
    ${txtblu}
    What version of Node.js do you want to install?

    ${txtrst}
    1) Node.js 8
    2) Node.js 10
    3) Node.js 11
    4) Node.js 12
    5) Node.js 14
    6) Node.js 16
    7) Node.js 18
    8) Node.js 20
    ";

    # Get value
    read version

    # Case
    case $version in
        1) node8;;
        2) node10;;
        3) node11;;
        4) node12;;
        5) node14;;
        6) node16;;
        7) node18;;
        8) node20;;
        *) echo "Invalid option. Please try again."; nodejs.sh;;
    esac
}

node8() {
    curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -;
    sudo apt-get install -y nodejs;
    clear;
}

node10() {
    curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash -;
    sudo apt-get install -y nodejs;
    clear;
}

node11(){
    curl -sL https://deb.nodesource.com/setup_11.x | sudo -E bash -;
    sudo apt-get install -y nodejs;
    clear;
}

node12(){
    curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash -;
    sudo apt-get install -y nodejs;
    clear;
}

node14(){
    curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash -;
    sudo apt-get install -y nodejs;
    clear;
}

node16(){
    curl -sL https://deb.nodesource.com/setup_16.x | sudo -E bash -;
    sudo apt-get install -y nodejs;
    clear;
}

node18(){
    curl -sL https://deb.nodesource.com/setup_18.x | sudo -E bash -;
    sudo apt-get install -y nodejs;
    clear;
}

node20(){
    curl -sL https://deb.nodesource.com/setup_20.x | sudo -E bash -;
    sudo apt-get install -y nodejs;
    clear;
}

nodejs.sh  # Invoke the function to start the script
