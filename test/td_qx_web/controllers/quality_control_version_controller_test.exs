defmodule TdQxWeb.QualityControlVersionControllerTest do
  use TdQxWeb.ConnCase

  alias TdCluster.TestHelpers.TdDdMock
  alias TdCluster.TestHelpers.TdDfMock

  import TdQx.TestOperators

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index versions" do
    @tag authentication: [role: "admin"]
    test "lists all versions of a quality_controls", %{conn: conn} do
      %{id: qc_id} = quality_control = insert(:quality_control)

      insert(:quality_control_version,
        status: "published",
        version: 1,
        quality_control: quality_control
      )

      insert(:quality_control_version,
        status: "draft",
        version: 2,
        quality_control: quality_control
      )

      conn = get(conn, ~p"/api/quality_controls/#{qc_id}/versions")

      assert [
               %{"version" => 1, "status" => "published", "id" => qc_id},
               %{"version" => 2, "status" => "draft", "id" => qc_id}
             ] ||| json_response(conn, 200)["data"]
    end
  end

  describe "show" do
    @tag authentication: [role: "admin"]
    test "will return actions for published version", %{conn: conn} do
      %{quality_control_id: id, version: version} =
        insert(:quality_control_version,
          status: "published",
          quality_control: insert(:quality_control)
        )

      conn = get(conn, ~p"/api/quality_controls/#{id}/versions/#{version}")

      assert %{"_actions" => actions} = json_response(conn, 200)

      assert [
               "deprecate",
               "create_draft",
               "toggle_active",
               "delete_score",
               "update_main",
               "execute"
             ] == actions
    end

    @tag authentication: [role: "admin"]
    test "will return enriched resources on ratio control_properties", %{conn: conn} do
      %{quality_control_id: id, version: version} =
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

      TdDdMock.get_latest_structure_version(
        &Mox.expect/4,
        888,
        {:ok,
         %{
           name: "ds888",
           data_fields: [
             %{data_structure_id: 8881, name: "field", metadata: %{}}
           ]
         }}
      )

      conn = get(conn, ~p"/api/quality_controls/#{id}/versions/#{version}")

      assert %{
               "data" => %{
                 "control_properties" => %{
                   "resource" => %{
                     "embedded" => %{
                       "name" => "ds888",
                       "fields" => [
                         %{
                           "id" => 8881,
                           "name" => "field",
                           "parent_name" => "ds888",
                           "type" => "string"
                         }
                       ]
                     }
                   }
                 }
               }
             } = json_response(conn, 200)
    end

    @tag authentication: [role: "admin"]
    test "will return enriched resources on error_count control_properties", %{conn: conn} do
      %{quality_control_id: id, version: version} =
        insert(:quality_control_version,
          status: "published",
          quality_control: insert(:quality_control),
          control_mode: "error_count",
          control_properties:
            build(:control_properties,
              error_count:
                build(:cp_error_count,
                  errors_resource: build(:resource, type: "data_structure", id: 888)
                )
            )
        )

      TdDdMock.get_latest_structure_version(
        &Mox.expect/4,
        888,
        {:ok,
         %{
           name: "ds888",
           data_fields: [
             %{data_structure_id: 8881, name: "field", metadata: %{}}
           ]
         }}
      )

      conn = get(conn, ~p"/api/quality_controls/#{id}/versions/#{version}")

      assert %{
               "data" => %{
                 "control_properties" => %{
                   "errors_resource" => %{
                     "embedded" => %{
                       "name" => "ds888",
                       "fields" => [
                         %{
                           "id" => 8881,
                           "name" => "field",
                           "parent_name" => "ds888",
                           "type" => "string"
                         }
                       ]
                     }
                   }
                 }
               }
             } = json_response(conn, 200)
    end

    @tag authentication: [role: "admin"]
    test "will return actions for deprecated version", %{conn: conn} do
      %{quality_control_id: id, version: version} =
        insert(:quality_control_version,
          status: "deprecated",
          quality_control: insert(:quality_control)
        )

      conn = get(conn, ~p"/api/quality_controls/#{id}/versions/#{version}")

      assert %{"_actions" => ["restore", "delete_score", "update_main"]} =
               json_response(conn, 200)
    end

    @tag authentication: [role: "admin"]
    test "will return actions for draft with incomplete version", %{conn: conn} do
      %{quality_control_id: id, df_type: template_name, version: version} =
        insert(:quality_control_version,
          status: "draft",
          control_mode: "percentage",
          control_properties:
            build(:control_properties,
              ratio: build(:cp_ratio, validation: [])
            ),
          quality_control: insert(:quality_control)
        )

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok, %{content: []}},
        2
      )

      conn = get(conn, ~p"/api/quality_controls/#{id}/versions/#{version}")

      assert %{
               "_actions" => [
                 "edit",
                 "toggle_active",
                 "delete_score",
                 "update_main",
                 "execute",
                 "delete"
               ]
             } =
               json_response(conn, 200)
    end

    @tag authentication: [role: "admin"]
    test "will return actions for draft with valid version", %{conn: conn} do
      %{quality_control_id: id, df_type: template_name, version: version} =
        insert(:quality_control_version,
          status: "draft",
          quality_control: insert(:quality_control)
        )

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok, %{content: []}},
        2
      )

      conn = get(conn, ~p"/api/quality_controls/#{id}/versions/#{version}")

      assert %{"_actions" => actions} = json_response(conn, 200)

      assert [
               "send_to_approval",
               "publish",
               "edit",
               "toggle_active",
               "delete_score",
               "update_main",
               "execute",
               "delete"
             ] == actions
    end

    @tag authentication: [role: "admin"]
    test "retuns not found if quality control version doesn't exist", %{conn: conn} do
      assert %{"errors" => %{"detail" => "Not Found"}} ==
               conn
               |> get(~p"/api/quality_controls/#{0}/versions/#{0}")
               |> json_response(404)
    end

    @tag authentication: [
           role: "user",
           permissions: [
             "view_quality_controls",
             "write_quality_controls",
             "execute_quality_controls"
           ]
         ]

    test "for non admin user with permissions we return all actions but execute only for latest version",
         %{
           conn: conn,
           domain: %{id: domain_id}
         } do
      quality_control = insert(:quality_control, domain_ids: [domain_id])

      versioned =
        insert(:quality_control_version,
          quality_control: quality_control,
          status: "versioned",
          version: 1
        )

      published =
        insert(:quality_control_version,
          quality_control: quality_control,
          status: "published",
          version: 2
        )

      draft =
        insert(:quality_control_version,
          quality_control: quality_control,
          status: "draft",
          version: 3
        )

      conn =
        get(
          conn,
          ~p"/api/quality_controls/#{quality_control.id}/versions/#{versioned.version}"
        )

      assert %{"_actions" => []} = json_response(conn, 200)

      conn =
        get(
          conn,
          ~p"/api/quality_controls/#{quality_control.id}/versions/#{published.version}"
        )

      assert %{"_actions" => ["execute"]} = json_response(conn, 200)

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        draft.df_type,
        {:ok, %{content: []}},
        2
      )

      conn =
        get(
          conn,
          ~p"/api/quality_controls/#{quality_control.id}/versions/#{draft.version}"
        )

      assert %{"_actions" => actions} = json_response(conn, 200)

      assert actions == ["send_to_approval", "edit", "execute"]
    end

    @tag authentication: [
           role: "user",
           permissions: [
             "view_quality_controls",
             "write_quality_controls",
             "execute_quality_controls"
           ]
         ]
    test "for non admin with permission returns correct actions for draft with valid version", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{quality_control_id: id, df_type: template_name, version: version} =
        insert(:quality_control_version,
          status: "draft",
          quality_control: build(:quality_control, domain_ids: [domain_id])
        )

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok, %{content: []}},
        2
      )

      conn = get(conn, ~p"/api/quality_controls/#{id}/versions/#{version}")
      assert %{"_actions" => ["send_to_approval", "edit", "execute"]} = json_response(conn, 200)
    end

    @tag authentication: [
           role: "user",
           permissions: [
             "view_quality_controls",
             "write_quality_controls",
             "manage_quality_controls"
           ]
         ]
    test "for non admin with permission returns correct actions including toogle_ active", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{quality_control_id: id, df_type: template_name, version: version} =
        insert(:quality_control_version,
          status: "draft",
          quality_control: build(:quality_control, domain_ids: [domain_id])
        )

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok, %{content: []}},
        2
      )

      conn = get(conn, ~p"/api/quality_controls/#{id}/versions/#{version}")

      assert %{"_actions" => actions} = json_response(conn, 200)

      assert [
               "send_to_approval",
               "publish",
               "edit",
               "toggle_active",
               "delete_score"
             ] == actions
    end

    @tag authentication: [
           role: "user",
           permissions: ["view_quality_controls", "write_quality_controls"]
         ]
    test "non admin with permission in different domain does not have access", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{quality_control_id: id, version: version} =
        insert(:quality_control_version,
          status: "draft",
          quality_control: build(:quality_control, domain_ids: [domain_id + 1])
        )

      conn = get(conn, ~p"/api/quality_controls/#{id}/versions/#{version}")
      assert json_response(conn, 403)
    end
  end

  describe "delete" do
    @tag authentication: [role: "admin"]
    test "deletes quality control version on draft status", %{conn: conn} do
      %{quality_control_id: id, version: version} =
        insert(:quality_control_version,
          status: "draft",
          quality_control: insert(:quality_control)
        )

      assert conn
             |> delete(~p"/api/quality_controls/#{id}/versions/#{version}")
             |> response(:no_content)
    end

    @tag authentication: [role: "admin"]
    test "forbidden when quality control version is not draft", %{conn: conn} do
      %{quality_control_id: id, version: version} =
        insert(:quality_control_version,
          status: "published",
          quality_control: insert(:quality_control)
        )

      assert conn
             |> delete(~p"/api/quality_controls/#{id}/versions/#{version}")
             |> response(:forbidden)
    end

    @tag authentication: [role: "admin"]
    test "not found when version does not exist", %{conn: conn} do
      assert %{"errors" => %{"detail" => "Not Found"}} ==
               conn
               |> delete(~p"/api/quality_controls/#{0}/versions/#{0}")
               |> json_response(404)
    end

    @tag authentication: [
           role: "user",
           permissions: [
             "manage_quality_controls"
           ]
         ]
    test "deletes quality control version when user has permissions", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{quality_control_id: id, version: version} =
        insert(:quality_control_version,
          status: "draft",
          quality_control: insert(:quality_control, domain_ids: [domain_id])
        )

      assert conn
             |> delete(~p"/api/quality_controls/#{id}/versions/#{version}")
             |> response(:no_content)
    end

    @tag authentication: [
           role: "user",
           permissions: [
             "view_quality_controls"
           ]
         ]
    test "returns forbidden when user has no permissions", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{quality_control_id: id, version: version} =
        insert(:quality_control_version,
          status: "draft",
          quality_control: insert(:quality_control, domain_ids: [domain_id])
        )

      assert conn
             |> delete(~p"/api/quality_controls/#{id}/versions/#{version}")
             |> response(:forbidden)
    end
  end
end
