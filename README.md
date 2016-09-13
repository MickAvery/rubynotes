# Ruby Notes
****
## Description
**Ruby Notes** is a terminal-based notetaking application written in Ruby during my spare time. It allows users to store tagged notes in a SQLite3 database. The application also allows users to use basic Markdown syntax (headers, lists) in the note content for a better notetaking experience.

Markdown syntax is parsed using a modified version of the [mdless gem](https://github.com/ttscoff/mdless). The gem is made to be a terminal command, so I have had to clone it and do some modifications to the code in order to use it in a script.

## Setup and Installation
**Ruby Notes** assumes you are on a Mac and have SQLite3 installed, otherwise install it with
```
brew install sqlite3
```
It also assumes that you have Vim installed and can call it from the terminal.

Clone the repo...
```
git clone https://github.com/MickAvery/rubynotes.git && cd ./rubynotes
```
... and install dependencies ...
```
bundle
```
... and then run the app
```
ruby ./rubynotes.rb
```
## Feature Checklist
These are my goals for this project
- [x] Initial setup: get Title, Content, and Tags from user
- [x] Setup SQLite3 database to store notes and tags
- [x] Allow user to save notes in database
- [x] Parse markdown syntax from note content and display it accordingly
- [ ] Setup user interface and menu
- [ ] Allow user to have separate folders for notes
- [ ] Allow user to move notes from one folder to another
- [ ] Allow user to export notes into .txt or .md format
- [ ] User authentication: user should enter password first before accessing notes database
- [ ] encrypt data in database
