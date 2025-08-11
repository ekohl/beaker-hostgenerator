require 'yaml'

require 'beaker-hostgenerator'
require 'beaker-hostgenerator/data'

module GeneratorTestHelpers
  include BeakerHostGenerator::Data

  def run_cli_with_options(options = [])
    cli = BeakerHostGenerator::CLI.new(options)
    yaml_string = cli.execute

    YAML.load(yaml_string)
  end

  def open_file(path)
    # Takes a list of path elements.
    # Returns a file object where the basename of the file is the last path
    # element.
    dirname = File.join(path[1, path.length - 2]) # wtf
    filename = File.join(path)
    FileUtils.mkdir_p(dirname)
    File.open(filename, 'w')
  end

  def generate_fixture(relative_path, options, spec, environment_variables = {})
    specopts = options + [spec]
    arguments_string = specopts.join(' ')

    environment_variables.each do |key, value|
      ENV[key] = value
    end
    generated_hash = run_cli_with_options(specopts)
    environment_variables.each_key do |key|
      ENV[key] = nil
    end

    fixture_hash = {
      'arguments_string' => arguments_string,
      'environment_variables' => environment_variables,
      'expected_hash' => generated_hash,
      'expected_exception' => nil,
    }
    fixture_yaml = fixture_hash.to_yaml

    fixture_file = open_file([Dir.pwd, @fixture_root] + relative_path + [spec])
    fixture_file.write(fixture_yaml)
  end

  def generate_fixtures_using_osinfo(relative_path,
                                     role_enumerator,
                                     options = [],
                                     bhg_version = 0)
    platforms = get_platforms(bhg_version)
    platforms.each do |platform_info|
      role = role_enumerator.next
      spec = "#{platform_info}" + role
      generate_fixture(relative_path, options, spec)
    end
  end
end

class FixtureGenerator
  include GeneratorTestHelpers

  def initialize
    @fixture_root = 'test/fixtures/generated/'
    @simple_roles = %w[a u l c d f m aulcdfm]
  end

  def generate
    # Validates single-host scenarios using all short-form role aliases with no
    # optional flags'
    generate_fixtures_using_osinfo(['default'], @simple_roles.cycle, [])

    # Validates single-host scenarios using all short-form role aliases with the
    # addition of the --osinfo-version flag to indicate which BHG version to
    # generate host configs for.
    [0, 1].each do |bhg_version|
      generate_fixtures_using_osinfo(["osinfo-version-#{bhg_version}"],
                                     @simple_roles.cycle,
                                     ['--osinfo-version', "#{bhg_version}"],
                                     bhg_version)
    end

    # Validates multi-platform specs
    get_platforms(0).zip(
      get_platforms(1).reverse,
      get_platforms(0),
      @simple_roles.cycle,
      @simple_roles.reverse.cycle,
    ) do |p1, p2, p3, r1, r2|
      generate_fixture(['multiplatform'], [], "#{p1}#{r1}-#{p2}-#{p3}#{r2}")
    end
  end
end
