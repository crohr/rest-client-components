Gem::Specification.new do |s|
  s.name = "rest-client-components"
  s.version = "1.5.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Cyril Rohr"]
  s.date = "2015-04-03"
  s.description = "RestClient on steroids ! Easily add one or more Rack middleware around RestClient to add functionalities such as transparent caching (Rack::Cache), transparent logging, etc."
  s.email = "cyril.rohr@gmail.com"
  s.extra_rdoc_files = [
    "LICENSE",
    "README.rdoc"
  ]
  s.files = [
    "LICENSE",
    "README.rdoc",
    "Rakefile",
    "VERSION",
    "examples/beautify_html.rb",
    "examples/caching.rb",
    "examples/parsing.rb",
    "lib/restclient/components.rb",
    "rest-client-components.gemspec",
    "spec/components_spec.rb",
    "spec/spec_helper.rb"
  ]
  s.homepage = "http://github.com/crohr/rest-client-components"
  s.rubygems_version = "2.4.5"
  s.summary = "RestClient on steroids ! Easily add one or more Rack middleware around RestClient to add functionalities such as transparent caching (Rack::Cache), transparent logging, etc."
  s.license = "MIT"

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<rest-client>, [">= 1.6.0"])
      s.add_runtime_dependency(%q<rack>, [">= 1.0.1"])
      s.add_development_dependency(%q<webmock>, [">= 1.21"])
      s.add_development_dependency(%q<rspec>, [">= 3.2.0"])
    else
      s.add_dependency(%q<rest-client>, [">= 1.6.0"])
      s.add_dependency(%q<rack>, [">= 1.0.1"])
      s.add_dependency(%q<webmock>, [">= 1.21"])
      s.add_dependency(%q<rspec>, [">= 3.2.0"])
    end
  else
    s.add_dependency(%q<rest-client>, [">= 1.6.0"])
    s.add_dependency(%q<rack>, [">= 1.0.1"])
    s.add_dependency(%q<webmock>, [">= 1.21"])
    s.add_dependency(%q<rspec>, [">= 3.2.0"])
  end
end

