defmodule TdQx.QualityControls.ElasticDocumentTest do
  use TdQx.DataCase

  alias Elasticsearch.Document
  alias TdQx.Scores.Score

  @template %{content: [%{"name" => "group", "fields" => [%{"name" => "foo"}]}]}

  describe "encode/1" do
    test "encodes content" do
      template_name = "df_type"

      quality_control_version =
        insert(:quality_control_version,
          df_type: template_name,
          dynamic_content: %{"foo" => %{"value" => "bar", "origin" => "user"}},
          quality_control: insert(:quality_control)
        )

      quality_control_version = Map.put(quality_control_version, :template, @template)

      document = Document.encode(quality_control_version)

      assert document == %{
               active: quality_control_version.quality_control.active,
               id: quality_control_version.id,
               name: quality_control_version.name,
               status: quality_control_version.status,
               version: quality_control_version.version,
               latest: quality_control_version.latest,
               df_type: quality_control_version.df_type,
               control_mode: quality_control_version.control_mode,
               inserted_at: quality_control_version.inserted_at,
               updated_at: quality_control_version.updated_at,
               dynamic_content: %{"foo" => "bar"},
               ngram_name: quality_control_version.name,
               quality_control_id: quality_control_version.quality_control_id,
               domain_ids: quality_control_version.quality_control.domain_ids,
               latest_score: %{result_message: nil},
               score_criteria: %{goal: 90.0, minimum: 75.0}
             }
    end

    for status <- ["draft", "published"] do
      @tag status: status
      test "encodes content with latest score in a failed status  qcv #{status}",
           %{
             status: status
           } do
        template_name = "df_type"

        quality_control_version =
          insert(:quality_control_version,
            df_type: template_name,
            status: status,
            dynamic_content: %{"foo" => %{"value" => "bar", "origin" => "user"}},
            quality_control: insert(:quality_control)
          )

        {_core_base, latest_score, final_score} =
          get_scores_by_status(status, quality_control_version, nil, nil)

        quality_control_version =
          quality_control_version
          |> Map.put(:template, @template)
          |> Map.put(:latest_score, latest_score)
          |> Map.put(:final_score, final_score)

        document = Document.encode(quality_control_version)
        assert document.latest_score == %{result_message: nil, status: "failed"}
        assert document.score_criteria == %{goal: 90.0, minimum: 75.0}
      end

      @tag status: status
      test "encodes content with latest score with an error count qcv #{status}", %{
        status: status
      } do
        template_name = "df_type"

        quality_control_version =
          insert(:quality_control_version,
            status: status,
            df_type: template_name,
            dynamic_content: %{"foo" => %{"value" => "bar", "origin" => "user"}},
            quality_control: insert(:quality_control),
            control_mode: "count",
            score_criteria: build(:score_criteria, count: build(:sc_count))
          )

        score_content =
          build(:score_content, count: build(:score_content_count))

        {score_base, latest_score, final_score} =
          get_scores_by_status(status, quality_control_version, score_content, "count")

        quality_control_version =
          quality_control_version
          |> Map.put(:template, @template)
          |> Map.put(:latest_score, latest_score)
          |> Map.put(:final_score, final_score)

        document = Document.encode(quality_control_version)

        assert document.latest_score == %{
                 status: "succeeded",
                 executed_at: score_base.execution_timestamp,
                 count_content: %{count: 100},
                 result_message: "under_threshold",
                 type: score_base.score_type,
                 result: 100
               }

        assert document.score_criteria == %{goal: 10, maximum: 100}
      end

      @tag status: status
      test "encodes content with latest score with ratio - deviation qcv #{status}", %{
        status: status
      } do
        template_name = "df_type"

        quality_control_version =
          insert(:quality_control_version,
            status: status,
            df_type: template_name,
            dynamic_content: %{"foo" => %{"value" => "bar", "origin" => "user"}},
            quality_control: insert(:quality_control),
            control_mode: "deviation",
            score_criteria: build(:score_criteria, deviation: build(:sc_deviation))
          )

        score_content = build(:score_content, ratio: build(:score_content_ratio))

        {score_base, latest_score, final_score} =
          get_scores_by_status(status, quality_control_version, score_content, "deviation")

        quality_control_version =
          quality_control_version
          |> Map.put(:template, @template)
          |> Map.put(:latest_score, latest_score)
          |> Map.put(:final_score, final_score)

        document = Document.encode(quality_control_version)

        assert document.latest_score == %{
                 status: "succeeded",
                 executed_at: score_base.execution_timestamp,
                 ratio_content: %{total_count: 10, validation_count: 1},
                 result_message: "under_goal",
                 type: score_base.score_type,
                 result: 10.0
               }

        assert document.score_criteria == %{maximum: 15.0, goal: 5.0}
      end

      @tag status: status
      test "encodes content with latest score with ratio - percentage qcv #{status}", %{
        status: status
      } do
        template_name = "df_type"

        quality_control_version =
          insert(:quality_control_version,
            status: status,
            df_type: template_name,
            dynamic_content: %{"foo" => %{"value" => "bar", "origin" => "user"}},
            quality_control: insert(:quality_control),
            control_mode: "percentage",
            score_criteria: build(:score_criteria, percentage: build(:sc_percentage))
          )

        score_content = build(:score_content, ratio: build(:score_content_ratio))

        {score_base, latest_score, final_score} =
          get_scores_by_status(status, quality_control_version, score_content, "percentage")

        quality_control_version =
          quality_control_version
          |> Map.put(:template, @template)
          |> Map.put(:latest_score, latest_score)
          |> Map.put(:final_score, final_score)

        document = Document.encode(quality_control_version)

        assert document.latest_score == %{
                 status: "succeeded",
                 executed_at: score_base.execution_timestamp,
                 ratio_content: %{total_count: 10, validation_count: 1},
                 result_message: "under_threshold",
                 type: score_base.score_type,
                 result: 10.0
               }

        assert document.score_criteria == %{goal: 90.0, minimum: 75.0}
      end
    end

    test "encodes with no scores published status" do
      template_name = "df_type"

      quality_control_version =
        insert(:quality_control_version,
          df_type: template_name,
          status: "published",
          dynamic_content: %{"foo" => %{"value" => "bar", "origin" => "user"}},
          quality_control: insert(:quality_control)
        )

      quality_control_version =
        quality_control_version
        |> Map.put(:template, @template)
        |> Map.put(:latest_score, nil)
        |> Map.put(:final_score, %Score{})

      document = Document.encode(quality_control_version)
      assert document.latest_score == %{result_message: nil}
    end

    test "encodes with scores with status draft and qcv with published status" do
      template_name = "df_type"

      quality_control_version =
        insert(:quality_control_version,
          df_type: template_name,
          status: "published",
          dynamic_content: %{"foo" => %{"value" => "bar", "origin" => "user"}},
          quality_control: insert(:quality_control)
        )

      score =
        build(:score,
          quality_control_status: "draft",
          score_content:
            build(:score_content,
              ratio: build(:score_content_ratio)
            )
        )

      quality_control_version =
        quality_control_version
        |> Map.put(:template, @template)
        |> Map.put(:latest_score, score)
        |> Map.put(:final_score, %Score{})

      document = Document.encode(quality_control_version)
      assert document.latest_score == %{result_message: nil}
    end
  end

  def get_scores_by_status(status, version, nil, nil) do
    score2 =
      insert(:score, quality_control_version: version, status: "FAILED")

    cond do
      status == "draft" -> {score2, score2, %Score{}}
      status == "published" -> {score2, %Score{}, score2}
    end
  end

  def get_scores_by_status(status, version, score_content, type) do
    score1 =
      insert(:score,
        quality_control_version: version,
        status: "SUCCEEDED",
        score_content: score_content,
        score_type: type
      )

    score2 =
      insert(:score, quality_control_version: version, status: "FAILED")

    cond do
      status == "draft" -> {score1, score1, score2}
      status == "published" -> {score1, score2, score1}
    end
  end
end
