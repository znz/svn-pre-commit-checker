#!/usr/bin/ruby
# -*- coding: utf-8 -*-

class SvnPreCommitChecker
  SVNLOOK = '/usr/bin/svnlook'

  def initialize(repos, txn)
    @repos = repos
    @txn = txn
  end

  def run
    @debug = false
    @result = true
    @changed = IO.popen("#{SVNLOOK} changed -t #{@txn} #{@repos}", "r") do |io|
      io.readlines.map do |line|
        /\A(...).(.+)\Z/ =~ line
        [$1, $2]
      end
    end
    conf_filename = "#{@repos}/hooks/svn-pre-commit-checker.conf"
    eval(File.read(conf_filename), binding, conf_filename, 1)
    exit(@result)
  end

  def fail
    STDERR.puts "fail in svn-pre-commit-checker.conf"
    exit(false)
  end

  def reject_filename(message, pattern, what_changed=//)
    case pattern
    when String
      pattern = Regexp.new(Regexp.quote(pattern))
    when Regexp
      # OK
    else
      raise ArgumentError, "unknown pattern type #{pattern.inspect}"
    end
    @changed.each do |changed, filepath|
      if pattern =~ filepath
        if what_changed =~ changed
          STDERR.puts "#{filepath}: #{message}"
          @result = false
        end
      end
    end
  end
end

if __FILE__ == $0
  SvnPreCommitChecker.new(*ARGV).run
end
