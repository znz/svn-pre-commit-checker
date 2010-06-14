#!/usr/bin/ruby
require 'tmpdir'
begin
  require_relative 'svn-pre-commit-checker'
rescue NoMethodError
  require File.expand_path('svn-pre-commit-checker', File.dirname(__FILE__))
end

CHECKER_PATH = File.join(File.dirname(File.expand_path(__FILE__)), 'svn-pre-commit-checker.rb')

describe SvnPreCommitChecker do
  before do
    @dir = Dir.mktmpdir
    Dir.chdir(@dir) do
      system("svnadmin create repo") or raise
      system("svn co file://#{@dir}/repo work") or raise
    end
    @repo = "#{@dir}/repo"
    @work = "#{@dir}/work"

    FileUtils.symlink(CHECKER_PATH, "#{@repo}/hooks/pre-commit")
  end

  after do
    FileUtils.remove_entry_secure(@dir)
  end

  it "should be fail" do
    Dir.chdir(@work) do
      open("hoge", "w"){|f|f.puts "hoge"}
      system("svn add hoge").should == true
      system("svn commit -m 'add hoge'").should == false
    end
  end

  it "should be success" do
    File.open("#{@repo}/hooks/svn-pre-commit-checker.conf", "w") do |f|
    end

    Dir.chdir(@work) do
      open("hoge", "w"){|f|f.puts "hoge"}
      system("svn add hoge").should == true
      system("svn commit -m 'add hoge'").should == true
    end
  end

  it "should be fail in conf" do
    File.open("#{@repo}/hooks/svn-pre-commit-checker.conf", "w") do |f|
      f.puts "fail"
    end

    Dir.chdir(@work) do
      open("hoge", "w"){|f|f.puts "hoge"}
      system("svn add hoge").should == true
      system("svn commit -m 'add hoge'").should == false
    end
  end

  it "should be unknown method" do
    File.open("#{@repo}/hooks/svn-pre-commit-checker.conf", "w") do |f|
      f.puts "hoge"
    end

    Dir.chdir(@work) do
      open("hoge", "w"){|f|f.puts "hoge"}
      system("svn add hoge").should == true
      system("svn commit -m 'add hoge'").should == false
    end
  end

  it "should be reject to add filename" do
    File.open("#{@repo}/hooks/svn-pre-commit-checker.conf", "w") do |f|
      f.puts <<-'CONF'
reject_filename('Do not add temporary files', '~', /\AA/)
reject_filename('Do not add temporary files', /\.bak\z/, /\AA/)
      CONF
    end

    Dir.chdir(@work) do
      %w"hoge hoge~ hoge.bak".each do |filename|
        open(filename, "w"){|f|f.puts "hoge"}
        system("svn add #{filename}").should == true
      end
      system("svn commit -m 'add hoge'").should == false
    end
  end

  it "should be reject to update filename" do
    File.open("#{@repo}/hooks/svn-pre-commit-checker.conf", "w") do |f|
      f.puts <<-'CONF'
reject_filename('You should remove temporary files', /\.bak\z/, /\AU/)
      CONF
    end

    Dir.chdir(@work) do
      open("hoge.bak", "w"){|f|f.puts "hoge"}
      system("svn add hoge.bak").should == true
      system("svn commit -m 'add hoge.bak'").should == true
    File.open("#{@repo}/hooks/svn-pre-commit-checker.conf", "w") do |f|
      f.puts <<-'CONF'
reject_filename('Do not add temporary files', /\.bak\z/, /\AA/)
reject_filename('You should remove temporary files', /\.bak\z/, /\AU/)
      CONF
    end
      open("hoge.bak", "a"){|f|f.puts "hoge"}
      system("svn commit -m 'update hoge.bak'").should == false
      File.unlink("hoge.bak")
      system("svn rm hoge.bak").should == true
      system("svn commit -m 'remove hoge.bak'").should == true
    end
  end
end
