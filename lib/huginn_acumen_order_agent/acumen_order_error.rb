class AcumenOrderError < StandardError
  attr_reader :status, :scope, :data, :original_error

  def initialize(status, scope, message, data, original_error)
    @status = status
    @scope = scope
    @data = data
    @original_error = original_error

    super(message)
  end
end
