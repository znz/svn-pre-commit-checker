#!/usr/bin/ruby
# -*- coding: utf-8 -*-
require 'test/unit'
require 'tmpdir'
begin
  require_relative 'svn-pre-commit-checker'
rescue NoMethodError
  require File.expand_path('svn-pre-commit-checker', File.dirname(__FILE__))
end

CHECKER_PATH = File.join(File.dirname(File.expand_path(__FILE__)), 'svn-pre-commit-checker.rb')

class TestSvnPreCommitChecker < Test::Unit::TestCase
  def setup
    @dir = Dir.mktmpdir
    Dir.chdir(@dir) do
      system("svnadmin create repo") or raise
      system("svn co file://#{@dir}/repo work") or raise
    end
    @repo = "#{@dir}/repo"
    @work = "#{@dir}/work"

    FileUtils.symlink(CHECKER_PATH, "#{@repo}/hooks/pre-commit")
  end

  def teardown
    FileUtils.remove_entry_secure(@dir)
  end

  def assert_system(*cmdline)
    assert(system(*cmdline), "assert #{cmdline.inspect}")
  end

  def assert_not_system(*cmdline)
    assert(!system(*cmdline), "assert not #{cmdline.inspect}")
  end

  def test_fail_to_add
    Dir.chdir(@work) do
      open("hoge", "w"){|f|f.puts "hoge"}
      assert_system("svn add hoge")
      assert_not_system("svn commit -m 'add hoge'")
    end
  end

  def test_success_to_add
    File.open("#{@repo}/hooks/svn-pre-commit-checker.conf", "w") do |f|
    end

    Dir.chdir(@work) do
      open("hoge", "w"){|f|f.puts "hoge"}
      assert_system("svn add hoge")
      assert_system("svn commit -m 'add hoge'")
    end
  end

  def test_fail_in_conf
    File.open("#{@repo}/hooks/svn-pre-commit-checker.conf", "w") do |f|
      f.puts "fail"
    end

    Dir.chdir(@work) do
      open("hoge", "w"){|f|f.puts "hoge"}
      assert_system("svn add hoge")
      assert_not_system("svn commit -m 'add hoge'")
    end
  end

  def test_unknown_method
    File.open("#{@repo}/hooks/svn-pre-commit-checker.conf", "w") do |f|
      f.puts "hoge"
    end

    Dir.chdir(@work) do
      open("hoge", "w"){|f|f.puts "hoge"}
      assert_system("svn add hoge")
      assert_not_system("svn commit -m 'add hoge'")
    end
  end

  def test_reject_to_add_filename
    File.open("#{@repo}/hooks/svn-pre-commit-checker.conf", "w") do |f|
      f.puts <<-'CONF'
regexp ADDED, '~', /\.bak\z/ do
  reject 'Do not add temporary files'
end
      CONF
    end

    Dir.chdir(@work) do
      %w"hoge~ ho~ge hoge.bak".each do |filename|
        open(filename, "w"){|f|f.puts "hoge"}
        assert_system("svn", "add", filename)
        assert_not_system("svn", "commit", "-m", "add hoge", filename)
        assert_system("svn", "rm", "--force", filename)
      end

      %w"hoge_bak".each do |filename|
        open(filename, "w"){|f|f.puts "hoge"}
        assert_system("svn", "add", filename)
        assert_system("svn", "commit", "-m", "add hoge", filename)
      end
    end
  end

  def test_reject_to_add_filename_old_style
    File.open("#{@repo}/hooks/svn-pre-commit-checker.conf", "w") do |f|
      f.puts <<-'CONF'
reject_filename('Do not add temporary files', '~', ADDED)
reject_filename('Do not add temporary files', /\.bak\z/, ADDED)
      CONF
    end

    Dir.chdir(@work) do
      %w"hoge~ ho~ge hoge.bak".each do |filename|
        open(filename, "w"){|f|f.puts "hoge"}
        assert_system("svn", "add", filename)
        assert_not_system("svn", "commit", "-m", "add hoge", filename)
        assert_system("svn", "rm", "--force", filename)
      end

      %w"hoge_bak".each do |filename|
        open(filename, "w"){|f|f.puts "hoge"}
        assert_system("svn", "add", filename)
        assert_system("svn", "commit", "-m", "add hoge", filename)
      end
    end
  end

  def test_reject_to_update_filename
    File.open("#{@repo}/hooks/svn-pre-commit-checker.conf", "w") do |f|
      f.puts <<-'CONF'
regexp UPDATED, /\.bak\z/ do
  reject 'You should remove temporary files'
