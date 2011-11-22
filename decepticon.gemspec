# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "decepticon/version"

Gem::Specification.new do |s|
  s.name        = "decepticon"
  s.version     = DeceptiCon::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Sujimichi"]
  s.email       = ["sujimichi@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{A way to simplify rails controller specs by generating the simple response tests }
  s.description = %q{A way to simplify rails controller specs by generating the simple response tests }

  s.rubyforge_project = "decepticon"

  s.add_development_dependency('rspec')
  s.add_development_dependency('ZenTest')

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

end
