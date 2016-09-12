require 'sqlite3'
require 'colorize'
#require 'debug'

def clear
  system "clear" or system "cls"
end

def new_note(db)
  clear()
  puts "Title:"        # make red or something
  title = gets
  #puts
  #puts "========================"

  puts "Content:\n(opens Vim to allow you to input large amounts of text)"  # make orange or something
  key_input = gets
  if key_input == "\n"
    system("vim", "/tmp/temp_content.txt")
    content = `less /tmp/temp_content.txt`
    `rm /tmp/temp_content.txt`
  end
  #puts
  #puts "========================"

  puts "Tags:"         # make green or something
  tag = gets
  #puts

  # create new note in table
  db.execute("INSERT INTO Notes VALUES(?, ?, ?)", [@null, title, content])
  noteId = db.get_first_value("SELECT last_insert_rowid()")

  # if tag doesnt exist, create one
  if db.execute("SELECT * FROM Tags WHERE tag_name=\'#{tag}\'").length <= 0
    db.execute("INSERT INTO Tags VALUES(?, ?)", [@null, tag])
    tagId = db.get_first_value("SELECT last_insert_rowid()")
  else
    tagId = db.get_first_value("SELECT id FROM Tags WHERE tag_name=\'#{tag}\'")
  end
  # create relationship between note and tag
  db.execute("INSERT INTO NotesTags VALUES(?, ?, ?)", [@null, noteId, tagId])
end

def setup_menu
  clear()
  puts "n) Make a new note".cyan
  puts "q) Quit Ruby Notes".light_red
  print "Action: "
end

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

setup_menu()

loop do
  input = gets.chomp   
  case input
  when "n"
    new_note(db)
    setup_menu()
  when "q"
    clear()
    abort
  else
    puts "Invalid entry, please try again"
  end
end

# output UI stuff
