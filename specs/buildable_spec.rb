require_relative 'spec_helper'

describe AggregateBuilder::Buildable do
  class Emails < Array
    attr_accessor :email, :email_type
  end

  class Address
    attr_accessor :street, :city, :postal_code, :state
  end

  class Contact
    module ContactTypes
      PERSON  = 0
      COMPANY = 1
    end

    attr_accessor :first_name, :last_name, :type_id, :date_of_birth, :is_private,
                  :rating, :average_rating, :created_at, :company_name

    def initialize
      @emails  = Emails.new
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

  context "Assign attributes" do
    class FullContactBuilder
      include AggregateBuilder::Buildable

      build_rules_for Contact do
        #config do
          search_key :id do |entity_key, key|
            if key.present?
              entity_key == key.to_s.to_i
            end
          end

          delete_key :_destroy do |value|
            ['1', 'true'].include?(value)
          end

          unmapped_fields_error_level :warn#, :error, :silent
        #end

        fields :first_name, :last_name, required: true
        field  :rating, type: :integer, required: true
        field  :average_rating, type: :float
        field  :date_of_birth, type: :date
        field  :type_id, type: :integer, required: true
        field  :is_private, type: :boolean
        field  :created_at, type: :time
        field  :company_name do |entity, attributes|
          'John Doe Inc.'
        end

        before_build do |entity|
        end

        after_build do |entity|
        end
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
        created_at: "2013-09-30 08:58:28 +0400"
      }

      builder = FullContactBuilder.new
      builder.build(nil, attributes)
    end

    its(:first_name)      { should == 'John' }
    its(:last_name)       { should == 'Doe' }
    its(:rating)          { should == 10 }
    its(:average_rating)  { should == 2.1 }
    its(:date_of_birth)   { should == Date.parse('12/09/1965') }
    its(:type_id)         { should == 3 }
    its(:is_private)      { should == true }
    its(:created_at)      { should == Time.new("2013-09-30 08:58:28 +0400") }
    its(:company_name)    { should == 'John Doe Inc.' }
  end
end
