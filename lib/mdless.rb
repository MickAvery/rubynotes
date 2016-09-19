#require 'optparse'
require 'shellwords'
#require 'open3'
#require 'fileutils'
require 'logger'
require_relative 'mdless/version.rb'
require_relative 'mdless/colors'
require_relative 'mdless/tables'
require_relative 'mdless/converter'

module CLIMarkdown
  EXECUTABLE_NAME = 'mdless'
end
