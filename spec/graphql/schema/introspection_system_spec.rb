# frozen_string_literal: true
require "spec_helper"

describe GraphQL::Schema::IntrospectionSystem do
  describe "custom introspection" do
    it "serves custom fields on types" do
      res = Jazz::Schema.execute("{ __schema { isJazzy } }")
      assert_equal true, res["data"]["__schema"]["isJazzy"]
    end

    it "serves overridden fields on types" do
      res = Jazz::Schema.execute(%|{ __type(name: "Ensemble") { name } }|)
      assert_equal "ENSEMBLE", res["data"]["__type"]["name"]
    end

    it "serves custom entry points" do
      res = Jazz::Schema.execute("{ __classname }", root_value: Set.new)
      assert_equal "Set", res["data"]["__classname"]
    end

    it "calls authorization methods of those types" do
      res = Jazz::Schema.execute(%|{ __type(name: "Ensemble") { name } }|)
      assert_equal "ENSEMBLE", res["data"]["__type"]["name"]

      unauth_res = Jazz::Schema.execute(%|{ __type(name: "Ensemble") { name } }|, context: { cant_introspect: true })
      assert_nil unauth_res["data"].fetch("__type")
      assert_equal ["You're not allowed to introspect here"], unauth_res["errors"].map { |e| e["message"] }
    end

    it "serves custom dynamic fields" do
      res = Jazz::Schema.execute("{ nowPlaying { __typename __typenameLength __astNodeClass } }")
      assert_equal "Ensemble", res["data"]["nowPlaying"]["__typename"]
      assert_equal 8, res["data"]["nowPlaying"]["__typenameLength"]
      assert_equal "GraphQL::Language::Nodes::Field", res["data"]["nowPlaying"]["__astNodeClass"]
    end

    it "doesn't affect other schemas" do
      res = Dummy::Schema.execute("{ __schema { isJazzy } }")
      assert_equal 1, res["errors"].length

      res = Dummy::Schema.execute("{ __classname }", root_value: Set.new)
      assert_equal 1, res["errors"].length

      res = Dummy::Schema.execute("{ ensembles { __typenameLength } }")
      assert_equal 1, res["errors"].length
    end

    it "runs the introspection query" do
      res = Jazz::Schema.execute(GraphQL::Introspection::INTROSPECTION_QUERY)
      assert res
      query_type = res["data"]["__schema"]["types"].find { |t| t["name"] == "QUERY" }
      ensembles_field = query_type["fields"].find { |f| f["name"] == "ensembles" }
      assert_equal [], ensembles_field["args"]
    end

    it "runs the introspection query and the result contains a edge field that has non-nullable node" do
      res = NonNullableDummy::Schema.execute(GraphQL::Introspection::INTROSPECTION_QUERY)
      assert res
      edge_type = res["data"]["__schema"]["types"].find { |t| t["name"] == "NonNullableNodeEdge" }
      node_field = edge_type["fields"].find { |f| f["name"] == "node" }
      assert_equal "NON_NULL", node_field["type"]["kind"]
      assert_equal "NonNullableNode", node_field["type"]["ofType"]["name"]
    end
  end
end