end
      CONF
    end

    Dir.chdir(@work) do
      open("hoge.bak", "w"){|f|f.puts "hoge"}
      assert_system("svn add hoge.bak")
      assert_system("svn commit -m 'add hoge.bak'")
    File.open("#{@repo}/hooks/svn-pre-commit-checker.conf", "w") do |f|
      f.puts <<-'CONF'
reject_filename('Do not add temporary files', /\.bak\z/, /\AA/)
reject_filename('You should remove temporary files', /\.bak\z/, /\AU/)
      CONF
    end
      open("hoge.bak", "a"){|f|f.puts "hoge"}
      assert_not_system("svn commit -m 'update hoge.bak'")
      File.unlink("hoge.bak")
      assert_system("svn rm hoge.bak")
      assert_system("svn commit -m 'remove hoge.bak'")
    end
  end

  def test_reject_to_update_filename_old_style
    File.open("#{@repo}/hooks/svn-pre-commit-checker.conf", "w") do |f|
      f.puts <<-'CONF'
reject_filename('You should remove temporary files', /\.bak\z/, /\AU/)
      CONF
    end

    Dir.chdir(@work) do
      open("hoge.bak", "w"){|f|f.puts "hoge"}
      assert_system("svn add hoge.bak")
      assert_system("svn commit -m 'add hoge.bak'")
    File.open("#{@repo}/hooks/svn-pre-commit-checker.conf", "w") do |f|
      f.puts <<-'CONF'
reject_filename('Do not add temporary files', /\.bak\z/, /\AA/)
reject_filename('You should remove temporary files', /\.bak\z/, /\AU/)
      CONF
    end
      open("hoge.bak", "a"){|f|f.puts "hoge"}
      assert_not_system("svn commit -m 'update hoge.bak'")
      File.unlink("hoge.bak")
      assert_system("svn rm hoge.bak")
      assert_system("svn commit -m 'remove hoge.bak'")
    end
  end

  def test_reject_to_add_filename_by_basename
    File.open("#{@repo}/hooks/svn-pre-commit-checker.conf", "w") do |f|
      f.puts <<-'CONF'
basename ANY, '*~', '~*', '*.bak' do
  reject 'Do not add temporary files'
end
      CONF
    end

    Dir.chdir(@work) do
      %w"hoge~ ~hoge hoge.bak".each do |filename|
        open(filename, "w"){|f|f.puts "hoge"}
        assert_system("svn", "add", filename)
        assert_not_system("svn", "commit", "-m", "add hoge", filename)
        assert_system("svn", "rm", "--force", filename)
      end

      %w"ho~ge hoge_bak".each do |filename|
        open(filename, "w"){|f|f.puts "hoge"}
        assert_system("svn", "add", filename)
        assert_system("svn", "commit", "-m", "add hoge", filename)
      end

      Dir.mkdir("d")
      assert_system("svn", "add", "d")
      assert_system("svn", "commit", "-m", "add dir", "d")

      %w"d/~hoge".each do |filename|
        open(filename, "w"){|f|f.puts "hoge"}
        assert_system("svn", "add", filename)
        assert_not_system("svn", "commit", "-m", "add hoge", filename)
      end
    end
  end

  def test_reject_to_update_files_in_tags
    File.open("#{@repo}/hooks/svn-pre-commit-checker.conf", "w") do |f|
      f.puts <<-'CONF'
regexp UPDATED, /(?:\A|\/)tags\// do
  reject 'Do not change files under tags'
end
      CONF
    end
    assert_reject_to_update_files_in_tags
  end

  def test_reject_to_update_files_in_tags_old_style
    File.open("#{@repo}/hooks/svn-pre-commit-checker.conf", "w") do |f|
      f.puts <<-'CONF'
reject_filename('Do not change files in tags', /(?:\A|\/)tags\//, UPDATED)
      CONF
    end
    assert_reject_to_update_files_in_tags
  end

  def assert_reject_to_update_files_in_tags
    Dir.chdir(@work) do
      assert_system("svn mkdir branches tags trunk")
      assert_system("svn commit -m 'Initial directories'")
      open("trunk/hoge.txt", "w"){|f|f.puts "hoge"}
      assert_system("svn add trunk/hoge.txt")
      assert_system("svn commit -m 'add hoge.txt'")
      assert_system("svn cp trunk tags/0.0.1")
      assert_system("svn commit -m '0.0.1 relaesed'")
      open("tags/0.0.1/hoge.txt", "w"){|f|f.puts "hoge hoge"}
      assert_not_system("svn commit -m 'change hoge in tags'")
      open("tags/0.0.1/hoge.txt", "w"){|f|f.puts "hoge hoge"}
      assert_not_system("svn commit -m 'change hoge in tags'")
      assert_system("svn rm --force tags/0.0.1")
      assert_system("svn commit -m 'remove 0.0.1 tag'")
    end
  end
end
