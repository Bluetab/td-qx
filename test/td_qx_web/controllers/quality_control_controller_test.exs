defmodule TdQxWeb.QualityControlControllerTest do
  use TdQxWeb.ConnCase

  alias TdCluster.TestHelpers.TdDdMock
  alias TdCluster.TestHelpers.TdDfMock
  alias TdQx.QualityControls.QualityControlVersion

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
      %{quality_control_id: id} =
        insert(:quality_control_version,
          status: "published",
          quality_control: insert(:quality_control)
        )

      conn = get(conn, ~p"/api/quality_controls/#{id}")

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
      %{quality_control_id: id} =
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

      conn = get(conn, ~p"/api/quality_controls/#{id}")

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
      %{quality_control_id: id} =
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

      conn = get(conn, ~p"/api/quality_controls/#{id}")

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
      %{quality_control_id: id} =
        insert(:quality_control_version,
          status: "deprecated",
          quality_control: insert(:quality_control)
        )

      conn = get(conn, ~p"/api/quality_controls/#{id}")

      assert %{"_actions" => ["restore", "delete_score", "update_main"]} =
               json_response(conn, 200)
    end

    @tag authentication: [role: "admin"]
    test "will return actions for draft with incomplete version", %{conn: conn} do
      %{quality_control_id: id, df_type: template_name} =
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

      conn = get(conn, ~p"/api/quality_controls/#{id}")

      assert %{"_actions" => ["edit", "toggle_active", "delete_score", "update_main", "execute"]} =
               json_response(conn, 200)
    end

    @tag authentication: [role: "admin"]
    test "will return actions for draft with valid version", %{conn: conn} do
      %{quality_control_id: id, df_type: template_name} =
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

      conn = get(conn, ~p"/api/quality_controls/#{id}")

      assert %{"_actions" => actions} = json_response(conn, 200)

      assert [
               "send_to_approval",
               "publish",
               "edit",
               "toggle_active",
               "delete_score",
               "update_main",
               "execute"
             ] == actions
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
      %{quality_control_id: id, df_type: template_name} =
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

      conn = get(conn, ~p"/api/quality_controls/#{id}")
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
      %{quality_control_id: id, df_type: template_name} =
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

      conn = get(conn, ~p"/api/quality_controls/#{id}")

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
      %{quality_control_id: id} =
        insert(:quality_control_version,
          status: "draft",
          quality_control: build(:quality_control, domain_ids: [domain_id + 1])
        )

      conn = get(conn, ~p"/api/quality_controls/#{id}")
      assert json_response(conn, 403)
    end
  end

  describe "create quality_control" do
    @tag authentication: [role: "admin"]
    test "renders quality_control when data is valid", %{conn: conn} do
      params = %{
        "domain_ids" => [1, 2],
        "name" => "some name",
        "control_mode" => "percentage",
        "source_id" => 10,
        "active" => false
      }

      conn = post(conn, ~p"/api/quality_controls", quality_control: params)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/quality_controls/#{id}")

      assert %{
               "id" => ^id,
               "domain_ids" => [1, 2],
               "name" => "some name",
               "version" => 1,
               "status" => "draft",
               "control_mode" => "percentage",
               "dynamic_content" => nil,
               "df_type" => nil,
               "score_criteria" => nil,
               "control_properties" => nil,
               "active" => false
             } = json_response(conn, 200)["data"]
    end

    @tag authentication: [role: "admin"]
    test "renders quality_control when with published status", %{conn: conn} do
      template_name = "df_type"

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok, %{content: [%{"name" => "group", "fields" => [%{"name" => "foo"}]}]}}
      )

      params = %{
        "domain_ids" => [1, 2],
        "source_id" => 10,
        "name" => "some name",
        "status" => "published",
        "dynamic_content" => %{"foo" => %{"value" => "bar", "origin" => "user"}},
        "df_type" => template_name,
        "score_criteria" => string_params_for(:sc_percentage),
        "control_mode" => "percentage",
        "control_properties" => string_params_for(:cp_ratio_params_for)
      }

      conn = post(conn, ~p"/api/quality_controls", quality_control: params)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/quality_controls/#{id}")

      assert %{
               "id" => ^id,
               "version" => 1,
               "status" => "published",
               "dynamic_content" => %{"foo" => %{"value" => "bar", "origin" => "user"}},
               "df_type" => "df_type",
               "domain_ids" => [1, 2],
               "name" => "some name",
               "score_criteria" => %{"goal" => 90.0, "minimum" => 75.0},
               "control_mode" => "percentage",
               "control_properties" => %{
                 "resource" => %{"id" => _, "type" => "data_view"},
                 "validation" => [
                   %{
                     "expressions" => [
                       %{
                         "shape" => "constant",
                         "value" => %{"type" => "string", "value" => _}
                       }
                     ]
                   }
                 ]
               }
             } = json_response(conn, 200)["data"]
    end

    @tag authentication: [role: "admin"]
    test "renders errors when published version is invalid", %{conn: conn} do
      params = %{
        "domain_ids" => [1, 2],
        "source_id" => 10,
        "control_mode" => "percentage",
        "name" => "some name",
        "status" => "published"
      }

      conn = post(conn, ~p"/api/quality_controls", quality_control: params)

      assert %{
               "dynamic_content" => ["can't be blank"],
               "df_type" => ["can't be blank"],
               "score_criteria" => ["can't be blank"],
               "control_properties" => ["can't be blank"]
             } = json_response(conn, 422)["errors"]
    end

    @tag authentication: [role: "admin"]
    test "renders errors when status is invalid", %{conn: conn} do
      params = %{
        "domain_ids" => [1, 2],
        "name" => "some name",
        "source_id" => 10,
        "status" => "pending_approval"
      }

      conn = post(conn, ~p"/api/quality_controls", quality_control: params)

      assert %{"status" => ["is invalid"]} = json_response(conn, 422)["errors"]
    end

    @tag authentication: [role: "admin"]
    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/quality_controls", quality_control: %{})

      assert %{"domain_ids" => ["can't be blank"]} = json_response(conn, 422)["errors"]

      conn =
        post(conn, ~p"/api/quality_controls",
          quality_control: %{domain_ids: [1, 2], source_id: 10}
        )

      assert %{"name" => ["can't be blank"]} = json_response(conn, 422)["errors"]
    end

    @tag authentication: [
           role: "user",
           permissions: ["view_quality_controls", "write_quality_controls"]
         ]
    test "user with permission can create quality control", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{"df_type" => template_name} =
        params = string_params_for(:quality_control_params, domain_ids: [domain_id])

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok, %{content: [%{"name" => "group", "fields" => [%{"name" => "foo"}]}]}},
        2
      )

      conn = post(conn, ~p"/api/quality_controls", quality_control: params)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/quality_controls/#{id}")
      assert %{"domain_ids" => [^domain_id]} = json_response(conn, 200)["data"]
    end

    @tag authentication: [
           role: "user",
           permissions: ["view_quality_controls", "write_quality_controls"]
         ]
    test "user with permission cant create quality control in different domain", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{"df_type" => template_name} =
        params = string_params_for(:quality_control_params, domain_ids: [domain_id + 1])

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok, %{content: [%{"name" => "group", "fields" => [%{"name" => "foo"}]}]}}
      )

      conn = post(conn, ~p"/api/quality_controls", quality_control: params)
      assert json_response(conn, 403)
    end

    @tag authentication: [
           role: "user",
           permissions: ["view_quality_controls", "write_quality_controls"]
         ]
    test "user without permission cannot create a published quality control", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{"df_type" => template_name} =
        params =
        string_params_for(:quality_control_params, domain_ids: [domain_id], status: "published")

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok, %{content: []}},
        2
      )

      conn = post(conn, ~p"/api/quality_controls", quality_control: params)
      assert json_response(conn, 403)
    end

    @tag authentication: [
           role: "user",
           permissions: ["view_quality_controls", "write_quality_controls"]
         ]
    test "user must have permission in all domains to create quality control", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{"df_type" => template_name} =
        params =
        string_params_for(:quality_control_params, domain_ids: [domain_id, domain_id + 1])

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok, %{content: []}},
        2
      )

      conn = post(conn, ~p"/api/quality_controls", quality_control: params)
      assert json_response(conn, 403)
    end

    @tag authentication: [
           role: "user",
           permissions: [
             "view_quality_controls",
             "manage_quality_controls"
           ]
         ]
    test "user with permission can create a published quality control", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{"df_type" => template_name} =
        params =
        string_params_for(:quality_control_params, status: "published", domain_ids: [domain_id])

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok, %{content: []}},
        2
      )

      conn = post(conn, ~p"/api/quality_controls", quality_control: params)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/quality_controls/#{id}")
      assert %{"domain_ids" => [^domain_id]} = json_response(conn, 200)["data"]
    end
  end

  describe "create quality_control draft" do
    @tag authentication: [role: "admin"]
    test "renders quality_control when data is valid", %{conn: conn} do
      %{quality_control_id: qc_id} =
        insert(:quality_control_version,
          status: "published",
          quality_control: insert(:quality_control)
        )

      params = %{
        "name" => "new name",
        "control_mode" => "percentage"
      }

      conn = post(conn, ~p"/api/quality_controls/#{qc_id}/draft", quality_control: params)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/quality_controls/#{id}")

      assert %{
               "id" => ^id,
               "name" => "new name",
               "control_mode" => "percentage",
               "version" => 2,
               "status" => "draft"
             } = json_response(conn, 200)["data"]
    end

    @tag authentication: [role: "admin"]
    test "renders quality_control when with published status", %{conn: conn} do
      %{quality_control_id: qc_id} =
        insert(:quality_control_version,
          status: "published",
          quality_control: insert(:quality_control)
        )

      template_name = "df_type"

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok, %{content: [%{"name" => "group", "fields" => [%{"name" => "foo"}]}]}}
      )

      score_criteria = string_params_for(:sc_percentage)
      control_properties = string_params_for(:cp_ratio_params_for)

      params = %{
        "name" => "some name",
        "status" => "published",
        "dynamic_content" => %{"foo" => %{"value" => "bar", "origin" => "user"}},
        "df_type" => template_name,
        "score_criteria" => score_criteria,
        "control_mode" => "percentage",
        "control_properties" => control_properties
      }

      conn = post(conn, ~p"/api/quality_controls/#{qc_id}/draft", quality_control: params)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/quality_controls/#{id}/versions")

      assert [
               %{"version" => 1, "status" => "versioned", "id" => id},
               %{
                 "id" => id,
                 "version" => 2,
                 "status" => "published",
                 "dynamic_content" => %{"foo" => "bar"},
                 "dinamic_content" => %{"foo" => %{"value" => "bar", "origin" => "user"}},
                 "df_type" => "df_type",
                 "domain_ids" => [1, 2],
                 "name" => "some name",
                 "score_criteria" => score_criteria,
                 "control_mode" => "percentage",
                 "control_properties" => control_properties
               }
             ] ||| json_response(conn, 200)["data"]
    end

    @tag authentication: [role: "admin"]
    test "renders errors when published version is invalid", %{conn: conn} do
      %{quality_control_id: qc_id} =
        insert(:quality_control_version,
          status: "published",
          quality_control: insert(:quality_control)
        )

      params = %{
        "name" => "some name",
        "status" => "published"
      }

      conn = post(conn, ~p"/api/quality_controls/#{qc_id}/draft", quality_control: params)

      assert %{
               "dynamic_content" => ["can't be blank"],
               "df_type" => ["can't be blank"],
               "score_criteria" => ["can't be blank"],
               "control_mode" => ["can't be blank"],
               "control_properties" => ["can't be blank"]
             } = json_response(conn, 422)["errors"]
    end

    @tag authentication: [role: "admin"]
    test "renders errors when status is invalid", %{conn: conn} do
      %{quality_control_id: qc_id} =
        insert(:quality_control_version,
          status: "published",
          quality_control: insert(:quality_control)
        )

      params = %{
        "name" => "some name",
        "status" => "pending_approval"
      }

      conn = post(conn, ~p"/api/quality_controls/#{qc_id}/draft", quality_control: params)

      assert %{"status" => ["is invalid"]} = json_response(conn, 422)["errors"]
    end

    @tag authentication: [role: "admin"]
    test "renders errors when data is invalid", %{conn: conn} do
      %{quality_control_id: qc_id} =
        insert(:quality_control_version,
          status: "published",
          quality_control: insert(:quality_control)
        )

      conn = post(conn, ~p"/api/quality_controls/#{qc_id}/draft", quality_control: %{})

      assert %{"name" => ["can't be blank"]} = json_response(conn, 422)["errors"]
    end

    @tag authentication: [role: "admin"]
    test "renders errors when latest version is not published", %{conn: conn} do
      %{quality_control_id: qc_id} =
        insert(:quality_control_version,
          status: "pending_approval",
          quality_control: insert(:quality_control)
        )

      conn = post(conn, ~p"/api/quality_controls/#{qc_id}/draft", quality_control: %{})

      assert "invalid action create_draft not published" = json_response(conn, 422)["errors"]
    end

    @tag authentication: [
           role: "user",
           permissions: ["view_quality_controls", "write_quality_controls"]
         ]
    test "user with permission can create quality control draft", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{quality_control_id: qc_id} =
        insert(:quality_control_version,
          status: "published",
          quality_control: build(:quality_control, domain_ids: [domain_id])
        )

      %{"df_type" => template_name} = params = string_params_for(:quality_control_params)

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok, %{content: []}},
        2
      )

      conn = post(conn, ~p"/api/quality_controls/#{qc_id}/draft", quality_control: params)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/quality_controls/#{id}")
      assert %{"domain_ids" => [^domain_id]} = json_response(conn, 200)["data"]
    end

    @tag authentication: [
           role: "user",
           permissions: ["view_quality_controls", "write_quality_controls"]
         ]
    test "user with permission cant create quality control draft in different domain", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{quality_control_id: qc_id} =
        insert(:quality_control_version,
          status: "published",
          quality_control: build(:quality_control, domain_ids: [domain_id + 1])
        )

      %{"df_type" => template_name} = params = string_params_for(:quality_control_params)

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok, %{content: []}}
      )

      conn = post(conn, ~p"/api/quality_controls/#{qc_id}/draft", quality_control: params)
      assert json_response(conn, 403)
    end

    @tag authentication: [
           role: "user",
           permissions: ["view_quality_controls", "write_quality_controls"]
         ]
    test "user without permission cannot create a published quality control draft", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{quality_control_id: qc_id} =
        insert(:quality_control_version,
          status: "published",
          quality_control: build(:quality_control, domain_ids: [domain_id])
        )

      %{"df_type" => template_name} =
        params = string_params_for(:quality_control_params, status: "published")

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok, %{content: []}},
        2
      )

      conn = post(conn, ~p"/api/quality_controls/#{qc_id}/draft", quality_control: params)
      assert json_response(conn, 403)
    end

    @tag authentication: [
           role: "user",
           permissions: ["view_quality_controls", "write_quality_controls"]
         ]
    test "user must have permission in all domains to create quality control draft", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{quality_control_id: qc_id} =
        insert(:quality_control_version,
          status: "published",
          quality_control: build(:quality_control, domain_ids: [domain_id, domain_id + 1])
        )

      %{"df_type" => template_name} = params = string_params_for(:quality_control_params)

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok, %{content: []}},
        2
      )

      conn = post(conn, ~p"/api/quality_controls/#{qc_id}/draft", quality_control: params)
      assert json_response(conn, 403)
    end

    @tag authentication: [
           role: "user",
           permissions: [
             "view_quality_controls",
             "manage_quality_controls"
           ]
         ]
    test "user with permission can create a published quality control draft", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{quality_control_id: qc_id} =
        insert(:quality_control_version,
          status: "published",
          quality_control: build(:quality_control, domain_ids: [domain_id])
        )

      %{"df_type" => template_name} =
        params = string_params_for(:quality_control_params, status: "published")

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok, %{content: []}},
        2
      )

      conn = post(conn, ~p"/api/quality_controls/#{qc_id}/draft", quality_control: params)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/quality_controls/#{id}")
      assert %{"domain_ids" => [^domain_id]} = json_response(conn, 200)["data"]
    end
  end

  describe "update quality_control status" do
    @tag authentication: [role: "admin"]
    test "handles invalid action", %{conn: conn} do
      %{quality_control_id: qc_id} =
        insert(:quality_control_version,
          status: "draft",
          quality_control: insert(:quality_control)
        )

      params = %{"action" => "invalid_action"}

      conn = patch(conn, ~p"/api/quality_controls/#{qc_id}/status", params)

      assert %{"errors" => "invalid action invalid_action"} = json_response(conn, 422)
    end

    @tag authentication: [role: "admin"]
    test "handles send_to_draft action", %{conn: conn} do
      %{quality_control_id: qc_id} =
        insert(:quality_control_version,
          status: "rejected",
          quality_control: insert(:quality_control)
        )

      params = %{"action" => "send_to_draft"}

      conn = patch(conn, ~p"/api/quality_controls/#{qc_id}/status", params)

      assert %{"data" => %{"id" => ^qc_id, "status" => "draft"}} = json_response(conn, 200)
    end

    @tag authentication: [role: "admin"]
    test "handles publish action when there is already a published version", %{conn: conn} do
      %{id: qc_id} = quality_control = insert(:quality_control)

      template_name = "df_type"

      TdDfMock.get_template_by_name!(&Mox.expect/4, template_name, {:ok, %{content: []}})

      insert(:quality_control_version,
        status: "published",
        quality_control: quality_control,
        version: 1
      )

      insert(:quality_control_version,
        status: "draft",
        quality_control: quality_control,
        version: 2,
        df_type: template_name
      )

      params = %{"action" => "publish"}

      conn = patch(conn, ~p"/api/quality_controls/#{qc_id}/status", params)
      assert %{"data" => %{"id" => ^qc_id, "status" => "published"}} = json_response(conn, 200)

      conn = get(conn, ~p"/api/quality_controls/#{qc_id}/versions", params)

      assert [
               %{"id" => qc_id, "version" => 1, "status" => "versioned"},
               %{"id" => qc_id, "version" => 2, "status" => "published"}
             ] ||| json_response(conn, 200)["data"]
    end

    @tag authentication: [role: "admin"]
    test "handles error for incompatible action", %{conn: conn} do
      %{quality_control_id: qc_id} =
        insert(:quality_control_version,
          status: "pending_approval",
          quality_control: insert(:quality_control)
        )

      params = %{"action" => "send_to_draft"}

      conn = patch(conn, ~p"/api/quality_controls/#{qc_id}/status", params)

      assert %{"errors" => "invalid action send_to_draft"} = json_response(conn, 422)
    end

    @version_statuses QualityControlVersion.valid_statuses()
    @version_actions QualityControlVersion.valid_actions()
    @valid_actions_statuses QualityControlVersion.valid_actions_statuses()

    for previous_status <- @version_statuses do
      for action <- @version_actions do
        @tag [
          authentication: [role: "admin"],
          previous_status: previous_status,
          action: action
        ]
        test "validate status change #{previous_status} with action #{action}", %{
          conn: conn,
          previous_status: previous_status,
          action: action
        } do
          template_name = "df_type"

          if action in ["publish", "send_to_approval", "restore"] do
            TdDfMock.get_template_by_name!(&Mox.expect/4, template_name, {:ok, %{content: []}})
          end

          %{quality_control_id: qc_id} =
            _quality_control_version =
            insert(:quality_control_version,
              status: previous_status,
              df_type: template_name,
              quality_control: insert(:quality_control)
            )

          params = %{"action" => action}

          conn = patch(conn, ~p"/api/quality_controls/#{qc_id}/status", params)

          if _is_valid = {previous_status, action} in @valid_actions_statuses do
            assert %{"id" => ^qc_id} = json_response(conn, 200)["data"]
          else
            assert json_response(conn, 422)["errors"] =~ "invalid action #{action}"
          end
        end
      end
    end

    @tag authentication: [
           role: "user",
           permissions: ["view_quality_controls", "write_quality_controls"]
         ]
    test "user with permission can update draft to pending approval", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{quality_control_id: qc_id, df_type: template_name} =
        insert(:quality_control_version,
          status: "draft",
          quality_control: build(:quality_control, domain_ids: [domain_id])
        )

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok, %{content: []}}
      )

      params = %{"action" => "send_to_approval"}
      conn = patch(conn, ~p"/api/quality_controls/#{qc_id}/status", params)
      assert %{"id" => ^qc_id} = json_response(conn, 200)["data"]
    end

    @tag authentication: [
           role: "user",
           permissions: ["view_quality_controls", "write_quality_controls"]
         ]
    test "user with permission cant update draft to pending approval in different domain", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{quality_control_id: qc_id, df_type: template_name} =
        insert(:quality_control_version,
          status: "draft",
          quality_control: build(:quality_control, domain_ids: [domain_id + 1])
        )

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok, %{content: []}}
      )

      params = %{"action" => "send_to_approval"}
      conn = patch(conn, ~p"/api/quality_controls/#{qc_id}/status", params)
      assert json_response(conn, 403)
    end

    @tag authentication: [
           role: "user",
           permissions: ["view_quality_controls", "write_quality_controls"]
         ]
    test "user without publish permission cannot do so", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{quality_control_id: qc_id, df_type: template_name} =
        insert(:quality_control_version,
          status: "draft",
          quality_control: build(:quality_control, domain_ids: [domain_id])
        )

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok, %{content: []}}
      )

      params = %{"action" => "publish"}
      conn = patch(conn, ~p"/api/quality_controls/#{qc_id}/status", params)
      assert json_response(conn, 403)
    end
  end

  describe "update quality_control draft" do
    @tag authentication: [role: "admin"]
    test "renders quality_control when data is valid", %{conn: conn} do
      %{quality_control_id: qc_id} =
        insert(:quality_control_version, version: 1, quality_control: insert(:quality_control))

      control_properties = string_params_for(:cp_ratio_params_for)

      params = %{
        "name" => "new name",
        "df_type" => "df_type",
        "dynamic_content" => %{"foo" => %{"value" => "bar", "origin" => "user"}},
        "status" => "not_changed",
        "version" => 10,
        "domain_ids" => [5, 6],
        "control_properties" => control_properties
      }

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        "df_type",
        {:ok, %{content: []}},
        2
      )

      conn = patch(conn, ~p"/api/quality_controls/#{qc_id}/draft", quality_control: params)
      assert %{"id" => id} = json_response(conn, 200)["data"]

      conn = get(conn, ~p"/api/quality_controls/#{id}")

      assert %{
               "domain_ids" => [1, 2],
               "id" => ^qc_id,
               "name" => "new name",
               "version" => 1,
               "status" => "draft",
               "df_type" => "df_type",
               "dynamic_content" => %{"foo" => %{"value" => "bar", "origin" => "user"}},
               "control_properties" => result_control_properties
             } = json_response(conn, 200)["data"]

      assert control_properties ==
               QueryableHelpers.drop_properties_embedded(result_control_properties)
    end

    @tag authentication: [role: "admin"]
    test "renders errors when name is duplicated", %{conn: conn} do
      insert(:quality_control_version,
        name: "name1",
        quality_control: insert(:quality_control)
      )

      %{quality_control_id: qc_id} =
        insert(:quality_control_version, name: "name2", quality_control: insert(:quality_control))

      params = %{"name" => "name1"}
      conn = patch(conn, ~p"/api/quality_controls/#{qc_id}/draft", quality_control: params)

      assert %{"name" => ["duplicated_name"]} = json_response(conn, 422)["errors"]
    end

    @tag authentication: [role: "admin"]
    test "renders errors when name is empty", %{conn: conn} do
      %{quality_control_id: qc_id} =
        insert(:quality_control_version, name: "name0", quality_control: insert(:quality_control))

      params = %{"name" => ""}
      conn = patch(conn, ~p"/api/quality_controls/#{qc_id}/draft", quality_control: params)
      assert %{"name" => ["can't be blank"]} = json_response(conn, 422)["errors"]

      params = %{"name" => nil}
      conn = patch(conn, ~p"/api/quality_controls/#{qc_id}/draft", quality_control: params)
      assert %{"name" => ["can't be blank"]} = json_response(conn, 422)["errors"]
    end

    @tag authentication: [role: "admin"]
    test "renders errors when updating a version with incorrect status", %{conn: conn} do
      %{quality_control_id: qc_id} =
        insert(:quality_control_version,
          name: "name0",
          status: "pending_approval",
          quality_control: insert(:quality_control)
        )

      params = %{"name" => ""}
      conn = patch(conn, ~p"/api/quality_controls/#{qc_id}/draft", quality_control: params)
      assert "invalid action update_draft not a draft" = json_response(conn, 422)["errors"]
    end

    @tag authentication: [
           role: "user",
           permissions: ["view_quality_controls", "write_quality_controls"]
         ]
    test "user with permission can update quality control draft", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{quality_control_id: qc_id} =
        insert(:quality_control_version,
          status: "draft",
          quality_control:
            build(:quality_control,
              domain_ids: [domain_id]
            )
        )

      %{"df_type" => template_name} = params = string_params_for(:quality_control_params)

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok, %{content: []}},
        2
      )

      conn = patch(conn, ~p"/api/quality_controls/#{qc_id}/draft", quality_control: params)
      assert %{"id" => id} = json_response(conn, 200)["data"]

      conn = get(conn, ~p"/api/quality_controls/#{id}")
      assert %{"domain_ids" => [^domain_id]} = json_response(conn, 200)["data"]
    end

    @tag authentication: [
           role: "user",
           permissions: ["view_quality_controls", "write_quality_controls"]
         ]
    test "user with permission cant update quality control draft in different domain", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{quality_control_id: qc_id} =
        insert(:quality_control_version,
          status: "draft",
          quality_control:
            build(:quality_control,
              domain_ids: [domain_id + 1]
            )
        )

      %{"df_type" => template_name} = params = string_params_for(:quality_control_params)

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok, %{content: []}}
      )

      conn = patch(conn, ~p"/api/quality_controls/#{qc_id}/draft", quality_control: params)
      assert json_response(conn, 403)
    end

    @tag authentication: [
           role: "user",
           permissions: ["view_quality_controls", "manage_quality_controls"]
         ]
    test "user with permission can update main quality control", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{quality_control_id: qc_id} =
        insert(:quality_control_version,
          status: "draft",
          quality_control:
            build(:quality_control,
              domain_ids: [domain_id]
            )
        )

      %{id: new_domain_id} = CacheHelpers.insert_domain()

      params = %{
        domain_ids: [new_domain_id],
        active: false
      }

      conn = patch(conn, ~p"/api/quality_controls/#{qc_id}/main", quality_control: params)

      assert %{"id" => ^qc_id, "domain_ids" => [^new_domain_id], "active" => false} =
               json_response(conn, 200)["data"]
    end

    @tag authentication: [
           role: "user",
           permissions: ["view_quality_controls"]
         ]
    test "user without permission cant update main quality control", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{quality_control_id: qc_id} =
        insert(:quality_control_version,
          status: "draft",
          quality_control:
            build(:quality_control,
              domain_ids: [domain_id]
            )
        )

      %{id: new_domain_id} = CacheHelpers.insert_domain()

      params = %{
        domain_ids: [new_domain_id],
        active: false
      }

      conn = patch(conn, ~p"/api/quality_controls/#{qc_id}/main", quality_control: params)
      assert json_response(conn, 403)
    end
  end

  describe "delete quality_control" do
    @tag authentication: [role: "admin"]
    test "deletes chosen quality_control", %{conn: conn} do
      quality_control = insert(:quality_control)
      conn = delete(conn, ~p"/api/quality_controls/#{quality_control}")
      assert response(conn, 204)

      assert_error_sent(404, fn ->
        get(conn, ~p"/api/quality_controls/#{quality_control}")
      end)
    end
  end

  describe "get quality control queries" do
    @tag authentication: [role: "admin"]
    test "will return queries for a version", %{conn: conn} do
      %{quality_control_id: id} =
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
        {:ok, %{name: "ds888", metadata: %{}}}
      )

      conn = get(conn, ~p"/api/quality_controls/#{id}/queries")

      assert %{"data" => %{"queries" => queries, "resources_lookup" => lookup}} =
               json_response(conn, 200)

      assert [
               %{
                 "__type__" => "query",
                 "action" => "count",
                 "resource" => %{
                   "__type__" => "data_view",
                   "queryables" => [%{"__type__" => "from"}],
                   "resource_refs" => %{"0" => %{"id" => 888}}
                 }
               },
               %{
                 "__type__" => "query",
                 "action" => "count",
                 "resource" => %{
                   "__type__" => "data_view",
                   "queryables" => [
                     %{"__type__" => "from"},
                     %{"__type__" => "where"}
                   ]
                 }
               }
             ] = queries

      assert lookup == %{
               "data_structure:888" => %{"id" => 888, "metadata" => %{}, "name" => "ds888"}
             }
    end

    @tag authentication: [
           role: "user",
           permissions: ["view_quality_controls", "write_quality_controls"]
         ]
    test "for non admin with permission returns correct queries", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{quality_control_id: id} =
        insert(:quality_control_version,
          status: "draft",
          quality_control: build(:quality_control, domain_ids: [domain_id]),
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
        {:ok, %{name: "ds888", metadata: %{}}}
      )

      conn = get(conn, ~p"/api/quality_controls/#{id}/queries")

      assert %{"data" => %{"queries" => queries, "resources_lookup" => lookup}} =
               json_response(conn, 200)

      assert [
               %{
                 "__type__" => "query",
                 "action" => "count",
                 "resource" => %{
                   "__type__" => "data_view",
                   "queryables" => [%{"__type__" => "from"}],
                   "resource_refs" => %{"0" => %{"id" => 888}}
                 }
               },
               %{
                 "__type__" => "query",
                 "action" => "count",
                 "resource" => %{
                   "__type__" => "data_view",
                   "queryables" => [
                     %{"__type__" => "from"},
                     %{"__type__" => "where"}
                   ]
                 }
               }
             ] = queries

      assert lookup == %{
               "data_structure:888" => %{"id" => 888, "metadata" => %{}, "name" => "ds888"}
             }
    end

    @tag authentication: [
           role: "user",
           permissions: ["view_quality_controls", "write_quality_controls"]
         ]
    test "non admin with permission in different domain does not have access", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{quality_control_id: id} =
        insert(:quality_control_version,
          status: "draft",
          quality_control: build(:quality_control, domain_ids: [domain_id + 1])
        )

      conn = get(conn, ~p"/api/quality_controls/#{id}/queries")
      assert json_response(conn, 403)
    end
  end

  describe "get quality control queries by source_id" do
    @tag authentication: [role: "admin"]
    test "will return queries for a source_id", %{conn: conn} do
      source_id = 8

      insert(:quality_control_version,
        status: "published",
        quality_control: insert(:quality_control, source_id: source_id),
        control_properties:
          build(:control_properties,
            ratio:
              build(:cp_ratio,
                resource: build(:resource, type: "data_structure", id: 888)
              )
          )
      )

      insert(:quality_control_version,
        status: "published",
        quality_control: insert(:quality_control, source_id: source_id),
        control_properties:
          build(:control_properties,
            ratio:
              build(:cp_ratio,
                resource: build(:resource, type: "data_structure", id: 999)
              )
          )
      )

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

      conn = get(conn, ~p"/api/quality_controls/queries/#{source_id}")

      assert %{"data" => %{"quality_controls" => quality_controls, "resources_lookup" => lookup}} =
               json_response(conn, 200)

      assert [
               %{
                 "queries" => [
                   %{
                     "__type__" => "query",
                     "action" => "count",
                     "resource" => %{"queryables" => [%{"__type__" => "from"}]}
                   },
                   %{
                     "__type__" => "query",
                     "action" => "count",
                     "resource" => %{
                       "queryables" => [%{"__type__" => "from"}, %{"__type__" => "where"}]
                     }
                   }
                 ]
               },
               %{}
             ] = quality_controls

      assert lookup == %{
               "data_structure:888" => %{"id" => 888, "metadata" => %{}, "name" => "ds888"},
               "data_structure:999" => %{"id" => 999, "metadata" => %{}, "name" => "ds999"}
             }
    end

    @tag authentication: [
           role: "user",
           permissions: ["view_quality_controls", "write_quality_controls"]
         ]
    test "for non admin with permission returns correct queries", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{quality_control_id: id} =
        insert(:quality_control_version,
          status: "draft",
          quality_control: build(:quality_control, domain_ids: [domain_id]),
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
        {:ok, %{name: "ds888", metadata: %{}}}
      )

      conn = get(conn, ~p"/api/quality_controls/#{id}/queries")

      assert %{"data" => %{"queries" => queries, "resources_lookup" => lookup}} =
               json_response(conn, 200)

      assert [
               %{
                 "__type__" => "query",
                 "action" => "count",
                 "resource" => %{
                   "__type__" => "data_view",
                   "queryables" => [%{"__type__" => "from"}],
                   "resource_refs" => %{"0" => %{"id" => 888}}
                 }
               },
               %{
                 "__type__" => "query",
                 "action" => "count",
                 "resource" => %{
                   "__type__" => "data_view",
                   "queryables" => [
                     %{"__type__" => "from"},
                     %{"__type__" => "where"}
                   ]
                 }
               }
             ] = queries

      assert lookup == %{
               "data_structure:888" => %{"id" => 888, "metadata" => %{}, "name" => "ds888"}
             }
    end

    @tag authentication: [
           role: "user",
           permissions: ["view_quality_controls", "write_quality_controls"]
         ]
    test "non admin with permission in different domain does not have access", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{quality_control_id: id} =
        insert(:quality_control_version,
          status: "draft",
          quality_control: build(:quality_control, domain_ids: [domain_id + 1])
        )

      conn = get(conn, ~p"/api/quality_controls/#{id}/queries")
      assert json_response(conn, 403)
    end
  end
end
