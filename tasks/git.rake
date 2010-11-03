desc "Alias to git:commit"
task :git => 'git:commit'

namespace :git do

  desc "Stage and commit your work [with message]"
  task :commit, [:message] do |t, args|
    puts "Staging new (unversioned) files"
    system "git add --all"
    if args.message
      puts "Committing with message: #{args.message}"
      system %Q[git commit -a -m "#{args.message}" --author arvicco]
    else
      puts "Committing"
      system %Q[git commit -a -m "No message" --author arvicco]
    end
  end

  desc "Push local changes to Github"
  task :push => :commit do
    puts "Pushing local changes to remote"
    system "git push"
  end

  desc "Create (release) tag on Github"
  task :tag => :push do
    tag = VERSION
    puts "Creating git tag: #{tag}"
    system %Q{git tag -a -m "Release tag #{tag}" #{tag}}
    puts "Pushing #{tag} to remote"
    system "git push origin #{tag}"
  end

end