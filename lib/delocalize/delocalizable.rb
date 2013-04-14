require 'active_support/concern'

module Delocalize
  module Delocalizable
    extend ActiveSupport::Concern

    module ClassMethods
      def delocalize(conversions = {})
        conversions.each do |field, options|
          delocalizable_fields << field.to_sym unless delocalizable_fields.include?(field.to_sym)
          if options.is_a?(Hash)
            type = options.delete(:type)
          else
            type = options
            options = {}
          end
          delocalize_conversions[field.to_sym] = type.to_sym
          delocalize_options[field.to_sym] = options
          define_delocalize_attr_writer field.to_sym
        end
      end

      def delocalizing?
        delocalizable_fields.any?
      end

      def delocalizes?(field)
        delocalizing? && (delocalizable_fields || []).include?(field.to_sym)
      end

      def delocalize_type_for(field)
        delocalize_conversions[field.to_sym]
      end
      
      def delocalize_options_for(field)
        delocalize_options[field.to_sym]
      end

      def delocalizable_fields
        @delocalizable_fields ||= if superclass.respond_to?(:delocalizable_fields)
          superclass.delocalizable_fields.dup
        else
          []
        end
      end

      def delocalize_conversions
        @delocalize_conversions ||= if superclass.respond_to?(:delocalize_conversions)
          superclass.delocalize_conversions.dup
        else
          {}
        end
      end

      def delocalize_options
        @delocalize_options ||= if superclass.respond_to?(:delocalize_options)
          superclass.delocalize_options.dup
        else
          {}
        end
      end

    private

      def delocalize_attribute_writers
        @delocalize_attribute_writers ||= begin
          mod = Module.new
          include(mod)
          mod
        end
      end

      def define_delocalize_attr_writer(field)
        writer_method = "#{field}="

        delocalize_attribute_writers.module_eval <<-ruby, __FILE__, __LINE__ + 1
          remove_possible_method(:#{writer_method})

          def #{writer_method}(value)
            if Delocalize.enabled? && delocalizes?(:#{field})
              type = delocalize_type_for(:#{field})

              case type
              when :number
                value = LocalizedNumericParser.parse(value) rescue value
              when :date, :time
                value = LocalizedDateTimeParser.parse(value, type.to_s.classify.constantize) rescue value
                value = value.in_time_zone if value.acts_like?(:time)
              end
            end

            write_attribute(:#{field}, value)
          end
        ruby
      end

    end

    def delocalizing?
      self.class.delocalizing?
    end

    def delocalizes?(field)
      self.class.delocalizes?(field)
    end

    def delocalize_type_for(field)
      self.class.delocalize_type_for(field)
    end

    def delocalize_options_for(field)
      self.class.delocalize_options_for(field)
    end
  end
end
