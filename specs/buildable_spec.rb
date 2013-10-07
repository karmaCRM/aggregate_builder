require_relative 'spec_helper'

describe AggregateBuilder::Buildable do
  class Email
    attr_accessor :email, :type, :id
  end

  class Address
    attr_accessor :street, :city, :postal_code, :state, :id
  end

  class Contact
    module ContactTypes
      PERSON  = 0
      COMPANY = 1
    end

    attr_accessor :first_name, :last_name, :type_id, :date_of_birth, :is_private,
                  :rating, :average_rating, :created_at, :company_name, :id

    attr_accessor :before_build_value, :after_build_value, :before_build_children_value

    attr_accessor :emails, :address

    def initialize
      @emails  = []
      @address = Address.new
    end
  end

  context "Set root class" do
    it "should set specified root class" do
      class TestBuilder
        include AggregateBuilder::Buildable

        build_rules_for Contact do
        end
      end

      rules = TestBuilder.send(:builder_rules)
      rules.root_class.should == Contact
    end

    it "should properly define root class from aggregate name" do
      class ContactBuilder
        include AggregateBuilder::Buildable

        build_rules do
        end
      end

      rules = ContactBuilder.send(:builder_rules)
      rules.root_class.should == Contact
    end

    it "should raise error when root class was not defined" do
      expect do
        class TestFactory
          include AggregateBuilder::Buildable

          build_rules do
          end
        end
      end.to raise_error(AggregateBuilder::Errors::UndefinedRootClassError)
    end
  end

  context "Build defaults" do
    it "should allows to assign defaults" do
      class DefaultBuilder
        include AggregateBuilder::Buildable

        build_defaults do
          before_build :setup_defaults
        end

        def setup_defaults
        end
      end

      rules = DefaultBuilder.send(:builder_rules)
      rules.callbacks.callbacks_by_type(:before).size.should == 1
    end
  end

  context "Assign attributes" do
    class EmailBuilder
      include AggregateBuilder::Buildable

      build_rules do
        field :email, required: true
        field :type, type: :integer, required: true
      end
    end

    class AddressBuilder
      include AggregateBuilder::Buildable

      build_rules do
        fields :street, :city, :postal_code, :state
      end
    end

    class FullContactBuilder
      include AggregateBuilder::Buildable

      config_builder do
        search_key :id do |id|
          id.to_s.to_i
        end

        delete_key :_destroy do |value|
          ['1', 'true', 'y', 'yes'].include?(value)
        end

        unmapped_fields_error_level :warn#, :error, :silent
      end

      build_rules_for Contact do
        fields :first_name, :last_name
        field  :rating, type: :integer do |entity, attributes|
          attribute_for :rating, attributes
        end
        field  :average_rating, type: :float
        field  :date_of_birth, type: :date
        field  :type_id, type: :integer
        field  :is_private, type: :boolean
        field  :created_at, type: :time
        field  :company_name do |entity, attributes|
          default_company_name
        end

        before_build_children do |entity, attributes|
          entity.before_build_children_value = "BEFORE BUILD CHILDREN"
        end

        build_children :address do
          builder :address_builder
          deletable true
        end

        build_children :emails do
          builder EmailBuilder

          reject_if do |entity, attributes|
            attributes[:reject] == true
          end

          deletable true
        end

        before_build :before_build_callback

        after_build do |entity, attributes|
          set_after_build_value(entity)
        end
      end

      private

      def address_builder
        AddressBuilder.new
      end

      def default_company_name
        'John Doe Inc.'
      end

      def before_build_callback(entity, attributes)
        entity.before_build_value = 'BEFORE'
      end

      def set_after_build_value(entity)
        entity.after_build_value = 'AFTER'
      end
    end

    subject do
      attributes = {
        first_name: 'John',
        last_name: 'Doe',
        rating: 10,
        average_rating: '2.1',
        date_of_birth: '12/09/1965',
        type_id: 3,
        is_private: true,
        created_at: "2013-09-30 08:58:28 +0400",
        emails: [
          {email: 'test@example.com', type: 0},
          {email: 'user@example.com', type: 1}
        ],
        address: {
          street: 'Street',
          city: 'City',
          postal_code: 'Code',
          state: 'State'
        }
      }

      builder = FullContactBuilder.new
      builder.build(nil, attributes)
    end

    its(:first_name)                   { should == 'John' }
    its(:last_name)                    { should == 'Doe' }
    its(:rating)                       { should == 10 }
    its(:average_rating)               { should == 2.1 }
    its(:date_of_birth)                { should == Date.parse('12/09/1965') }
    its(:type_id)                      { should == 3 }
    its(:is_private)                   { should == true }
    its(:created_at)                   { should == Time.new("2013-09-30 08:58:28 +0400") }
    its(:company_name)                 { should == 'John Doe Inc.' }
    its(:before_build_value)           { should == 'BEFORE' }
    its(:after_build_value)            { should == 'AFTER' }
    its(:before_build_children_value)  { should == "BEFORE BUILD CHILDREN" }

    context "Child processing" do
      subject do
        attributes = {
          address: {
            street: 'Street',
            city: 'City',
            postal_code: 'Code',
            state: 'State'
          }
        }

        builder = FullContactBuilder.new
        contact = builder.build(nil, attributes)
        contact.address
      end

      its(:street)      { should == 'Street' }
      its(:city)        { should == 'City' }
      its(:postal_code) { should == 'Code' }
      its(:state)       { should == 'State' }
    end

    context "Children processing" do
      subject do
        attributes = {
          emails: [
            {email: 'test@example.com', type: 0},
            {id: 1, email: 'user@example.com', type: 1, _destroy: '1'},
            {reject: true, email: 'user@example.com', type: 1}
          ]
        }

        contact = Contact.new
        email = Email.new
        email.id = 1
        contact.emails << email
        email = Email.new
        email.id = 2
        contact.emails << email
        builder = FullContactBuilder.new
        contact = builder.build(contact, attributes)
      end

      it "should remove existing child" do
        subject.emails.count.should == 2
      end

      it "should properly build attributes for child" do
        email = subject.emails.last
        email.email.should == 'test@example.com'
        email.type.should == 0
      end
    end
  end

  context "Required fields" do
    class FieldWithRequirenmnets
      attr_accessor :required_field
      attr_accessor :required_field_with_condition
      attr_accessor :not_required_field
    end

    class RequiredFieldBuilder
      include AggregateBuilder::Buildable

      config_builder do
        unmapped_fields_error_level :error
      end

      build_rules_for FieldWithRequirenmnets do
        field :required_field, required: true
        field :required_field_with_condition, required: :required_condition
        field :not_required_field
      end

      private

      def required_condition(entity, attributes)
        true
      end
    end

    it "should raise error when required field is missing" do
      builder = RequiredFieldBuilder.new
      lambda do
        builder.build(
          nil,
          {required_field_with_condition: 'required_field_with_condition'}
        )
      end.should raise_error(AggregateBuilder::Errors::RequireAttributeMissingError)
    end

    it "should raise error when required field with condition is missing" do
      builder = RequiredFieldBuilder.new
      lambda do
        builder.build(
          nil,
          {required_field: 'required_field'}
        )
      end.should raise_error(AggregateBuilder::Errors::RequireAttributeMissingError)
    end

    it "should not raise error when required field present" do
      builder = RequiredFieldBuilder.new
      lambda do
        field = builder.build(
          nil,
          {
            required_field: 'required',
            required_field_with_condition: 'required_field_with_condition'
          }
        )
      end.should_not raise_error
    end
  end

  context "Inheritance" do
    class BaseBuilder
      include AggregateBuilder::Buildable

      build_defaults do
        before_build do |entity, attributes|
          'before build call'
        end
      end
    end

    class Company
      attr_accessor :name
    end

    class Deal
      attr_accessor :due_at
    end

    class FirstBuilder < BaseBuilder
      build_rules_for Company do
        field :name
      end
    end

    class SecondBuilder < BaseBuilder
      build_rules_for Deal do
        field :due_at, type: :date
      end
    end

    it "should not have rules from other builders" do
      rules = SecondBuilder.builder_rules
      rules.fields_collection.should have(1).item
    end

    it "should have proper rules" do
      rules = SecondBuilder.builder_rules
      rules.fields_collection.map(&:field_name).should == [:due_at]
    end
  end
end
