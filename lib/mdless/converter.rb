module CLIMarkdown
  class Converter
    include Colors

    attr_reader :helpers, :log, :formatted_text

    def version
      "#{CLIMarkdown::EXECUTABLE_NAME} #{CLIMarkdown::VERSION}"
    end

    def initialize(args)
      @cols = %x{tput cols}.strip.to_i
      @output = ''

      input = args
      @ref_links = {}
      @footnotes = {}

      if args.length > 0
        input.gsub!(/\r?\n/,"\n")
        #list_headers(input)
        convert_markdown(input)
        @output = printout
        @formatted_text = @output
      end
    end

    def list_headers(input)
      h_adjust = highest_header(input) - 1
      input.gsub!(/^(#+)/) do |m|
        match = Regexp.last_match
        new_level = match[1].length - h_adjust
        if new_level > 0
          "#" * new_level
        else
          ''
        end
      end

      headers = []
      last_level = 0
      input.split(/\n/).each do |line|
        if line =~ /^(#+)\s*(.*?)( #+)?\s*$/
          level = $1.size - 1
          title = $2

          if level - 1 > last_level
            level = last_level + 1
          end
          last_level = level

          subdoc = case level
          when 0
            '  '
          when 1
            '- '
          when 2
            '+ '
          when 3
            '* '
          else
            '  '
          end
          headers.push(("  "*level) + (c([:x, :yellow]) + subdoc + title.strip + xc))
        end
      end

      @output += headers.join("\n")
    end

    def highest_header(input)
      headers = input.scan(/^(#+)/)
      top = 6
      headers.each {|h|
        top = h[0].length if h[0].length < top
      }
      top
    end

    def color_table(input)
      first = true
      input.split(/\n/).map{|line|
        if first
          first = false
          line.gsub!(/\|/, "#{c([:d,:black])}|#{c([:x,:yellow])}")
        elsif line.strip =~ /^[|:\- ]+$/
          line.gsub!(/^(.*)$/, "#{c([:d,:black])}\\1#{c([:x,:white])}")
          line.gsub!(/([:\-]+)/,"#{c([:b,:black])}\\1#{c([:d,:black])}")
        else
          line.gsub!(/\|/, "#{c([:d,:black])}|#{c([:x,:white])}")
        end
      }.join("\n")
    end

    def cleanup_tables(input)
      in_table = false
      header_row = false
      all_content = []
      this_table = []
      orig_table = []
      input.split(/\n/).each {|line|
        if line =~ /(\|.*?)+/ && line !~ /^\s*~/
          in_table = true
          table_line = line.to_s.uncolor.strip.sub(/^\|?\s*/,'|').gsub(/\s*([\|:])\s*/,'\1')

          if table_line.strip.gsub(/[\|:\- ]/,'') == ''
            header_row = true
          end
          this_table.push(table_line)
          orig_table.push(line)
        else
          if in_table
            if this_table.length > 2
              # if there's no header row, add one, cleanup requires it
              unless header_row
                cells = this_table[0].sub(/^\|/,'').scan(/.*?\|/).length
                cell_row = '|' + ':-----|'*cells
                this_table.insert(1, cell_row)
              end

              table = this_table.join("\n").strip
              begin
                formatted = MDTableCleanup.new(table)
                res = formatted.to_md
                res = color_table(res)
              rescue
                res = orig_table.join("\n")
              end
              all_content.push(res)
            else
              all_content.push(orig_table.join("\n"))
            end
            this_table = []
            orig_table = []
          end
          in_table = false
          header_row = false
          all_content.push(line)
        end
      }
      all_content.join("\n")
    end

    def clean_markers(input)
      input.gsub!(/^(\e\[[\d;]+m)?[%~] ?/,'\1')
      input
    end

    def update_inline_links(input)
      links = {}
      counter = 1
      input.gsub!(/(?<=\])\((.*?)\)/) do |m|
        links[counter] = $1.uncolor
        "[#{counter}]"
      end
    end

    def find_color(line,nullable=false)
      return line if line.nil?
      colors = line.scan(/\e\[[\d;]+m/)
      if colors && colors.size > 0
        colors[-1]
      else
        nullable ? nil : xc
      end
    end

    def color_link(line, text, url)
      out = c([:b,:black])
      out += "[#{c([:u,:blue])}#{text}"
      out += c([:b,:black])
      out += "]("
      out += c([:x,:cyan])
      out += url
      out += c([:b,:black])
      out += ")"
      out += find_color(line)
      out
    end

    def color_image(line, text, url)
      text.gsub!(/\e\[0m/,c([:x,:cyan]))

      "#{c([:x,:red])}!#{c([:b,:black])}[#{c([:x,:cyan])}#{text}#{c([:b,:black])}](#{c([:u,:yellow])}#{url}#{c([:b,:black])})" + find_color(line)
    end

    def convert_markdown(input)

      # yaml/MMD headers
      in_yaml = false
      if input.split("\n")[0] =~ /(?i-m)^---[ \t]*?(\n|$)/
        @log.info("Found YAML")
        # YAML
        in_yaml = true
        input.sub!(/(?i-m)^---[ \t]*\n([\s\S]*?)\n[\-.]{3}[ \t]*\n/) do |yaml|
          m = Regexp.last_match

          @log.warn("Processing YAML Header")
          m[0].split(/\n/).map {|line|
            if line =~ /^[\-.]{3}\s*$/
              line = c([:d,:black,:on_black]) + "% " + c([:d,:black,:on_black]) + line
            else
              line.sub!(/^(.*?:)[ \t]+(\S)/, '\1 \2')
              line = c([:d,:black,:on_black]) + "% " + c([:d,:white]) + line
            end
            if @cols - line.uncolor.size > 0
              line += " "*(@cols-line.uncolor.size)
            end
          }.join("\n") + "#{xc}\n"
        end
      end

      if !in_yaml && input.gsub(/\n/,' ') =~ /(?i-m)^\w.+:\s+\S+ /
        @log.info("Found MMD Headers")
        input.sub!(/(?i-m)^([\S ]+:[\s\S]*?)+(?=\n\n)/) do |mmd|
          puts mmd
          mmd.split(/\n/).map {|line|
            line.sub!(/^(.*?:)[ \t]+(\S)/, '\1 \2')
            line = c([:d,:black,:on_black]) + "% " + c([:d,:white,:on_black]) + line
            if @cols - line.uncolor.size > 0
              line += " "*(@cols - line.uncolor.size)
            end
          }.join("\n") + " "*@cols + "#{xc}\n"
        end

      end


      # Gather reference links
      input.gsub!(/^\s{,3}(?<![\e*])\[\b(.+)\b\]: +(.+)/) do |m|
        match = Regexp.last_match
        @ref_links[match[1]] = match[2]
        ''
      end

      # Gather footnotes (non-inline)
      input.gsub!(/^ {,3}(?<!\*)(?:\e\[[\d;]+m)*\[(?:\e\[[\d;]+m)*\^(?:\e\[[\d;]+m)*\b(.+)\b(?:\e\[[\d;]+m)*\]: *(.*?)\n/) do |m|
        match = Regexp.last_match
        @footnotes[match[1].uncolor] = match[2].uncolor
        ''
      end

      h_adjust = highest_header(input) - 1
      input.gsub!(/^(#+)/) do |m|
        match = Regexp.last_match
        "#" * (match[1].length - h_adjust)
      end

      input.gsub!(/(?i-m)([`~]{3,})([\s\S]*?)\n([\s\S]*?)\1/ ) do |cb|
        m = Regexp.last_match
        leader = m[2] ? m[2].upcase + ":" : 'CODE:'
        leader += xc

        if exec_available('pygmentize')
          lexer = m[2].nil? ? '-g' : "-l #{m[2]}"
          begin
            hilite, s = Open3.capture2(%Q{pygmentize #{lexer} 2> /dev/null}, :stdin_data=>m[3])

            if s.success?
              hilite = hilite.split(/\n/).map{|l| "#{c([:x,:black])}~ #{xc}" + l}.join("\n")
            end
          rescue => e
            @log.error(e)
            hilite = m[0]
          end

        else

          hilite = m[3].split(/\n/).map{|l|
            new_code_line = l.gsub(/\t/,'    ')
            orig_length = new_code_line.size + 3
            new_code_line.gsub!(/ /,"#{c([:x,:white,:on_black])} ")
            "#{c([:x,:black])}~ #{c([:x,:white,:on_black])} " + new_code_line + c([:x,:white,:on_black]) + " "*(@cols - orig_length) + xc
          }.join("\n")
        end
        "#{c([:x,:magenta])}#{leader}\n#{hilite}#{xc}"
      end

      # remove empty links
      input.gsub!(/\[(.*?)\]\(\s*?\)/, '\1')
      input.gsub!(/\[(.*?)\]\[\]/, '[\1][\1]')

      lines = input.split(/\n/)

      # previous_indent = 0

      lines.map!.with_index do |aLine, i|
        line = aLine.dup
        clean_line = line.dup.uncolor


        if clean_line.uncolor =~ /(^[%~])/ # || clean_line.uncolor =~ /^( {4,}|\t+)/
          ## TODO: find indented code blocks and prevent highlighting
          ## Needs to miss block indented 1 level in lists
          ## Needs to catch lists in code
          ## Needs to avoid within fenced code blocks
          # if line =~ /^([ \t]+)([^*-+]+)/
          #   indent = $1.gsub(/\t/, "    ").size
          #   if indent >= previous_indent
          #     line = "~" + line
          #   end
          #   p [indent, previous_indent]
          #   previous_indent = indent
          # end
        else
          # Headlines
          line.gsub!(/^(#+) *(.*?)(\s*#+)?\s*$/) do |match|
            m = Regexp.last_match
            pad = ""
            ansi = ''
            case m[1].length
            when 1
              ansi = c([:b, :black, :on_intense_white])
              pad = c([:b,:white])
              pad += m[2].length + 2 > @cols ? "*"*m[2].length : "*"*(@cols - (m[2].length + 2))
            when 2
              ansi = c([:b, :green, :on_black])
              pad = c([:b,:black])
              pad += m[2].length + 2 > @cols ? "-"*m[2].length : "-"*(@cols - (m[2].length + 2))
            when 3
              ansi = c([:u, :b, :yellow])
            when 4
              ansi = c([:x, :u, :yellow])
            else
              ansi = c([:b, :white])
            end

            "\n#{xc}#{ansi}#{m[2]} #{pad}#{xc}\n"
          end

          # place footnotes under paragraphs that reference them
          if line =~ /\[(?:\e\[[\d;]+m)*\^(?:\e\[[\d;]+m)*(\S+)(?:\e\[[\d;]+m)*\]/
            key = $1.uncolor
            if @footnotes.key? key
              line += "\n\n#{c([:b,:black,:on_black])}[#{c([:b,:cyan,:on_black])}^#{c([:x,:yellow,:on_black])}#{key}#{c([:b,:black,:on_black])}]: #{c([:u,:white,:on_black])}#{@footnotes[key]}#{xc}"
              @footnotes.delete(key)
            end
          end

          # color footnote references
          line.gsub!(/\[\^(\S+)\]/) do |m|
            match = Regexp.last_match
            last = find_color(match.pre_match, true)
            counter = i
            while last.nil? && counter > 0
              counter -= 1
              find_color(lines[counter])
            end
            "#{c([:b,:black])}[#{c([:b,:yellow])}^#{c([:x,:yellow])}#{match[1]}#{c([:b,:black])}]" + (last ? last : xc)
          end

          # blockquotes
          line.gsub!(/^(\s*>)+( .*?)?$/) do |m|
            match = Regexp.last_match
            last = find_color(match.pre_match, true)
            counter = i
            while last.nil? && counter > 0
              counter -= 1
              find_color(lines[counter])
            end
            "#{c([:b,:black])}#{match[1]}#{c([:x,:magenta])} #{match[2]}" + (last ? last : xc)
          end

          # make reference links inline
          line.gsub!(/(?<![\e*])\[(\b.*?\b)?\]\[(\b.+?\b)?\]/) do |m|
            match = Regexp.last_match
            title = match[2] || ''
            text = match[1] || ''
            if match[2] && @ref_links.key?(title.downcase)
              "[#{text}](#{@ref_links[title]})"
            elsif match[1] && @ref_links.key?(text.downcase)
              "[#{text}](#{@ref_links[text]})"
            else
              if input.match(/^#+\s*#{Regexp.escape(text)}/i)
                "[#{text}](##{text})"
              else
                match[1]
              end
            end
          end

          # color inline links
          line.gsub!(/(?<![\e*!])\[(\S.*?\S)\]\((\S.+?\S)\)/) do |m|
            match = Regexp.last_match
            color_link(match.pre_match, match[1], match[2])
          end



          # inline code
          line.gsub!(/`(.*?)`/) do |m|
            match = Regexp.last_match
            last = find_color(match.pre_match, true)
            "#{c([:b,:black])}`#{c([:b,:white])}#{match[1]}#{c([:b,:black])}`" + (last ? last : xc)
          end

          # horizontal rules
          line.gsub!(/^ {,3}([\-*] ?){3,}$/) do |m|
            c([:x,:black]) + '_'*@cols + xc
          end

          # bold, bold/italic
          line.gsub!(/(^|\s)[\*_]{2,3}([^\*_\s][^\*_]+?[^\*_\s])[\*_]{2,3}/) do |m|
            match = Regexp.last_match
            last = find_color(match.pre_match, true)
            counter = i
            while last.nil? && counter > 0
              counter -= 1
              find_color(lines[counter])
            end
            "#{match[1]}#{c([:b])}#{match[2]}" + (last ? last : xc)
          end

          # italic
          line.gsub!(/(^|\s)[\*_]([^\*_\s][^\*_]+?[^\*_\s])[\*_]/) do |m|
            match = Regexp.last_match
            last = find_color(match.pre_match, true)
            counter = i
            while last.nil? && counter > 0
              counter -= 1
              find_color(lines[counter])
            end
            "#{match[1]}#{c([:u])}#{match[2]}" + (last ? last : xc)
          end

          # equations
          line.gsub!(/((\\\\\[)(.*?)(\\\\\])|(\\\\\()(.*?)(\\\\\)))/) do |m|
            match = Regexp.last_match
            last = find_color(match.pre_match)
            if match[2]
              brackets = [match[2], match[4]]
              equat = match[3]
            else
              brackets = [match[5], match[7]]
              equat = match[6]
            end
            "#{c([:b, :black])}#{brackets[0]}#{xc}#{c([:b,:blue])}#{equat}#{c([:b, :black])}#{brackets[1]}" + (last ? last : xc)
          end

          # list items
          # TODO: Fix ordered list numbering, pad numbers based on total number of list items
          line.gsub!(/^(\s*)([*\-+]|\d+\.) /) do |m|
            match = Regexp.last_match
            last = find_color(match.pre_match)
            indent = match[1] || ''
            "#{indent}#{c([:d, :red])}#{match[2]} " + (last ? last : xc)
          end

          # definition lists
          line.gsub!(/^(:\s*)(.*?)/) do |m|
            match = Regexp.last_match
            "#{c([:d, :red])}#{match[1]} #{c([:b, :white])}#{match[2]}#{xc}"
          end

          # misc html
          line.gsub!(/<br\/?>/, "\n")
          line.gsub!(/(?i-m)((<\/?)(\w+[\s\S]*?)(>))/) do |tag|
            match = Regexp.last_match
            last = find_color(match.pre_match)
            "#{c([:d,:black])}#{match[2]}#{c([:b,:black])}#{match[3]}#{c([:d,:black])}#{match[4]}" + (last ? last : xc)
          end
        end

        line
      end

      input = lines.join("\n")

      @footnotes.each {|t, v|
        input += "\n\n#{c([:b,:black,:on_black])}[#{c([:b,:yellow,:on_black])}^#{c([:x,:yellow,:on_black])}#{t}#{c([:b,:black,:on_black])}]: #{c([:u,:white,:on_black])}#{v}#{xc}"
      }

      @output += input

    end

    def exec_available(cli)
      if File.exists?(File.expand_path(cli))
        File.executable?(File.expand_path(cli))
      else
        system "which #{cli} &> /dev/null"
      end
    end

    def page(text, &callback)
      return text
    end

    def printout
      out = @output.strip.split(/\n/).map {|p|
        p.wrap(@cols)
      }.join("\n")


      unless out && out.size > 0
        $stderr.puts "No results"
        Process.exit
      end

      out = cleanup_tables(out)
      out = clean_markers(out)
      out = out.gsub(/\n+{2,}/m,"\n\n") + "\n#{xc}\n\n"

      return page("\n\n" + out)
    end

    def which_pager
      pagers = [ENV['GIT_PAGER'], ENV['PAGER'],
                `git config --get-all core.pager`.split.first,
                'less', 'more', 'cat', 'pager']
      pagers.select! do |f|
        if f
          system "which #{f} &> /dev/null"
        else
          false
        end
      end

      pg = pagers.first
      args = case pg
      when 'more'
        ' -r'
      when 'less'
        ' -r'
      else
        ''
      end

      [pg, args]
    end
  end
end
