class ClosableBody
  def initialize(content)
    @content = content
    @closed = false
  end

  def each
    yield @content
  end

  def close
    @closed = true
  end

  def closed?
    @closed
  end
end