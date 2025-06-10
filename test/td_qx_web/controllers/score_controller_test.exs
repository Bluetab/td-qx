defmodule TdQxWeb.ScoreControllerTest do
  use TdQxWeb.ConnCase

  alias TdCluster.TestHelpers.TdDdMock
  alias TdQx.Scores
  alias TdQxWeb.ScoreController

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "cast_params/2 :fetch_pending" do
    test "casts all params" do
      params = %{
        "sources" => [1, 2],
        "status" => "pending",
        "preload" => [:quality_control_version],
        "foo" => "bar"
      }

      assert {:ok,
              [
                status: "PENDING",
                sources: [1, 2],
                preload: [:quality_control_version]
              ]} = ScoreController.cast_params(:fetch_pending, params)
    end
  end

  describe "index_by_quality_control - POST /api/quality_controls/:quality_control_id/scores" do
    @tag authentication: [role: "admin"]
    test "lists score with enriched status", %{conn: conn} do
      %{
        id: score_id,
        quality_control_version: %{id: qcv_id, quality_control_id: quality_control_id}
      } =
        score = insert(:score)

      insert(:score_event, type: "FAILED", score: score)

      insert(:score_event)
      insert(:score_event)

      assert %{
               "data" => %{
                 "current_page" => 1,
                 "scores" => [
                   %{
                     "id" => ^score_id,
                     "quality_control_version_id" => ^qcv_id,
                     "status" => "FAILED"
                   }
                 ],
                 "total_count" => 1,
                 "total_pages" => 1
               }
             } =
               conn
               |> post(~p"/api/quality_controls/#{quality_control_id}/scores")
               |> json_response(:ok)
    end

    @tag authentication: [role: "user", permissions: ["view_quality_controls"]]
    test "user with permissions", %{conn: conn, domain: %{id: domain_id}} do
      %{id: qcv_id} =
        qcv =
        insert(:quality_control_version,
          quality_control: build(:quality_control, domain_ids: [domain_id])
        )

      %{id: score_id} = score = insert(:score, quality_control_version: qcv)

      insert(:score_event, type: "SUCCEEDED", score: score)

      assert %{
               "data" => %{
                 "current_page" => 1,
                 "scores" => [
                   %{
                     "id" => ^score_id,
                     "quality_control_version_id" => ^qcv_id,
                     "status" => "SUCCEEDED"
                   }
                 ],
                 "total_count" => 1,
                 "total_pages" => 1
               }
             } =
               conn
               |> post(~p"/api/quality_controls/#{qcv.quality_control_id}/scores")
               |> json_response(:ok)
    end

    @tag authentication: [role: "user"]
    test "forbidden for user", %{conn: conn} do
      %{quality_control_version: %{quality_control_id: quality_control_id}} =
        score = insert(:score)

      insert(:score_event, type: "STARTED", score: score)

      assert %{"errors" => %{"detail" => "Forbidden"}} =
               conn
               |> post(~p"/api/quality_controls/#{quality_control_id}/scores")
               |> json_response(:forbidden)
    end
  end

  describe "show - GET /api/scores/:id" do
    @tag authentication: [role: "service"]
    test "shows score", %{conn: conn} do
      %{id: score_id, quality_control_version: %{quality_control_id: quality_control_id}} =
        score = insert(:score)

      %{id: event_id} = insert(:score_event, type: "STARTED", score: score)

      assert %{
               "data" => %{
                 "id" => ^score_id,
                 "status" => "STARTED",
                 "quality_control" => %{
                   "id" => ^quality_control_id
                 },
                 "events" => [
                   %{"id" => ^event_id}
                 ]
               }
             } =
               conn
               |> get(~p"/api/scores/#{score_id}")
               |> json_response(:ok)
    end

    @tag authentication: [role: "user"]
    test "forbidden for user", %{conn: conn} do
      %{id: score_id} = score = insert(:score)

      insert(:score_event, type: "STARTED", score: score)

      assert %{"errors" => %{"detail" => "Forbidden"}} =
               conn
               |> get(~p"/api/scores/#{score_id}")
               |> json_response(:forbidden)
    end
  end

  describe "fetch_pending - POST /api/scores/fetch_pending" do
    @tag authentication: [role: "service"]
    test "status filter is always replaced by PENDING", %{conn: conn} do
      source_id = 8

      %{id: id} =
        score =
        insert(:score,
          quality_control_version:
            build(:quality_control_version,
              status: "published",
              quality_control: build(:quality_control, source_id: source_id)
            )
        )

      insert(:score_event, type: "PENDING", score: score)

      another_score = insert(:score)
      insert(:score_event, type: "QUEUED", score: another_score)

      params = %{status: "queued", sources: [source_id]}

      %{"data" => scores} =
        conn
        |> post(~p"/api/scores/fetch_pending", params)
        |> json_response(:ok)

      assert [%{"id" => ^id}] = scores
    end

    @tag authentication: [role: "service"]
    test "filter by both source and status", %{conn: conn} do
      # Create combinatory of values
      for source_id <- [8, 9],
          type <- ["PENDING", "QUEUED"] do
        score =
          insert(:score,
            quality_control_version:
              build(:quality_control_version,
                status: "published",
                quality_control: build(:quality_control, source_id: source_id)
              )
          )

        insert(:score_event, type: type, score: score)
      end

      params = %{sources: [8]}

      %{"data" => scores} =
        conn
        |> post(~p"/api/scores/fetch_pending", params)
        |> json_response(:ok)

      assert length(scores) == 1
    end

    @tag authentication: [role: "service"]
    test "score status is updated to queued after fetching", %{conn: conn} do
      source_id = 8

      %{id: id} =
        score =
        insert(:score,
          quality_control_version:
            build(:quality_control_version,
              status: "published",
              quality_control: build(:quality_control, source_id: source_id)
            )
        )

      insert(:score_event, type: "PENDING", score: score)

      assert %{status: "PENDING"} = Scores.get_score(id, preload: :status)

      %{"data" => _} =
        conn
        |> post(~p"/api/scores/fetch_pending", %{sources: [source_id]})
        |> json_response(:ok)

      assert %{status: "QUEUED"} = Scores.get_score(id, preload: :status)
    end

    @tag authentication: [role: "service"]
    test "score type and quality control status are updated on fetching", %{conn: conn} do
      source_id = 8

      %{id: id} =
        score =
        insert(:score,
          quality_control_version:
            build(:quality_control_version,
              control_mode: "deviation",
              status: "draft",
              quality_control: build(:quality_control, source_id: source_id)
            )
        )

      insert(:score_event, type: "PENDING", score: score)

      assert %{score_type: nil, quality_control_status: nil} = Scores.get_score(id)

      %{"data" => _} =
        conn
        |> post(~p"/api/scores/fetch_pending", %{sources: [source_id]})
        |> json_response(:ok)

      assert %{
               score_type: "ratio",
               quality_control_status: "draft"
             } = Scores.get_score(id)
    end

    @tag authentication: [role: "service"]
    test "scores embeds the quality_control query", %{conn: conn} do
      %{quality_control: %{source_id: source_id_1}} =
        qcv =
        insert(:quality_control_version,
          status: "published",
          quality_control: insert(:quality_control),
          control_properties:
            build(:control_properties,
              ratio:
                build(:cp_ratio,
                  resource: build(:resource, type: "data_structure", id: 888)
                )
            )
        )

      %{id: score_id_1} = score = insert(:score, quality_control_version: qcv)
      insert(:score_event, type: "PENDING", score: score)

      %{quality_control: %{source_id: source_id_2}} =
        qcv =
        insert(:quality_control_version,
          status: "published",
          quality_control: insert(:quality_control),
          control_properties:
            build(:control_properties,
              ratio:
                build(:cp_ratio,
                  resource: build(:resource, type: "data_structure", id: 999)
                )
            )
        )

      %{id: score_id_2} = score = insert(:score, quality_control_version: qcv)
      insert(:score_event, type: "PENDING", score: score)

      TdDdMock.get_latest_structure_version(
        &Mox.expect/4,
        888,
        {:ok, %{name: "ds888", metadata: %{}}}
      )

      TdDdMock.get_latest_structure_version(
        &Mox.expect/4,
        999,
        {:ok, %{name: "ds999", metadata: %{}}}
      )

      %{"data" => scores, "resources_lookup" => resources_lookup} =
        conn
        |> post(~p"/api/scores/fetch_pending", %{
          sources: [source_id_1, source_id_2]
        })
        |> json_response(:ok)

      [
        %{
          "id" => ^score_id_1,
          "queries" => [
            %{
              "__type__" => "query",
              "action" => "count",
              "resource" => %{"queryables" => [%{"__type__" => "from"}]}
            },
            %{
              "__type__" => "query",
              "action" => "count",
              "resource" => %{"queryables" => [%{"__type__" => "from"}, %{"__type__" => "where"}]}
            }
          ]
        },
        %{
          "id" => ^score_id_2,
          "queries" => [
            %{
              "__type__" => "query",
              "action" => "count",
              "resource" => %{"queryables" => [%{"__type__" => "from"}]}
            },
            %{
              "__type__" => "query",
              "action" => "count",
              "resource" => %{"queryables" => [%{"__type__" => "from"}, %{"__type__" => "where"}]}
            }
          ]
        }
      ] = scores

      assert %{
               "data_structure:888" => %{"id" => 888, "metadata" => %{}, "name" => "ds888"},
               "data_structure:999" => %{"id" => 999, "metadata" => %{}, "name" => "ds999"}
             } = resources_lookup
    end

    @tag authentication: [role: "service"]
    test "embeds the quality_control query for count", %{conn: conn} do
      %{quality_control: %{source_id: source_id}} =
        qcv =
        insert(:quality_control_version,
          status: "published",
          quality_control: insert(:quality_control),
          control_mode: "count",
          control_properties:
            build(:control_properties,
              count:
                build(:cp_count,
                  errors_resource: build(:resource, type: "data_structure", id: 888)
                )
            )
        )

      %{id: score_id} = score = insert(:score, quality_control_version: qcv)
      insert(:score_event, type: "PENDING", score: score)

      TdDdMock.get_latest_structure_version(
        &Mox.expect/4,
        888,
        {:ok, %{name: "ds888", metadata: %{}}}
      )

      %{"data" => scores, "resources_lookup" => resources_lookup} =
        conn
        |> post(~p"/api/scores/fetch_pending", %{
          sources: [source_id]
        })
        |> json_response(:ok)

      [
        %{
          "id" => ^score_id,
          "queries" => [
            %{
              "__type__" => "query",
              "action" => "count",
              "query_ref" => "count",
              "resource" => %{
                "__type__" => "data_view",
                "queryables" => [%{"__type__" => "from", "resource" => nil, "resource_ref" => 0}],
                "resource_refs" => %{
                  "0" => %{"alias" => nil, "id" => 888, "type" => "data_structure"}
                },
                "select" => nil
              }
            }
          ]
        }
      ] = scores

      assert %{"data_structure:888" => %{"id" => 888, "metadata" => %{}, "name" => "ds888"}} =
               resources_lookup
    end

    @tag authentication: [role: "user"]
    test "user without permission cannot fetch scores", %{conn: conn} do
      source_id = 8

      score =
        insert(:score,
          quality_control_version:
            build(:quality_control_version,
              status: "published",
              quality_control: build(:quality_control, source_id: source_id)
            )
        )

      insert(:score_event, type: "PENDING", score: score)

      assert conn
             |> post(~p"/api/scores/fetch_pending", %{sources: [source_id]})
             |> json_response(:forbidden)
    end
  end

  describe "success - POST /api/scores/:id/success" do
    @tag authentication: [role: "service"]
    test "updates score success", %{conn: conn} do
      %{id: id} = score = insert(:score, score_type: "ratio")
      insert(:score_event, type: "STARTED", score: score)

      params = %{
        "execution_timestamp" => "2024-11-18 15:34:21.438113Z",
        "result" => %{
          "total_count" => [[10]],
          "validation_count" => [[1]]
        },
        "details" => %{"foo" => "bar"}
      }

      assert %{
               "data" => %{
                 "score_content" => %{
                   "total_count" => 10,
                   "validation_count" => 1
                 },
                 "details" => %{"foo" => "bar"},
                 "execution_timestamp" => "2024-11-18T15:34:21.438113Z"
               }
             } =
               conn
               |> post(~p"/api/scores/#{id}/success", params)
               |> json_response(:ok)

      assert %{status: "SUCCEEDED"} = Scores.get_score(id, preload: :status)
    end

    @tag authentication: [role: "service"]
    test "invalid params", %{conn: conn} do
      %{id: id} = score = insert(:score, score_type: "ratio")
      insert(:score_event, type: "STARTED", score: score)

      params = %{
        "execution_timestamp" => nil,
        "result" => %{
          "invalid" => [[10]]
        }
      }

      assert %{
               "errors" => %{
                 "execution_timestamp" => ["can't be blank"],
                 "score_content" => ["can't be blank"]
               }
             } =
               conn
               |> post(~p"/api/scores/#{id}/success", params)
               |> json_response(:unprocessable_entity)

      assert %{status: "STARTED"} = Scores.get_score(id, preload: :status)
    end

    @tag authentication: [role: "user"]
    test "forbidden for user", %{conn: conn} do
      %{id: id} = score = insert(:score, score_type: "ratio")
      insert(:score_event, type: "STARTED", score: score)

      params = %{
        "execution_timestamp" => "2024-11-18 15:34:21.438113Z",
        "result" => %{
          "total_count" => [[10]],
          "validation_count" => [[1]]
        },
        "details" => %{"foo" => "bar"}
      }

      assert conn
             |> post(~p"/api/scores/#{id}/success", params)
             |> json_response(:forbidden)

      assert %{status: "STARTED"} = Scores.get_score(id, preload: :status)
    end
  end

  describe "fail - POST /api/scores/:id/fail" do
    @tag authentication: [role: "service"]
    test "updates score fail", %{conn: conn} do
      %{id: id} = score = insert(:score, score_type: "ratio")
      insert(:score_event, type: "STARTED", score: score)

      params = %{
        "execution_timestamp" => "2024-11-18 15:34:21.438113Z",
        "details" => %{"foo" => "bar"}
      }

      assert %{
               "data" => %{
                 "details" => %{"foo" => "bar"},
                 "execution_timestamp" => "2024-11-18T15:34:21.438113Z"
               }
             } =
               conn
               |> post(~p"/api/scores/#{id}/fail", params)
               |> json_response(:ok)

      assert %{status: "FAILED"} = Scores.get_score(id, preload: :status)
    end

    @tag authentication: [role: "service"]
    test "invalid params", %{conn: conn} do
      %{id: id} = score = insert(:score, score_type: "ratio")
      insert(:score_event, type: "STARTED", score: score)

      params = %{
        "execution_timestamp" => nil,
        "result" => %{
          "invalid" => [[10]]
        }
      }

      assert %{
               "errors" => %{
                 "execution_timestamp" => ["can't be blank"]
               }
             } =
               conn
               |> post(~p"/api/scores/#{id}/fail", params)
               |> json_response(:unprocessable_entity)

      assert %{status: "STARTED"} = Scores.get_score(id, preload: :status)
    end

    @tag authentication: [role: "user"]
    test "forbidden for user", %{conn: conn} do
      %{id: id} = score = insert(:score, score_type: "ratio")
      insert(:score_event, type: "STARTED", score: score)

      params = %{
        "execution_timestamp" => "2024-11-18 15:34:21.438113Z",
        "details" => %{"foo" => "bar"}
      }

      assert conn
             |> post(~p"/api/scores/#{id}/fail", params)
             |> json_response(:forbidden)

      assert %{status: "STARTED"} = Scores.get_score(id, preload: :status)
    end
  end

  describe "delete - DELETE /api/scores/:id" do
    @tag authentication: [role: "admin"]
    test "admin can delete score", %{conn: conn} do
      %{id: group_id} = group = insert(:score_group)
      score = insert(:score, group_id: group_id, group: group)

      insert(:score_event, type: "PENDING", score: score)

      assert conn
             |> delete(~p"/api/scores/#{score.id}")
             |> response(:no_content)
    end

    @tag authentication: [
           role: "user",
           permissions: [
             "manage_quality_controls"
           ]
         ]
    test "user with permission can delete score", %{conn: conn, domain: %{id: domain_id}} do
      qcv =
        insert(:quality_control_version,
          quality_control: build(:quality_control, domain_ids: [domain_id])
        )

      %{id: group_id} = group = insert(:score_group)
      score = insert(:score, group_id: group_id, group: group, quality_control_version: qcv)

      insert(:score_event, type: "PENDING", score: score)

      assert conn
             |> delete(~p"/api/scores/#{score.id}")
             |> response(:no_content)
    end

    @tag authentication: [role: "user"]
    test "forbidden for user without permission", %{conn: conn} do
      %{id: group_id} = group = insert(:score_group)
      score = insert(:score, group_id: group_id, group: group)

      insert(:score_event, type: "PENDING", score: score)

      assert %{"errors" => %{"detail" => "Forbidden"}} =
               conn
               |> delete(~p"/api/scores/#{score.id}")
               |> json_response(:forbidden)
    end

    for status <- ["PENDING", "SUCCEEDED", "FAILED"] do
      @tag [
        authentication: [role: "admin"],
        status: status
      ]
      test "is valid delete score with status #{status}", %{conn: conn, status: status} do
        %{id: group_id} = group = insert(:score_group)
        score = insert(:score, group_id: group_id, group: group)
        insert(:score_event, type: status, score: score)

        assert conn
               |> delete(~p"/api/scores/#{score.id}")
               |> response(:no_content)
      end
    end

    for status <- ["QUEUED", "TIMEOUT", "STARTED"] do
      @tag [
        authentication: [role: "admin"],
        status: status
      ]
      test "is invalid to delete score with status #{status}", %{conn: conn, status: status} do
        score = insert(:score)

        insert(:score_event, type: status, score: score)

        assert conn
               |> delete(~p"/api/scores/#{score.id}")
               |> json_response(:unprocessable_entity)
      end
    end
  end
end
