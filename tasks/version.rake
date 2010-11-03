class Version
  attr_accessor :major, :minor, :patch, :build

  def initialize(version_string)
    raise "Invalid version #{version_string}" unless version_string =~ /^(\d+)\.(\d+)\.(\d+)(?:\.(.*?))?$/
    @major = $1.to_i
    @minor = $2.to_i
    @patch = $3.to_i
    @build = $4
  end

  def bump_major(x)
    @major += x.to_i
    @minor = 0
    @patch = 0
    @build = nil
  end

  def bump_minor(x)
    @minor += x.to_i
    @patch = 0
    @build = nil
  end

  def bump_patch(x)
    @patch += x.to_i
    @build = nil
  end

  def update(major, minor, patch, build=nil)
    @major = major
    @minor = minor
    @patch = patch
    @build = build
  end

  def write(desc = nil)
    CLASS_NAME::VERSION_FILE.open('w') {|file| file.puts to_s }
    (BASE_PATH + 'HISTORY').open('a') do |file|
      file.puts "\n== #{to_s} / #{Time.now.strftime '%Y-%m-%d'}\n"
      file.puts "\n* #{desc}\n" if desc
    end
  end

  def to_s
    [major, minor, patch, build].compact.join('.')
  end
end

desc 'Set version: [x.y.z] - explicitly, [1/10/100] - bump major/minor/patch, [.build] - build'
task :version, [:command, :desc] do |t, args|
  version = Version.new(VERSION)
  case args.command
    when /^(\d+)\.(\d+)\.(\d+)(?:\.(.*?))?$/  # Set version explicitly
      version.update($1, $2, $3, $4)
    when /^\.(.*?)$/                        # Set build
      version.build = $1
    when /^(\d{1})$/                          # Bump patch
      version.bump_patch $1
    when /^(\d{1})0$/                         # Bump minor
      version.bump_minor $1
    when /^(\d{1})00$/                        # Bump major
      version.bump_major $1
    else                                      # Unknown command, just display VERSION
      puts "#{NAME} #{version}"
      next
  end

  puts "Writing version #{version} to VERSION file"
  version.write args.desc
end
