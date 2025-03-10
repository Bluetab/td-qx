defmodule TdQxWeb.ScoreGroupControllerTest do
  use TdQxWeb.ConnCase

  alias TdCluster.TestHelpers.TdDfMock
  alias TdCore.Search.IndexWorkerMock

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  setup {Mox, :verify_on_exit!}

  describe "index - GET /api/score_groups" do
    @tag authentication: [role: "admin"]
    test "Admin gets user's score groups", %{conn: conn, claims: %{user_id: user_id}} do
      user_group_ids = for _ <- 1..3, do: insert(:score_group, created_by: user_id).id

      for _ <- 1..3, do: insert(:score_group)

      %{"data" => response} =
        conn
        |> get(~p"/api/score_groups?created_by=me")
        |> json_response(:ok)

      response_ids =
        response
        |> Enum.map(& &1["id"])
        |> Enum.sort()

      assert response_ids == user_group_ids
    end

    @tag authentication: [role: "user", permissions: [:execute_quality_controls]]
    test "User with permissions gets user's score groups", %{
      conn: conn,
      claims: %{user_id: user_id}
    } do
      user_group_ids = for _ <- 1..3, do: insert(:score_group, created_by: user_id).id

      for _ <- 1..3, do: insert(:score_group)

      %{"data" => data} =
        conn
        |> get(~p"/api/score_groups?created_by=me")
        |> json_response(:ok)

      response_ids =
        data
        |> Enum.map(& &1["id"])
        |> Enum.sort()

      assert response_ids == user_group_ids
    end

    @tag authentication: [role: "admin"]
    test "response contains status summary", %{conn: conn, claims: %{user_id: user_id}} do
      score_group = insert(:score_group, created_by: user_id)

      insert(:score_event, type: "PENDING", score: build(:score, group: score_group))
      insert(:score_event, type: "PENDING", score: build(:score, group: score_group))
      insert(:score_event, type: "STARTED", score: build(:score, group: score_group))
      insert(:score_event, type: "QUEUED", score: build(:score, group: score_group))
      insert(:score_event, type: "TIMEOUT", score: build(:score, group: score_group))
      insert(:score_event, type: "FAILED", score: build(:score, group: score_group))
      insert(:score_event, type: "SUCCEEDED", score: build(:score, group: score_group))

      %{"data" => [%{"status_summary" => status_summary}]} =
        conn
        |> get(~p"/api/score_groups?created_by=me")
        |> json_response(:ok)

      assert %{
               "PENDING" => 2,
               "STARTED" => 1,
               "QUEUED" => 1,
               "TIMEOUT" => 1,
               "FAILED" => 1,
               "SUCCEEDED" => 1
             } = status_summary
    end

    @tag authentication: [role: "user"]
    test "forbidden for user without permissions", %{conn: conn} do
      assert %{"errors" => %{"detail" => "Forbidden"}} ==
               conn
               |> get(~p"/api/score_groups?created_by=me")
               |> json_response(:forbidden)
    end

    @tag authentication: [role: "admin"]
    test "invalid request without created_by param", %{conn: conn} do
      assert %{"errors" => %{"detail" => "Unprocessable Entity"}} ==
               conn
               |> get(~p"/api/score_groups")
               |> json_response(:unprocessable_entity)
    end
  end

  describe "show - GET /api/score_groups/:id" do
    @tag authentication: [role: "admin"]
    test "Admin gets score group", %{conn: conn} do
      %{id: id, df_type: df_type, dynamic_content: dynamic_content, created_by: created_by} =
        score_group = insert(:score_group)

      %{id: score_id} = score = insert(:score, group: score_group)
      insert(:score_event, type: "PENDING", score: score)

      %{"data" => response} =
        conn
        |> get(~p"/api/score_groups/#{id}")
        |> json_response(:ok)

      assert %{
               "id" => ^id,
               "df_type" => ^df_type,
               "dynamic_content" => ^dynamic_content,
               "created_by" => ^created_by,
               "scores" => [
                 %{
                   "id" => ^score_id,
                   "status" => "PENDING"
                 }
               ]
             } = response
    end

    @tag authentication: [role: "admin"]
    test "enriches Score's QualityControlVersion", %{conn: conn} do
      %{id: id, df_type: df_type, dynamic_content: dynamic_content, created_by: created_by} =
        score_group = insert(:score_group)

      %{id: score_id} =
        score =
        insert(:score,
          group: score_group,
          quality_control_version:
            build(:quality_control_version,
              name: "QualityControlName",
              quality_control: build(:quality_control)
            )
        )

      insert(:score_event, type: "PENDING", score: score)

      %{"data" => response} =
        conn
        |> get(~p"/api/score_groups/#{id}")
        |> json_response(:ok)

      assert %{
               "id" => ^id,
               "df_type" => ^df_type,
               "dynamic_content" => ^dynamic_content,
               "created_by" => ^created_by,
               "scores" => [
                 %{
                   "id" => ^score_id,
                   "status" => "PENDING",
                   "quality_control" => %{
                     "name" => "QualityControlName"
                   }
                 }
               ]
             } = response
    end
  end

  describe "create - POST /api/score_groups" do
    @tag authentication: [role: "admin"]
    test "admin can create score group passing quality_controls search", %{
      conn: conn,
      claims: %{user_id: user_id}
    } do
      IndexWorkerMock.clear()

      quality_controls =
        for _ <- 1..3 do
          qc = insert(:quality_control)
          qcv = insert(:quality_control_version, status: "published", quality_control: qc)
          %{qc | latest_version: qcv}
        end

      template_name = "type"

      TdDfMock.list_templates_by_scope(
        &Mox.expect/4,
        "quality_control",
        {:ok, []}
      )

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok, %{content: []}}
      )

      ElasticsearchMock
      |> Mox.expect(:request, fn _, :post, "/quality_controls/_search", params, _ ->
        assert %{
                 query: %{
                   bool: %{
                     must: [
                       %{
                         multi_match: %{
                           type: "bool_prefix",
                           fields: ["ngram_name*^3"],
                           query: "",
                           fuzziness: "AUTO",
                           lenient: true
                         }
                       },
                       %{term: %{"active" => true}}
                     ]
                   }
                 }
               } = params

        SearchHelpers.hits_response(quality_controls)
      end)

      creation_params = %{
        "score_group" => %{
          "dynamic_content" => %{},
          "df_type" => template_name
        },
        "search" => %{
          "query" => "",
          "must" => %{"for_execution" => [true]}
        }
      }

      assert %{"id" => id} =
               conn
               |> post(~p"/api/score_groups", creation_params)
               |> json_response(201)
               |> Map.get("data")

      %{"data" => response} =
        conn
        |> get(~p"/api/score_groups/#{id}")
        |> json_response(:ok)

      assert %{
               "df_type" => ^template_name,
               "created_by" => ^user_id,
               "scores" => [
                 %{"status" => "PENDING"},
                 %{"status" => "PENDING"},
                 %{"status" => "PENDING"}
               ]
             } = response

      assert IndexWorkerMock.calls() == [{:reindex, :score_groups, [id]}]
    end

    @tag authentication: [role: "admin"]
    test "admin can create score group passing quality_control_versions ids", %{
      conn: conn,
      claims: %{user_id: user_id}
    } do
      IndexWorkerMock.clear()

      quality_control_version_ids =
        for _ <- 1..3,
            do:
              insert(:quality_control_version,
                status: "published",
                quality_control: build(:quality_control)
              ).id

      template_name = "type"

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok, %{content: []}}
      )

      creation_params = %{
        "score_group" => %{
          "dynamic_content" => %{},
          "df_type" => template_name
        },
        "ids" => quality_control_version_ids
      }

      assert %{"id" => id} =
               conn
               |> post(~p"/api/score_groups", creation_params)
               |> json_response(201)
               |> Map.get("data")

      %{"data" => response} =
        conn
        |> get(~p"/api/score_groups/#{id}")
        |> json_response(:ok)

      assert %{
               "df_type" => ^template_name,
               "created_by" => ^user_id,
               "scores" => [
                 %{"status" => "PENDING"},
                 %{"status" => "PENDING"},
                 %{"status" => "PENDING"}
               ]
             } = response

      assert IndexWorkerMock.calls() == [{:reindex, :score_groups, [id]}]
    end
  end
end
