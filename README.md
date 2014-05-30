rubox
=====

ftp-like command-line interface to dropbox in ruby

example session
---------------

    rubox user@site:/> mkdir test
    rubox user@site:/> ls
    test
    rubox user@site:/> cd test
    rubox user@site:/test> !ls
    data.txt
    rubox user@site:/test> put data.txt
    rubox user@site:/test> get data.txt info.txt
    rubox user@site:/test> !ls
    data.txt
    info.txt
    rubox user@site:/test> cd ..
    rubox user@site:/> rm test/data.txt
