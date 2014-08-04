module AggregateBuilder
  class FieldBuilders::FloatFieldBuilder < FieldBuilders::PrimitiveFieldBuilder

    def self.cast(field_name, value)
      if value.is_a?(Float)
        value
      elsif value.is_a?(Integer)
        Float(value)
      elsif value.is_a?(String)
        Float(value)
      elsif value.nil?
        raise Errors::TypeCastingError, "#{field_name} can't be nil"
      else
        raise Errors::TypeCastingError, "Expected to be a float value, got #{value.inspect} for #{field_name}"
      end
    rescue => e
      raise Errors::TypeCastingError, "Expected to be a float value, got #{value} for #{field_name}"
    end

  end
end
