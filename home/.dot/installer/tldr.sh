mkdir -p ~/bin
curl -o ~/bin/tldr https://raw.githubusercontent.com/raylee/tldr/master/tldr
chmod +x ~/bin/tldr
export PATH=$PATH:/usr/local/bin
tldr -u