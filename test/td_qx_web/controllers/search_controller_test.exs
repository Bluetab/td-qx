defmodule TdQxWeb.SearchControllerTest do
  use TdQxWeb.ConnCase

  alias TdCluster.TestHelpers.TdDfMock

  setup do
    quality_control = insert(:quality_control)
    qcv = insert(:quality_control_version, quality_control: quality_control)

    response =
      quality_control
      |> Map.put(:latest_version, qcv)
      |> Map.put(:template, %{})

    [response: response]
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
      |> Mox.expect(:request, fn _, :post, "/quality_controls/_search", _, _ ->
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

      ElasticsearchMock
      |> Mox.expect(:request, fn _, :post, "/quality_controls/_search", %{query: query}, _ ->
        assert %{bool: %{must: %{match_all: %{}}}} == query

        SearchHelpers.hits_response([response])
      end)

      assert %{"data" => [_]} =
               conn
               |> post(~p"/api/quality_controls/search", %{"must" => %{}})
               |> json_response(:ok)
    end

    @tag authentication: [role: "user"]
    test "user with no permissions cannot search quality_controls", %{conn: conn} do
      assert %{"errors" => %{} = errors} =
               conn
               |> post(~p"/api/quality_controls/search")
               |> json_response(:forbidden)

      refute errors == %{}
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

      ElasticsearchMock
      |> Mox.expect(:request, fn _, :post, "/quality_controls/_search", %{query: query}, _ ->
        assert query == %{bool: %{must: %{term: %{"domain_ids" => domain_id}}}}
        SearchHelpers.hits_response([response])
      end)

      assert %{"data" => [_]} =
               conn
               |> post(~p"/api/quality_controls/search")
               |> json_response(:ok)
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

      ElasticsearchMock
      |> Mox.expect(:request, fn
        _, :post, "/quality_controls/_search", %{query: query, size: 0}, _ ->
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

      ElasticsearchMock
      |> Mox.expect(:request, fn
        _, :post, "/quality_controls/_search", %{query: query, size: 0}, _ ->
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

      ElasticsearchMock
      |> Mox.expect(:request, fn
        _, :post, "/quality_controls/_search", %{query: query, size: 0}, _ ->
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
        _, :post, "/quality_controls/_search", %{query: query, size: 0}, _ ->
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
end
