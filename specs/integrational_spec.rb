require_relative 'spec_helper'

# Big builder example text with all possible builder features
module IntegrationalTests
  describe AggregateBuilder::Buildable do
    class Email
      module EmailTypes
        HOME = 0
        WORK = 1
      end
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

      attr_accessor :before_build_value, :after_build_value

      attr_accessor :emails, :address

      def initialize
        @emails  = []
        @address = Address.new
      end
    end

    class EmailBuilder
      include AggregateBuilder::Buildable

      build_rules Email do
        primary_field :id, type: :integer
        field :email
        field :type, type: :integer
      end
    end

    class AddressBuilder
      include AggregateBuilder::Buildable

      build_rules Address do
        primary_field :id, type: :integer
        fields :street, :city, :postal_code, :state
      end
    end

    class ContactBuilder
      include AggregateBuilder::Buildable

      build_config do
        primary_key ->(entity, hash) { entity.id == hash[:id] }

        delete_key ->(hash) { ['1', 'true', 'y', 'yes', true].include?(hash[:_destroy]) }

        log_type :exception
      end

      build_rules_for Contact do
        fields :first_name, :last_name
        field  :rating, type: :integer
        field  :average_rating, type: :float
        field  :date_of_birth, type: :date
        field  :type_id, type: :integer
        field  :is_private, type: :boolean
        field  :created_at, type: :datetime
        field  :company_name

        field :address, type: :object, builder: AddressBuilder, deletable: true

        field :emails, type: :array_of_objects,
          builder: EmailBuilder,
          reject_if: ->(attributes) { attributes[:reject] == true },
          deletable: true

        before_build :before_build_callback

        after_build do |entity, attributes|
          set_after_build_value(entity)
        end
      end

      private

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
        company_name: 'John Doe Inc.',
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

      builder = ContactBuilder.new
      builder.build(attributes)
    end

    its(:first_name)                   { should == 'John' }
    its(:last_name)                    { should == 'Doe' }
    its(:rating)                       { should == 10 }
    its(:average_rating)               { should == 2.1 }
    its(:date_of_birth)                { should == Date.parse('12/09/1965') }
    its(:type_id)                      { should == 3 }
    its(:is_private)                   { should == true }
    its(:created_at)                   { should == DateTime.parse("2013-09-30 08:58:28 +0400") }
    its(:company_name)                 { should == 'John Doe Inc.' }
    its(:before_build_value)           { should == 'BEFORE' }
    its(:after_build_value)            { should == 'AFTER' }

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

        builder = ContactBuilder.new
        contact = builder.build(attributes)
        contact.address
      end

      its(:street)      { should == 'Street' }
      its(:city)        { should == 'City' }
      its(:postal_code) { should == 'Code' }
      its(:state)       { should == 'State' }
    end

    context "Children building" do
      subject do
        attributes = {
          emails: [
            {email: 'test@example.com', type: 0},
            {id: 1, email: 'user@example.com', type: 1, _destroy: true},
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
        builder = ContactBuilder.new
        contact = builder.update(contact, attributes)
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
end
