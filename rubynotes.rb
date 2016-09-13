require 'sqlite3'
require 'curses'
include Curses
#require 'debug'

# Initialize curses and allow for color in text
init_screen
start_color
#nocbreak

# Setup global window variables
@menu
@border
@note_border
@note
@db

def setup_menu(ask_input)
  @menu = Curses::Window.new(lines - 3, cols - 3, 2, 2)
  init_pair(1, 1, 0)
  init_pair(2, 2, 0)
  init_pair(3, 3, 0)
  @menu.attrset(color_pair(1))
  @menu.addstr("Welcome to Ruby Notes!\n\n\n")
  
  @menu.attrset(color_pair(2))
  @menu.addstr("n) Make a new note\n")
  
  @menu.attrset(color_pair(3))
  @menu.addstr("q) Quit Ruby Notes\n")
  
  @menu.attroff(color_pair(3))
  @menu.refresh
  
  if ask_input
    @menu.addstr("Action: ")
    @menu.refresh
    input = @menu.getch
    
    case input
    when "q"
      close_screen
      abort
    when "n"
      @menu.addstr("\nYou chose to open notes window!")
      @menu.refresh
      sleep 1
      new_note()
    else
      @menu.addstr("\nInvalid input")
      @menu.refresh
      sleep 2
      close_screen
      abort
    end       
  end
end

def setup_border
  @border = Curses::Window.new(lines, cols, 0, 0)
  @border.box("#", "#")
  @border.refresh
end

def start_app
  setup_border()
  setup_menu(true)
end

def new_note
  @note_border = Curses::Window.new(lines - 5, cols - 5, 4, 4)
  @note_border.box("||", "=")
  @note_border.refresh
  
  @note = Curses::Window.new(lines - 7, cols - 7, 6, 6)
  @note.addstr("Title: ")
  @note.refresh
  title = @note.getstr

  @note.addstr("\n")
  @note.addstr("Content: \n")
  @note.addstr("(opens Vim to allow you to input large amounts of text)")
  @note.refresh
  key_input = @note.getch
  system("vim", "/tmp/temp_content.txt")
  file_content = File.open("/tmp/temp_content.txt", "rb")
  # TODO: check if file exists (aka if user actually put in something)
  content = file_content.read
  file_content.close
  File.delete("/tmp/temp_content.txt")
  setup_border()
  setup_menu(false)
  
  # repopulate note_border and note window (TODO: find better, more generic, way of doing this)
  @note_border.box("|", "-")
  @note_border.refresh
  @note.setpos(0, 0)
  @note.addstr("Title: #{title}\n\n")
  @note.addstr("Content: ")
  @note.addstr("\n" + content + "\n\n")
  @note.addstr("Tags (separated with commas \',\'): ")
  tags = @note.getstr
  tags.split(",").each do |tag|
    @note.addstr("\n#{tag.strip}")
  end
  @note.refresh
  sleep 3

  # create new note in table
  #@db.execute("INSERT INTO Notes VALUES(?, ?, ?)", [@null, title, content])
  #noteId = @db.get_first_value("SELECT last_insert_rowid()")

  # if tag doesnt exist, create one
  #if @db.execute("SELECT * FROM Tags WHERE tag_name=\'#{tag}\'").length <= 0
  #  @db.execute("INSERT INTO Tags VALUES(?, ?)", [@null, tag])
  #  tagId = @db.get_first_value("SELECT last_insert_rowid()")
  #else
  #  tagId = @db.get_first_value("SELECT id FROM Tags WHERE tag_name=\'#{tag}\'")
  #end
  # create relationship between note and tag
  #@db.execute("INSERT INTO NotesTags VALUES(?, ?, ?)", [@null, noteId, tagId])
end

@db = SQLite3::Database.new 'NotesDB.@db'
# check if NotesDB.Notes table exists
unless @db.execute("SELECT * FROM sqlite_master WHERE type=\'table\' AND name=\'Notes\'").length > 0
  @db.execute("CREATE TABLE Notes(id INTEGER PRIMARY KEY, 
                                 title NVARCHAR, 
                                 content NVARCHAR)")
  @db.execute("CREATE TABLE Tags(id INTEGER PRIMARY KEY, 
                                tag_name NVARCHAR)")
  @db.execute("CREATE TABLE NotesTags(id INTEGER PRIMARY KEY, 
                                     noteId INTEGER,
                                     tagId INTEGER,
                                     FOREIGN KEY(noteId) REFERENCES Notes(id),
                                     FOREIGN KEY(tagId) REFERENCES Tags(id))")
end

start_app()

close_screen
abort