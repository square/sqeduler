# frozen_string_literal: true

require "spec_helper"
require "sqeduler"

RSpec.describe Sqeduler do
  it "should have a VERSION constant" do
    expect(subject.const_get("VERSION")).not_to be_empty
  end
end
