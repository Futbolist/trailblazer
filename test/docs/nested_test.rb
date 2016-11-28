require "test_helper"

class DocsNestedOperationTest < Minitest::Spec
  Song = Struct.new(:id, :title)

  # self.> :bla!
  #   def bla!(options)
  #     self["model"] =
  #       self["result"]["model"]
  #     self["contract.default"] = self["result"]["contract.default"]
  #   end



  #---
  #- nested operations
  class New < Trailblazer::Operation
    extend Contract::DSL

    contract do
      property :id
    end

    self.| Model[Song, :create]
    self.| Contract::Build[]
  end

  class Create < Trailblazer::Operation
    self.| Nested[ New ] #, "policy.default" => self["policy.create"]
    self.| Contract::Validate[]
    self.| Persist[method: :sync]
  end

  puts Create["pipetree"].inspect(style: :rows)

  it do
    result = Create.({ id: 1, title: "Miami" }, "user.current" => Module)
    result.inspect("model").must_equal %{<Result:true [#<struct DocsNestedOperationTest::Song id=1, title=nil>] >}
    # result["model"]
    # result["contract.default"].must_equal ""
  end

  #- shared data
  class B < Trailblazer::Operation
    self.> ->(input, options) { options["can.B.see.it?"] = options["this.should.not.be.visible.in.B"] }
    self.> ->(input, options) { options["can.B.see.user.current?"] = options["user.current"] }
    self.> ->(input, options) { options["can.B.see.A.class.data?"] = options["A.class.data"] }
  end

  class A < Trailblazer::Operation
    self["A.class.data"] = true

    self.> ->(input, options) { options["this.should.not.be.visible.in.B"] = true }
    self.| Nested[ B ]
  end

  # mutual data from A doesn't bleed into B.
  it { A.()["can.B.see.it?"].must_equal nil }
  it { A.()["this.should.not.be.visible.in.B"].must_equal true }
  # runtime dependencies are visible in B.
  it { A.({}, "user.current" => Module)["can.B.see.user.current?"].must_equal Module }
  # class data from A doesn't bleed into B.
  it { A.()["can.B.see.A.class.data?"].must_equal nil }


  # cr_result = Create.({}, "result" => result)
  # puts cr_result["model"]
  # puts cr_result["contract.default"]
end

# =begin
# class New
#   Model[Song, :create]
#   Policy :new
#   self.| :init!

#   def init!

#   end
# end

# class Create < Op
#   self.| New

#   Model[Song, :create]
#   Contract
#   Present
#   Persist
#   ->(*) { Mailer }

#   include Present
# end

# Create.(..., present: true)

# class Update < Create
# end

# =end
