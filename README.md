Droxi
=====
An `ftp`-like command-line [Dropbox](https://www.dropbox.com/) interface in
[Ruby](https://www.ruby-lang.org/en/). **Due to changes in the Dropbox API,
this software is no longer functional and is not maintained.**

Installation
------------
Installation as Ruby gem:

    gem install droxi

Manual installation:

    git clone https://github.com/jangler/droxi.git
    cd droxi && rake && sudo rake install

If you use Arch Linux or a derivative, you may also install via the
[AUR package](https://aur.archlinux.org/packages/droxi/).

Features
--------
- Interface based on
  [GNU coreutils](http://www.gnu.org/software/coreutils/),
  [GNU ftp](http://www.gnu.org/software/inetutils/), and
  [lftp](http://lftp.yar.ru/)
- Context-sensitive tab completion and path globbing
- Upload, download, organize, search, and share files
- File revision control
- Interactive help

Usage
-----
	Usage: droxi [OPTION ...] [COMMAND [ARGUMENT ...]]

	If invoked without arguments, run in interactive mode. If invoked with
	arguments, parse the arguments as a command invocation, execute the
	command, and exit.

	For a list of commands, run `droxi help` or use the 'help' command in
	interactive mode.

	Options:
			--debug                      Enable debug command
		-f, --file FILE                  Specify path of config file
		-h, --help                       Print help information and exit
			--version                    Print version information and exit

Examples
--------
Start interactive session:

	droxi

Invoke single command and exit:

	droxi share Photos/pic.jpg

Scripting:

	echo -e "cd Photos \n put -f *jpg" | droxi
