defmodule TdQx.Search.ElasticEncodeTest do
  use TdQxWeb.ConnCase

  alias Elasticsearch.Document

  @test_template %{
    id: 5,
    label: "score_group",
    name: "foo",
    scope: "qxe",
    content: [
      %{
        "fields" => [
          %{
            "cardinality" => "?",
            "default" => %{"origin" => "default", "value" => ""},
            "label" => "Quality Principle",
            "name" => "Quality Principle",
            "subscribable" => false,
            "type" => "string",
            "values" => %{
              "fixed" => [
                "Completeness",
                "Accuracy",
                "Consistency",
                "Timeliness",
                "Validity",
                "Uniqueness"
              ]
            },
            "widget" => "dropdown"
          },
          %{
            "cardinality" => "?",
            "default" => %{"origin" => "default", "value" => ""},
            "label" => "Frequency",
            "name" => "Frequency",
            "subscribable" => false,
            "type" => "string",
            "values" => %{"fixed" => ["Daily", "Weekly"]},
            "widget" => "dropdown"
          }
        ],
        "name" => ""
      }
    ]
  }

  describe "encode/1" do
    test "the content of score groups should have a format without origin" do
      %{id: user_id} = user = CacheHelpers.insert_user()
      created_by = %{id: user.id, user_name: user.user_name, full_name: user.full_name}

      %{id: score_group_id} =
        score_group =
        insert(:score_group,
          created_by: user_id,
          df_type: "foo",
          dynamic_content: %{
            "Frequency" => %{"origin" => "user", "value" => "Weekly"},
            "Quality Principle" => %{"origin" => "user", "value" => "Accuracy"}
          }
        )
        |> Map.put(:template, @test_template)

      legacy_content = %{
        "Frequency" => "Weekly",
        "Quality Principle" => "Accuracy"
      }

      assert %{
               id: ^score_group_id,
               dynamic_content: score_content,
               created_by: ^created_by
             } =
               Document.encode(score_group)

      assert legacy_content == score_content
    end
  end
end
