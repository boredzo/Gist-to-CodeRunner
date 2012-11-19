#Gist to CodeRunner service
## An OS X service to open Gists in CodeRunner

This service enables you to right-click on links to Gists and choose “Send Gist to CodeRunner” from the Services menu.

[CodeRunner](https://itunes.apple.com/us/app/coderunner/id433335799) is a Mac app that makes it easy to make and run small test apps. It was developed by Nikolai Krill and is available from the Mac App Store, currently for $10. I made this app to make it easy to take test apps posted on Gist and load them into CodeRunner.

If the service can guess the main file of the Gist, it will do so; otherwise, it will ask you to pick. If there is only one module file, then that is the main file. The “main file” is the file that the service will eventually open in CodeRunner.

Currently, this service recognizes Objective-C, C, and C++ module files and Python and Ruby source files as possible main files.

I'm Peter Hosey, and you can obtain newer versions of this service from [my GitHub repository for it](https://github.com/boredzo/Gist-to-CodeRunner/).
