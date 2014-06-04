droxi
=====

ftp-like command-line [Dropbox](https://www.dropbox.com/) interface in
[Ruby](https://www.ruby-lang.org/en/)

installation
------------

    gem install droxi

or

    git clone https://github.com/jangler/droxi.git
    cd droxi && rake && sudo rake install

or

    wget https://aur.archlinux.org/packages/dr/droxi/droxi.tar.gz
    tar -xzf droxi.tar.gz
    cd droxi && makepkg -s && sudo pacman -U droxi-*.pkg.tar.xz

features
--------

- interface inspired by
  [GNU coreutils](http://www.gnu.org/software/coreutils/),
  [GNU ftp](http://www.gnu.org/software/inetutils/), and
  [lftp](http://lftp.yar.ru/)
- context-sensitive tab completion and path globbing
- upload, download, and share files
- man page and interactive help

developer features
------------------

- spec-style unit tests using [MiniTest](https://github.com/seattlerb/minitest)
- [RuboCop](https://github.com/bbatsov/rubocop) approved
- fully [RDoc](http://rdoc.sourceforge.net/) documented
