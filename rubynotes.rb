require 'sqlite3'
require 'curses'
require_relative './lib/mdless'
include Curses
#require 'debug'

# Initialize curses and allow for color in text
init_screen
start_color

# Setup global window variables
@menu
@border
@note_border
@note
@all_notes
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
  @menu.addstr("s) Look at all notes\n")
  @menu.addstr("t) Search notes using their tags (STILL NOT IMPLEMENTED)\n")

  @menu.attrset(color_pair(3))
  @menu.addstr("q) Quit Ruby Notes\n")

  @menu.attroff(color_pair(3))
  @menu.refresh

  unless not ask_input
    @menu.addstr("Action: ")
    @menu.refresh
    input = @menu.getch

    case input
    when "q"
      # TODO: put these in separate function
      @border.clear
      @border.refresh
      @menu.clear
      @menu.refresh
      @note_border.clear
      @note_border.refresh
      @note.clear
      @note.refresh
      @db.close
      close_screen
      abort
    when "n"
      @menu.addstr("\nYou chose to open notes window!")
      @menu.refresh
      sleep 1
      new_note()
    when "s"
      @menu.addstr("\nYou chose to see all notes!")
      @menu.refresh
      sleep 1
      see_all_notes()
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
  title = @note.getstr # TODO: check if input is empty

  @note.addstr("\n")
  @note.addstr("Content: \n")
  @note.addstr("(opens Vim to allow you to input large amounts of text)")
  @note.refresh
  key_input = @note.getch
  system("vim", "/tmp/temp_content.txt")
  file_content = File.open("/tmp/temp_content.txt", "rb")
  content = file_content.read # TODO: check if file exists (aka if user actually put in something)
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

  ### Now we insert data into the database ###
  # title and content to Notes table
  @db.execute("INSERT INTO Notes VALUES(?, ?, ?)", [@null, title, content])
  noteId = @db.get_first_value("SELECT last_insert_rowid()")

  # tags to Tags table
  tags.split(",").each do |tag|
    unless tag.strip.empty?
      if @db.execute("SELECT * FROM Tags WHERE tag_name=\'#{tag}\'").length <= 0
        @db.execute("INSERT INTO Tags VALUES(?, ?)", [@null, tag])
        tagId = @db.get_first_value("SELECT last_insert_rowid()")
      else
        tagId = @db.get_first_value("SELECT id FROM Tags WHERE tag_name=\'#{tag}\'")
      end

      # create relationship between note and tag, this goes into NotesTags table
      @db.execute("INSERT INTO NotesTags VALUES(?, ?, ?)", [@null, noteId, tagId])
    end
  end
  sleep 1.5
  setup_menu(true)
end

def see_all_notes
  # get all notes and their tags
  notes = @db.execute "SELECT * FROM Notes"
  notes.each do |note|
    note["tags"] = @db.execute "SELECT t.tag_name
                        FROM Tags t
                        INNER JOIN NotesTags nt
                          ON t.id = nt.tagId
                        INNER JOIN Notes n
                          ON n.id = nt.noteId
                        WHERE n.id = #{note["id"]}"
  end
  num_notes = notes.length
  index = 0

  close_screen()
  note_content = CLIMarkdown::Converter.new(notes[index]["content"])
  #@all_notes = Curses::Window.new(lines - 3, cols - 3, 2, 2)
  #@all_notes.addstr("Title: #{notes[index]["title"]}" + "\n\n")
  #@all_notes.addstr("Content:\n #{note_content.formatted_text}" + "\n\n")
  #@all_notes.addstr("Tags: #{notes[index]["tags"]}\n")
  #@all_notes.keypad = true
  #@all_notes.refresh
  puts "Title: #{notes[index]["title"]}" + "\n\n"
  puts "Content:\n #{note_content.formatted_text}" + "\n\n"
  puts "Tags: #{notes[index]["tags"]}\n"

  loop do
    #input = @all_notes.getch
    input = gets.chomp
    if input == "j" #Curses::Key::LEFT then
      index = (index - 1) % num_notes
      note_content = CLIMarkdown::Converter.new(notes[index]["content"])
      #@all_notes.clear
      #@all_notes.addstr("Title: #{notes[index]["title"]}" + "\n\n")
      #@all_notes.addstr("Content:\n #{note_content.formatted_text}" + "\n\n")
      #@all_notes.addstr("Tags: #{notes[index]["tags"]}\n")
      #@all_notes.refresh

      system "clear" or system "cls"
      puts "Title: #{notes[index]["title"]}" + "\n\n"
      puts "Content:\n #{note_content.formatted_text}" + "\n\n"
      puts "Tags: #{notes[index]["tags"]}\n"
    elsif input == "k" #Curses::Key::RIGHT then
      index = (index + 1) % num_notes
      note_content = CLIMarkdown::Converter.new(notes[index]["content"])
      #@all_notes.clear
      #@all_notes.addstr("Title: #{notes[index]["title"]}" + "\n\n")
      #@all_notes.addstr("Content:\n #{note_content.formatted_text}" + "\n\n")
      #@all_notes.addstr("Tags: #{notes[index]["tags"]}\n")
      #@all_notes.refresh

      system "clear" or system "cls"
      puts "Title: #{notes[index]["title"]}" + "\n\n"
      puts "Content:\n #{note_content.formatted_text}" + "\n\n"
      puts "Tags: #{notes[index]["tags"]}\n"
    elsif input == "q"
      system "clear" or system "cls"
      refresh()
      setup_border()
      setup_menu(true)
    end
  end
end

@db = SQLite3::Database.new 'NotesDB.db'
@db.results_as_hash = true
# check if NotesDB.Notes table exists
unless @db.execute("SELECT *
                    FROM sqlite_master
                    WHERE type=\'table\'
                    AND name=\'Notes\'").length > 0
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
