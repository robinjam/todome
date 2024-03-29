deploy_to = "/srv/www/todome"
repository = "git://github.com/robinjam/TodoMe.git"
branch = "master"

target = "#{deploy_to}/current"
timestamp = Time.now.utc.strftime("%Y-%m-%d-%H-%M-%S")

def run(cmd)
  server = "todome@ec2-176-34-195-131.eu-west-1.compute.amazonaws.com"
  result = `ssh #{server} \"#{cmd}\" 2>&1`
  if $?.exitstatus != 0
    puts "  ! Command failed: #{cmd}"
    puts "  ! Exit status:    #{$?.exitstatus}"
    puts "  ! Result:         #{result}"
    raise
  end
  result
end

namespace :deploy do
  task :setup do
    puts " => Prepare application for deployment"
    run "mkdir -p #{deploy_to}/releases #{deploy_to}/shared/assets #{deploy_to}/shared/system #{deploy_to}/shared/bundle #{deploy_to}/shared/log"
  end

  task :checkout do
    puts " => Check out code"
    target = "#{deploy_to}/releases/#{timestamp}"
    run [
      "mkdir #{target}",
      "git clone -b #{branch} #{repository} #{target}",
      "rm -rf #{target}/.git #{target}/log #{target}/public/assets #{target}/public/system",
      "ln -s #{deploy_to}/shared/log #{target}/log",
      "ln -s #{deploy_to}/shared/assets #{target}/public/assets",
      "ln -s #{deploy_to}/shared/system #{target}/public/system"
    ].join(" && ")
  end

  task :bundle do
    puts " => Install gems"
    run "cd #{target} && bundle install --deployment --path #{deploy_to}/shared/bundle"
  end

  task :migrate do
    puts " => Migrate database"
    run [
      "ln -sf #{deploy_to}/shared/production.sqlite3 #{target}/db/production.sqlite3",
      "cd #{target}",
      "env RAILS_ENV=production bundle exec rake db:migrate"
    ].join(" && ")
  end

  namespace :assets do
    task :precompile do
      puts " => Precompile assets"
      run "cd #{target} && env RAILS_ENV=production bundle exec rake assets:precompile"
    end
  end

  task :symlink do
    puts " => Symlink"
    run "ln -fns #{target} #{deploy_to}/current"
  end

  task :restart do
    puts " => Restart"
    run "touch #{target}/tmp/restart.txt"
  end

  task :rollback do
    puts " => Rollback"
    releases = run("ls -x #{deploy_to}/releases").split.sort
    raise "Cannot rollback when there are less than 2 releases" if releases.length < 2
    target = "#{deploy_to}/releases/#{releases[-2]}"
    Rake::Task["deploy:symlink"].execute
    Rake::Task["deploy:restart"].execute
    puts " => Cleanup"
    run "rm -rf #{deploy_to}/releases/#{releases.last}"
    puts " => Successfully rolled back to revision #{releases[-2]}."
  end
end

task :deploy => ["deploy:setup", "deploy:checkout", "deploy:bundle", "deploy:migrate", "deploy:assets:precompile", "deploy:symlink", "deploy:restart"] do
  puts " => Successfully deployed."
end
