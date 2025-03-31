defmodule TdQxWeb.SearchControllerTest do
  use TdQxWeb.ConnCase

  alias TdCluster.TestHelpers.TdDfMock
  alias TdCore.Search.IndexWorkerMock

  setup do
    quality_control = insert(:quality_control)
    qcv = insert(:quality_control_version, quality_control: quality_control)

    user = CacheHelpers.insert_user()
    score_group = insert(:score_group, created_by: user.id)

    [response: qcv, score_group: score_group]
  end

  setup {Mox, :verify_on_exit!}

  describe "POST /api/quality_controls/search" do
    @tag authentication: [role: "admin"]
    test "admin can search quality_controls", %{conn: conn, response: response} do
      TdDfMock.list_templates_by_scope(
        &Mox.expect/4,
        "quality_control",
        {:ok, []}
      )

      ElasticsearchMock
      |> Mox.expect(:request, fn _, :post, "/quality_control_versions/_search", _, _ ->
        SearchHelpers.hits_response([response])
      end)

      assert %{"data" => [_]} =
               conn
               |> post(~p"/api/quality_controls/search")
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "admin can search quality_controls with must params", %{conn: conn, response: response} do
      TdDfMock.list_templates_by_scope(
        &Mox.expect/4,
        "quality_control",
        {:ok, []}
      )

      Mox.expect(ElasticsearchMock, :request, fn _,
                                                 :post,
                                                 "/quality_control_versions/_search",
                                                 %{query: query},
                                                 _ ->
        assert %{bool: %{must: %{match_all: %{}}}} == query

        SearchHelpers.hits_response([response])
      end)

      assert %{"data" => [_]} =
               conn
               |> post(~p"/api/quality_controls/search", %{"must" => %{}})
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "search quality_controls with scroll", %{conn: conn, response: response} do
      TdDfMock.list_templates_by_scope(
        &Mox.expect/4,
        "quality_control",
        {:ok, []}
      )

      ElasticsearchMock
      |> Mox.expect(:request, fn _,
                                 :post,
                                 "/quality_control_versions/_search",
                                 _,
                                 [params: %{"scroll" => "1m"}] ->
        SearchHelpers.scroll_response([response], 1)
      end)
      |> Mox.expect(:request, fn _,
                                 :post,
                                 "/_search/scroll",
                                 %{"scroll_id" => "some_scroll_id"},
                                 _ ->
        SearchHelpers.scroll_response([], 1)
      end)

      assert %{"data" => [_], "scroll_id" => scroll_id} =
               conn
               |> post(
                 ~p"/api/quality_controls/search",
                 %{"size" => 1, "scroll" => "1m"}
               )
               |> json_response(:ok)

      assert %{"data" => [], "scroll_id" => _scroll_id} =
               conn
               |> post(
                 ~p"/api/quality_controls/search",
                 %{"size" => 1, "scroll" => "1m", "scroll_id" => scroll_id}
               )
               |> json_response(:ok)
    end

    @tag authentication: [role: "user"]
    test "user with no permissions cannot search quality_controls", %{conn: conn} do
      assert %{"errors" => %{} = errors} =
               conn
               |> post(~p"/api/quality_controls/search")
               |> json_response(:forbidden)

      refute errors == %{"errors" => %{"detail" => "Forbidden"}}
    end

    @tag authentication: [role: "user"]
    test "user with no permissions cannot search quality_controls with must", %{conn: conn} do
      assert %{"errors" => %{} = errors} =
               conn
               |> post(~p"/api/quality_controls/search", %{"must" => %{}})
               |> json_response(:forbidden)

      refute errors == %{}
    end

    @tag authentication: [
           role: "user",
           permissions: ["view_quality_controls"]
         ]
    test "user with permissions can search quality_controls", %{
      conn: conn,
      response: response,
      domain: %{id: domain_id}
    } do
      TdDfMock.list_templates_by_scope(
        &Mox.expect/4,
        "quality_control",
        {:ok, []}
      )

      Mox.expect(ElasticsearchMock, :request, fn _,
                                                 :post,
                                                 "/quality_control_versions/_search",
                                                 %{query: query},
                                                 _ ->
        assert query == %{bool: %{must: %{term: %{"domain_ids" => domain_id}}}}
        SearchHelpers.hits_response([response])
      end)

      assert %{"data" => [_]} =
               conn
               |> post(~p"/api/quality_controls/search")
               |> json_response(:ok)
    end

    @tag authentication: [
           role: "user",
           permissions: ["view_quality_controls"]
         ]
    test "user with no permissions can not execute quality_controls", %{
      conn: conn,
      response: response,
      domain: %{id: domain_id}
    } do
      TdDfMock.list_templates_by_scope(
        &Mox.expect/4,
        "quality_control",
        {:ok, []}
      )

      ElasticsearchMock
      |> Mox.expect(:request, fn _,
                                 :post,
                                 "/quality_control_versions/_search",
                                 %{query: query},
                                 _ ->
        assert query == %{bool: %{must: %{term: %{"domain_ids" => domain_id}}}}
        SearchHelpers.hits_response([response])
      end)

      assert %{"data" => [_], "actions" => actions} =
               conn
               |> post(~p"/api/quality_controls/search")
               |> json_response(:ok)

      refute Map.get(actions, "execute")
    end

    @tag authentication: [
           role: "user",
           permissions: ["view_quality_controls", "execute_quality_controls"]
         ]
    test "user with permissions can execute quality_controls", %{
      conn: conn,
      response: response,
      domain: %{id: domain_id}
    } do
      TdDfMock.list_templates_by_scope(
        &Mox.expect/4,
        "quality_control",
        {:ok, []}
      )

      ElasticsearchMock
      |> Mox.expect(:request, fn _,
                                 :post,
                                 "/quality_control_versions/_search",
                                 %{query: query},
                                 _ ->
        assert query == %{bool: %{must: %{term: %{"domain_ids" => domain_id}}}}
        SearchHelpers.hits_response([response])
      end)

      assert %{"data" => [_], "actions" => actions} =
               conn
               |> post(~p"/api/quality_controls/search")
               |> json_response(:ok)

      assert Map.get(actions, "execute") == %{"method" => "POST"}
    end
  end

  describe "POST /api/quality_controls/filters" do
    @tag authentication: [role: "admin"]
    test "maps filters from request parameters", %{conn: conn} do
      response = %{"name.raw" => %{"buckets" => [%{"key" => "foo"}, %{"key" => "bar"}]}}

      TdDfMock.list_templates_by_scope(
        &Mox.expect/4,
        "quality_control",
        {:ok, []}
      )

      Mox.expect(ElasticsearchMock, :request, fn
        _, :post, "/quality_control_versions/_search", %{query: query, size: 0}, _ ->
          assert query == %{bool: %{must: %{term: %{"name.raw" => "foo"}}}}

          SearchHelpers.aggs_response(response)
      end)

      filters = %{"name.raw" => ["foo"]}

      assert %{"data" => data} =
               conn
               |> post(~p"/api/quality_controls/filters", %{"must" => filters})
               |> json_response(:ok)

      assert %{"name.raw" => %{"values" => ["foo", "bar"]}} = data
    end

    @tag authentication: [role: "user", permissions: ["view_quality_controls"]]
    test "user with permissions filters by domain_id", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      TdDfMock.list_templates_by_scope(
        &Mox.expect/4,
        "quality_control",
        {:ok, []}
      )

      Mox.expect(ElasticsearchMock, :request, fn
        _, :post, "/quality_control_versions/_search", %{query: query, size: 0}, _ ->
          assert %{bool: %{must: %{term: %{"domain_ids" => ^domain_id}}}} = query

          SearchHelpers.aggs_response()
      end)

      assert %{"data" => _} =
               conn
               |> post(~p"/api/quality_controls/filters", %{})
               |> json_response(:ok)
    end

    @tag authentication: [role: "user"]
    test "user with permissions filters by domain_ids", %{
      conn: conn,
      claims: claims
    } do
      %{id: id1} = CacheHelpers.insert_domain()
      %{id: id2} = CacheHelpers.insert_domain()

      CacheHelpers.put_session_permissions(claims, %{
        "view_quality_controls" => [id1, id2]
      })

      TdDfMock.list_templates_by_scope(
        &Mox.expect/4,
        "quality_control",
        {:ok, []}
      )

      Mox.expect(ElasticsearchMock, :request, fn
        _, :post, "/quality_control_versions/_search", %{query: query, size: 0}, _ ->
          assert %{bool: %{must: %{terms: %{"domain_ids" => domain_ids}}}} = query
          assert Enum.sort(domain_ids) == Enum.sort([id1, id2])

          SearchHelpers.aggs_response()
      end)

      assert %{"data" => _} =
               conn
               |> post(~p"/api/quality_controls/filters", %{})
               |> json_response(:ok)
    end

    @tag authentication: [role: "user"]
    test "filter domain_ids by execute permission", %{
      conn: conn,
      claims: claims
    } do
      %{id: id1} = CacheHelpers.insert_domain()
      %{id: id2} = CacheHelpers.insert_domain()
      %{id: id3} = CacheHelpers.insert_domain()

      CacheHelpers.put_session_permissions(claims, %{
        "view_quality_controls" => [id1, id2],
        "execute_quality_controls" => [id2, id3]
      })

      TdDfMock.list_templates_by_scope(
        &Mox.expect/4,
        "quality_control",
        {:ok, []}
      )

      ElasticsearchMock
      |> Mox.expect(:request, fn
        _, :post, "/quality_control_versions/_search", %{query: query, size: 0}, _ ->
          assert %{
                   bool: %{
                     must: [
                       %{term: %{"active" => true}},
                       %{term: %{"domain_ids" => ^id2}}
                     ]
                   }
                 } = query

          SearchHelpers.aggs_response()
      end)

      assert %{"data" => _} =
               conn
               |> post(~p"/api/quality_controls/filters", %{
                 "must" => %{"for_execution" => [true]}
               })
               |> json_response(:ok)
    end

    @tag authentication: [role: "user"]
    test "user without permissions is forbidden", %{conn: conn} do
      assert conn
             |> post(~p"/api/quality_controls/filters", %{})
             |> json_response(:forbidden)
    end
  end

  describe "GET /api/quality_controls/reindex" do
    setup do
      quality_controls =
        Enum.map(1..3, fn _ ->
          insert(:quality_control_version,
            status: "published",
            quality_control: insert(:quality_control)
          )
        end)

      %{quality_controls: quality_controls}
    end

    for role <- ["admin", "service"] do
      @tag authentication: [role: role]
      test "#{role} role can reindex quality_control_versions", %{conn: conn} do
        IndexWorkerMock.clear()

        assert conn
               |> get(~p"/api/quality_controls/reindex")
               |> response(:accepted)

        assert IndexWorkerMock.calls() == [{:reindex, :quality_control_versions, :all}]
      end
    end

    @tag authentication: [role: "non_admin"]
    test "user without admin privileges cannot reindex quality_control_versions", %{conn: conn} do
      IndexWorkerMock.clear()

      assert conn
             |> get(~p"/api/quality_controls/reindex")
             |> response(:forbidden)

      assert IndexWorkerMock.calls() == []
    end
  end

  describe "POST /api/score_groups/search" do
    @tag authentication: [role: "admin"]
    test "admin can search score groups", %{
      conn: conn,
      score_group: %{id: score_id} = score_group
    } do
      TdDfMock.list_templates_by_scope(
        &Mox.expect/4,
        "qxe",
        {:ok, []}
      )

      ElasticsearchMock
      |> Mox.expect(:request, fn _, :post, "/score_groups/_search", _, _ ->
        SearchHelpers.hits_response([score_group])
      end)

      assert %{"data" => [%{"id" => ^score_id}]} =
               conn
               |> post(~p"/api/score_groups/search")
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "admin can search score_groups with must params", %{
      conn: conn,
      score_group: score_group
    } do
      TdDfMock.list_templates_by_scope(
        &Mox.expect/4,
        "qxe",
        {:ok, []}
      )

      ElasticsearchMock
      |> Mox.expect(:request, fn _, :post, "/score_groups/_search", %{query: query}, _ ->
        assert %{bool: %{must: %{match_all: %{}}}} == query

        SearchHelpers.hits_response([score_group])
      end)

      assert %{"data" => [_]} =
               conn
               |> post(~p"/api/score_groups/search", %{"must" => %{}})
               |> json_response(:ok)
    end

    @tag authentication: [role: "user"]
    test "user with no permissions cannot search score_groups", %{conn: conn} do
      assert %{"errors" => %{} = errors} =
               conn
               |> post(~p"/api/score_groups/search")
               |> json_response(:forbidden)

      refute errors == %{"errors" => %{"detail" => "Forbidden"}}
    end

    @tag authentication: [role: "user"]
    test "user with no permissions cannot search score_groups with must", %{conn: conn} do
      assert %{"errors" => %{} = errors} =
               conn
               |> post(~p"/api/score_groups/search", %{"must" => %{}})
               |> json_response(:forbidden)

      refute errors == %{"errors" => %{"detail" => "Forbidden"}}
    end

    @tag authentication: [
           role: "user",
           permissions: ["view_quality_controls", "execute_quality_controls"]
         ]
    test "user with permissions can search score groups", %{
      conn: conn,
      score_group: score_group
    } do
      TdDfMock.list_templates_by_scope(
        &Mox.expect/4,
        "qxe",
        {:ok, []}
      )

      ElasticsearchMock
      |> Mox.expect(:request, fn _, :post, "/score_groups/_search", %{query: query}, _ ->
        assert query == %{bool: %{must: %{match_all: %{}}}}
        SearchHelpers.hits_response([score_group])
      end)

      assert %{"data" => [_]} =
               conn
               |> post(~p"/api/score_groups/search")
               |> json_response(:ok)
    end
  end

  describe "POST /api/score_groups/filters" do
    @tag authentication: [role: "admin"]
    test "maps filters from request parameters", %{conn: conn} do
      response = %{"created_by" => %{"buckets" => [%{"key" => "foo"}, %{"key" => "bar"}]}}

      TdDfMock.list_templates_by_scope(
        &Mox.expect/4,
        "qxe",
        {:ok, []}
      )

      ElasticsearchMock
      |> Mox.expect(:request, fn
        _, :post, "/score_groups/_search", %{query: query, size: 0}, _ ->
          assert query == %{bool: %{must: %{term: %{"created_by.user_name" => "foo"}}}}

          SearchHelpers.aggs_response(response)
      end)

      filters = %{"created_by" => ["foo"]}

      assert %{"data" => data} =
               conn
               |> post(~p"/api/score_groups/filters", %{"must" => filters})
               |> json_response(:ok)

      assert %{"created_by" => %{"values" => ["foo", "bar"]}} = data
    end

    @tag authentication: [role: "user"]
    test "user without permissions is forbidden", %{conn: conn} do
      assert conn
             |> post(~p"/api/score_groups/filters", %{})
             |> json_response(:forbidden)
    end
  end

  describe "GET /api/score_groups/reindex" do
    setup do
      score_groups =
        Enum.map(1..3, fn _ ->
          insert(:score_group)
        end)

      %{score_groups: score_groups}
    end

    for role <- ["admin", "service"] do
      @tag authentication: [role: role]
      test "#{role} role  can reindex score_groups", %{conn: conn} do
        IndexWorkerMock.clear()

        assert conn
               |> get(~p"/api/score_groups/reindex")
               |> response(:accepted)

        assert IndexWorkerMock.calls() == [{:reindex, :score_groups, :all}]
      end
    end

    @tag authentication: [role: "non_admin"]
    test "user without admin privilege cannot reindex score_group", %{conn: conn} do
      IndexWorkerMock.clear()

      assert conn
             |> get(~p"/api/score_groups/reindex")
             |> response(:forbidden)

      assert IndexWorkerMock.calls() == []
    end
  end
end
