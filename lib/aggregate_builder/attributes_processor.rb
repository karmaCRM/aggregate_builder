module AggregateBuilder
  class AttributesProcessor < BaseProcessor
    def initialize(builder_rules, builder)
      @builder_rules = builder_rules
      @builder       = builder
    end

    def process(attributes, entity)
      keys = extract_attributes_keys(attributes)
      @attributes = attributes
      @entity     = entity
      processed_attributes = {}
      @builder_rules.fields_collection.each do |field|
        field_key = find_key_or_alias(field, keys)
        value = process_attribute(field, field_key)
        processed_attributes[field.field_name] = value
      end
      processed_attributes
    end

    private

    def process_attribute(field, field_key)
      if !field_key && required_field?(field)
        log_missing_attribute(field)
      end

      value = @builder.instance_exec(
        @entity,
        @attributes,
        &field.value_processor
      ) if field.has_processing?

      field_key ||= field.field_name
      clean_value(field, field_key, value)
    end

    def required_field?(field)
      if field.required
        if field.required.is_a?(Symbol)
          @builder.send(field.required, @entity, @attributes)
        else
          true
        end
      end
    end

    def clean_value(field, field_key, value)
      value ||= @attributes[field_key] || @attributes[field_key.to_s]
      klass = type_caster_class(field)
      type_caster_class(field).clean(value)
    rescue => e
      if @builder_rules.silent_level?
        nil
      elsif @builder_rules.warn_level?
        p e.message
        nil
      elsif @builder_rules.error_level?
        raise e
      end
    end

    def type_caster_class(field)
      if field.type.is_a?(Class)
        field.type
      else
        type = field.type.to_s.classify
        "AggregateBuilder::TypeCasters::#{type}Caster".constantize
      end
    end

    def log_missing_attribute(field)
      if @builder_rules.warn_level?
        p "Warning: Required field #{field.field_name} is missing for #{@builder.class} builder"
      elsif @builder_rules.error_level?
        raise Errors::RequireAttributeMissingError, "Required field #{field.field_name} is missing for #{@builder.class} builder"
      end
    end
  end
end
