# Work correctly with older versions of Psych, having
# unsafe_load call load (in older versions, load operates
# as unsafe_load in current version).
unless YAML.respond_to?(:unsafe_load)
  def YAML.unsafe_load(body)
    load(body)
  end
end
