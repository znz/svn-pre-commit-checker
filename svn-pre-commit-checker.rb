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

  def reject(message)
    STDERR.puts "#{@filepath}: #{message}"
    @result = false
  end

  ANY = //
  ADDED = /\AA/
  DELETED = /\AD/
  UPDATED = /\AU/
  PROP_CHANGED = /\A.U/

  def reject_filename(message, pattern, what_changed=ANY)
    regexp(what_changed, pattern) do
      reject message
    end
  end

  def regexp(what_changed, *patterns)
    patterns.map! do |pattern|
      case pattern
      when Regexp
        pattern # OK
      when String
        Regexp.new(Regexp.quote(pattern))
      else
        raise ArgumentError, "unknown pattern type #{pattern.inspect}"
      end
    end
    @changed.each do |changed, filepath|
      if what_changed =~ changed && patterns.any?{|pat| pat =~ filepath }
        @what_changed = changed
        @filepath = filepath
        yield(changed, filepath)
      end
    end
  end

  def basename(what_changed, *patterns)
    @changed.each do |changed, filepath|
      if what_changed =~ changed && patterns.any?{|pat| File.fnmatch(pat, File.basename(filepath)) }
        @what_changed = changed
        @filepath = filepath
        yield(changed, filepath)
      end
    end
  end
end

if __FILE__ == $0
  SvnPreCommitChecker.new(*ARGV).run
end
