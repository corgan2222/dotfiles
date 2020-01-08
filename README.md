
# Dotfiles - bash Profile, Alias and basic Functions

> Scripts and Functions

all the Linux Stuff i used over the last 10 years

![](https://corgan2222.github.io/dotfiles/checkout.jpg)

## Table of Contents

- [Dotfiles - Alias and basic Functions](#dotfiles---alias-and-basic-functions)
- [Table of Contents](#table-of-contents)- [Requirements](#requirements)
- [Installation](#installation)
- [alias functions from /.dot/.bash_functions.sh](#alias-functions-from-dotbash_functionssh)
- [homeshick native](#homeshick-native)
- [Usage example](#usage-example)
- [Release History](#release-history)
- [Meta](#meta)

## Requirements

- linux or wsl
- git
- a lot of other stuff, check the functions

## Installation

Linux:

```sh
bash <(curl https://corgan2222.github.io/dotfiles/deploy_homeshick.sh)
gitSaveCredential
```

## alias functions from /.dot/.bash_functions.sh

Update:

```sh
saveHome
```

Load:

```sh
loadHome
```

Check:

```sh
checkHome
```

add File or Folder:

```sh
addToHome [file, folder]
```

## homeshick native

Update:

```sh
homeshick cd dotfiles
gitadd "message"
gitp
cd -
```

Load:

```sh
 homeshick pull dotfiles
  reload
```

Check:

```sh
homeshick check dotfiles
```

add File or Folder:

```sh
homeshick track dotfiles [file, folder]
```

troubleshoot
```sh
homeshick cd dotfiles
git status
#rm file
git pull
```

## Usage example

_For alias and functions check the [Wiki][https://github.com/corgan2222/dotfiles/wiki]._

## Release History

- 0.0.1
  - first deploy

## ToDo

- merge with Asus Merlin
- scripts

## Software Used and thanks

- [homeshick (git dotfiles synchronizer written in bash)](https://github.com/andsens/homeshick)
- [voku/dotfiles](https://github.com/voku/dotfiles)
- [cowboy/dotfiles](https://github.com/cowboy/dotfiles)
- [alrra/dotfiles](https://github.com/alrra/dotfiles)

## Meta

Stefan Knaak – stefan@knaak.org
