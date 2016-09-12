require 'sqlite3'
#require 'debug'

#system "clear" or system "cls"

db = SQLite3::Database.new 'NotesDB.db'
# check if NotesDB.Notes table exists
unless db.execute("SELECT * FROM sqlite_master WHERE type=\'table\' AND name=\'Notes\'").length > 0
  db.execute("CREATE TABLE Notes(id INTEGER PRIMARY KEY, 
                                 title NVARCHAR, 
                                 content NVARCHAR)")
  db.execute("CREATE TABLE Tags(id INTEGER PRIMARY KEY, 
                                tag_name NVARCHAR)")
  db.execute("CREATE TABLE NotesTags(id INTEGER PRIMARY KEY, 
                                     noteId INTEGER,
                                     tagId INTEGER,
                                     FOREIGN KEY(noteId) REFERENCES Notes(id),
                                     FOREIGN KEY(tagId) REFERENCES Tags(id))")
end

# output UI stuff
puts "Title:"        # make red or something
title = gets
#puts
#puts "========================"

puts "Content:\n(opens Vim to allow you to input large amounts of text)"  # make orange or something
content = gets
#puts
#puts "========================"

puts "Tags:"         # make green or something
tag = gets
#puts

# create new note in table
db.execute("INSERT INTO Notes VALUES(?, ?, ?)", [@null, title, content])
noteId = db.get_first_value("SELECT last_insert_rowid()")

# if tag doesnt exist, create one
if db.execute("SELECT * FROM Tags WHERE tag_name=\'#{tag}\'") <= 0
  db.execute("INSERT INTO Tags VALUES(?, ?)", [@null, tag])
  tagId = db.get_first_value("SELECT last_insert_rowid()")
else
  tagId = db.get_first_value("SELECT id FROM Tags WHERE tag_name=\'#{tag}\'")
end
# create relationship between note and tag
db.execute("INSERT INTO NotesTags VALUES(?, ?, ?)", [@null, noteId, tagId])
