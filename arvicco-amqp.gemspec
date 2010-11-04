Gem::Specification.new do |s|
  s.name        = 'arvicco-amqp'
  s.version     = File.open('VERSION').read.strip
  s.date        = Time.now.strftime "%Y-%m-%d"
  s.summary     = 'Fork of original tmm1/amqp with some tweaks.'
  s.description = "An implementation of the AMQP protocol in Ruby/EventMachine. Fork of original tmm1/amqp with improvements (see README)."
  s.email       = "arvitallian@gmail.com"
  s.authors     = ["Aman Gupta", "Arvicco"]
  s.homepage    = "http://github.com/arvicco/amqp"
  s.platform    = Gem::Platform::RUBY

  # Docs setup
  s.has_rdoc = true
  s.rdoc_options = '--include=examples'
  # ruby -rpp -e' pp `git ls-files`.split("\n").grep(/^(doc|README)/) '
  s.extra_rdoc_files = [
      "README.md",
      "HISTORY",
      "doc/EXAMPLE_01_PINGPONG",
      "doc/EXAMPLE_02_CLOCK",
      "doc/EXAMPLE_03_STOCKS",
      "doc/EXAMPLE_04_MULTICLOCK",
      "doc/EXAMPLE_05_ACK",
      "doc/EXAMPLE_05_POP",
      "doc/EXAMPLE_06_HASHTABLE"
  ]

  # Files setup
  # ruby -rpp -e' pp `git ls-files`.split("\n") '
  versioned  = `git ls-files -z`.split("\0")
  s.files    = Dir['{doc,lib,old,protocol,research,tasks}/**/*', 'Rakefile', 'README*', 'LICENSE*',
                   'VERSION*', 'TODO', 'HISTORY*', 'amqp.*', '.gitignore'] & versioned

  # Dependencies
  s.add_dependency('eventmachine', '>= 0.12.4')
  s.add_development_dependency("bacon", ['>=0.0.0'])
end
