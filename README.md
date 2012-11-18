#Gist to CodeRunner service
## An OS X service to open Gists in CodeRunner

This service enables you to right-click on links to Gists and choose “Send Gist to CodeRunner” from the Services menu.

If the service can guess the main file of the Gist, it will do so; otherwise, it will ask you to pick. If there is only one module file, then that is the main file. The “main file” is the file that the service will eventually open in CodeRunner.

Currently, this service recognizes Objective-C, C, and C++ module files and Python and Ruby source files as possible main files.
