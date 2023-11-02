defmodule TdQxWeb.QualityControlControllerTest do
  use TdQxWeb.ConnCase

  alias TdCluster.TestHelpers.TdDfMock
  alias TdCore.Search.MockIndexWorker
  alias TdQx.QualityControls.QualityControlVersion

  setup %{conn: conn} do
    start_supervised!(MockIndexWorker)
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    @tag authentication: [role: "admin"]
    test "lists all quality_controls", %{conn: conn} do
      conn = get(conn, ~p"/api/quality_controls")
      assert json_response(conn, 200)["data"] == []
    end
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
               %{"version" => 1, "status" => "published"},
               %{"version" => 2, "status" => "draft"}
             ] = json_response(conn, 200)["data"]
    end
  end

  describe "show" do
    @tag authentication: [role: "admin"]
    test "will return actions for published version", %{conn: conn} do
      %{quality_control_id: id} = insert(:quality_control_version, status: "published")
      conn = get(conn, ~p"/api/quality_controls/#{id}")
      assert %{"_actions" => ["deprecate", "create_draft"]} = json_response(conn, 200)
    end

    @tag authentication: [role: "admin"]
    test "will return actions for deprecated version", %{conn: conn} do
      %{quality_control_id: id} = insert(:quality_control_version, status: "deprecated")
      conn = get(conn, ~p"/api/quality_controls/#{id}")
      assert %{"_actions" => ["restore"]} = json_response(conn, 200)
    end

    @tag authentication: [role: "admin"]
    test "will return actions for draft with incomplete version", %{conn: conn} do
      %{quality_control_id: id, df_type: template_name} =
        insert(:quality_control_version, status: "draft", validation: [])

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok, %{content: []}}
      )

      conn = get(conn, ~p"/api/quality_controls/#{id}")
      assert %{"_actions" => ["edit"]} = json_response(conn, 200)
    end

    @tag authentication: [role: "admin"]
    test "will return actions for draft with valid version", %{conn: conn} do
      %{quality_control_id: id, df_type: template_name} =
        insert(:quality_control_version, status: "draft")

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok, %{content: []}},
        2
      )

      conn = get(conn, ~p"/api/quality_controls/#{id}")
      assert %{"_actions" => ["send_to_approval", "publish", "edit"]} = json_response(conn, 200)
    end

    @tag authentication: [
           role: "user",
           permissions: ["view_quality_controls", "create_quality_controls"]
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
      assert %{"_actions" => ["send_to_approval", "edit"]} = json_response(conn, 200)
    end

    @tag authentication: [
           role: "user",
           permissions: ["view_quality_controls", "create_quality_controls"]
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

      # TdDfMock.get_template_by_name!(
      #   &Mox.expect/4,
      #   template_name,
      #   {:ok, %{content: []}},
      #   2
      # )

      conn = get(conn, ~p"/api/quality_controls/#{id}")
      assert json_response(conn, 403)
    end
  end

  describe "create quality_control" do
    @tag authentication: [role: "admin"]
    test "renders quality_control when data is valid", %{conn: conn} do
      params = %{
        "domain_ids" => [1, 2],
        "name" => "some name"
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
               "df_content" => nil,
               "df_type" => nil,
               "resource" => nil,
               "result_criteria" => nil,
               "result_type" => nil,
               "validation" => nil
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
        "name" => "some name",
        "status" => "published",
        "df_content" => %{"foo" => "bar"},
        "df_type" => template_name,
        "result_criteria" => string_params_for(:rc_percentage),
        "result_type" => "percentage",
        "resource" => string_params_for(:resource),
        "validation" => [string_params_for(:clause_params_for)]
      }

      conn = post(conn, ~p"/api/quality_controls", quality_control: params)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/quality_controls/#{id}")

      assert %{
               "id" => ^id,
               "version" => 1,
               "status" => "published",
               "df_content" => %{"foo" => "bar"},
               "df_type" => "df_type",
               "domain_ids" => [1, 2],
               "name" => "some name",
               "resource" => %{"id" => _, "type" => "data_view"},
               "result_criteria" => %{"goal" => 90.0, "minimum" => 75.0},
               "result_type" => "percentage",
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
             } = json_response(conn, 200)["data"]
    end

    @tag authentication: [role: "admin"]
    test "renders errors when published version is invalid", %{conn: conn} do
      params = %{
        "domain_ids" => [1, 2],
        "name" => "some name",
        "status" => "published"
      }

      conn = post(conn, ~p"/api/quality_controls", quality_control: params)

      assert %{
               "df_content" => ["can't be blank"],
               "df_type" => ["can't be blank"],
               "resource" => ["can't be blank"],
               "result_criteria" => ["can't be blank"],
               "result_type" => ["can't be blank"],
               "validation" => ["can't be blank"]
             } = json_response(conn, 422)["errors"]
    end

    @tag authentication: [role: "admin"]
    test "renders errors when status is invalid", %{conn: conn} do
      params = %{
        "domain_ids" => [1, 2],
        "name" => "some name",
        "status" => "pending_approval"
      }

      conn = post(conn, ~p"/api/quality_controls", quality_control: params)

      assert %{"status" => ["is invalid"]} = json_response(conn, 422)["errors"]
    end

    @tag authentication: [role: "admin"]
    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/quality_controls", quality_control: %{})

      assert %{"domain_ids" => ["can't be blank"]} = json_response(conn, 422)["errors"]

      conn = post(conn, ~p"/api/quality_controls", quality_control: %{domain_ids: [1, 2]})

      assert %{"name" => ["can't be blank"]} = json_response(conn, 422)["errors"]
    end

    @tag authentication: [
           role: "user",
           permissions: ["view_quality_controls", "create_quality_controls"]
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
           permissions: ["view_quality_controls", "create_quality_controls"]
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
           permissions: ["view_quality_controls", "create_quality_controls"]
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
           permissions: ["view_quality_controls", "create_quality_controls"]
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
             "create_quality_controls",
             "publish_quality_controls"
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
      %{quality_control_id: qc_id} = insert(:quality_control_version, status: "published")

      params = %{
        "name" => "new name"
      }

      conn = post(conn, ~p"/api/quality_controls/#{qc_id}/draft", quality_control: params)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/quality_controls/#{id}")

      assert %{
               "id" => ^id,
               "name" => "new name",
               "version" => 2,
               "status" => "draft"
             } = json_response(conn, 200)["data"]
    end

    @tag authentication: [role: "admin"]
    test "renders quality_control when with published status", %{conn: conn} do
      %{quality_control_id: qc_id} = insert(:quality_control_version, status: "published")

      template_name = "df_type"

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok, %{content: [%{"name" => "group", "fields" => [%{"name" => "foo"}]}]}}
      )

      result_criteria = string_params_for(:rc_percentage)
      resource = string_params_for(:resource)
      clause = string_params_for(:clause_params_for)

      params = %{
        "name" => "some name",
        "status" => "published",
        "df_content" => %{"foo" => "bar"},
        "df_type" => template_name,
        "result_criteria" => result_criteria,
        "result_type" => "percentage",
        "resource" => resource,
        "validation" => [clause]
      }

      conn = post(conn, ~p"/api/quality_controls/#{qc_id}/draft", quality_control: params)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/quality_controls/#{id}/versions")

      assert [
               %{
                 "version" => 1,
                 "status" => "versioned"
               },
               %{
                 "id" => ^id,
                 "version" => 2,
                 "status" => "published",
                 "df_content" => %{"foo" => "bar"},
                 "df_type" => "df_type",
                 "domain_ids" => [1, 2],
                 "name" => "some name",
                 "result_criteria" => ^result_criteria,
                 "result_type" => "percentage",
                 "resource" => ^resource,
                 "validation" => [^clause]
               }
             ] = json_response(conn, 200)["data"]
    end

    @tag authentication: [role: "admin"]
    test "renders errors when published version is invalid", %{conn: conn} do
      %{quality_control_id: qc_id} = insert(:quality_control_version, status: "published")

      params = %{
        "name" => "some name",
        "status" => "published"
      }

      conn = post(conn, ~p"/api/quality_controls/#{qc_id}/draft", quality_control: params)

      assert %{
               "df_content" => ["can't be blank"],
               "df_type" => ["can't be blank"],
               "resource" => ["can't be blank"],
               "result_criteria" => ["can't be blank"],
               "result_type" => ["can't be blank"],
               "validation" => ["can't be blank"]
             } = json_response(conn, 422)["errors"]
    end

    @tag authentication: [role: "admin"]
    test "renders errors when status is invalid", %{conn: conn} do
      %{quality_control_id: qc_id} = insert(:quality_control_version, status: "published")

      params = %{
        "name" => "some name",
        "status" => "pending_approval"
      }

      conn = post(conn, ~p"/api/quality_controls/#{qc_id}/draft", quality_control: params)

      assert %{"status" => ["is invalid"]} = json_response(conn, 422)["errors"]
    end

    @tag authentication: [role: "admin"]
    test "renders errors when data is invalid", %{conn: conn} do
      %{quality_control_id: qc_id} = insert(:quality_control_version, status: "published")
      conn = post(conn, ~p"/api/quality_controls/#{qc_id}/draft", quality_control: %{})

      assert %{"name" => ["can't be blank"]} = json_response(conn, 422)["errors"]
    end

    @tag authentication: [role: "admin"]
    test "renders errors when latest version is not published", %{conn: conn} do
      %{quality_control_id: qc_id} = insert(:quality_control_version, status: "pending_approval")
      conn = post(conn, ~p"/api/quality_controls/#{qc_id}/draft", quality_control: %{})

      assert "invalid action create_draft not published" = json_response(conn, 422)["errors"]
    end

    @tag authentication: [
           role: "user",
           permissions: ["view_quality_controls", "create_quality_controls"]
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
           permissions: ["view_quality_controls", "create_quality_controls"]
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
           permissions: ["view_quality_controls", "create_quality_controls"]
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
           permissions: ["view_quality_controls", "create_quality_controls"]
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
             "create_quality_controls",
             "publish_quality_controls"
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
      %{quality_control_id: qc_id} = insert(:quality_control_version, status: "draft")

      params = %{"action" => "invalid_action"}

      conn = patch(conn, ~p"/api/quality_controls/#{qc_id}/status", params)

      assert %{"errors" => "invalid action invalid_action"} = json_response(conn, 422)
    end

    @tag authentication: [role: "admin"]
    test "handles send_to_draft action", %{conn: conn} do
      %{quality_control_id: qc_id} = insert(:quality_control_version, status: "rejected")

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
               %{"version" => 1, "status" => "versioned"},
               %{"version" => 2, "status" => "published"}
             ] = json_response(conn, 200)["data"]
    end

    @tag authentication: [role: "admin"]
    test "handles error for incompatible action", %{conn: conn} do
      %{quality_control_id: qc_id} = insert(:quality_control_version, status: "pending_approval")

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
            insert(:quality_control_version, status: previous_status, df_type: template_name)

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
           permissions: ["view_quality_controls", "create_quality_controls"]
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
           permissions: ["view_quality_controls", "create_quality_controls"]
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
           permissions: ["view_quality_controls", "create_quality_controls"]
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
      %{quality_control_id: qc_id} = insert(:quality_control_version, version: 1)

      resource = string_params_for(:resource)
      clause = string_params_for(:clause_params_for)

      params = %{
        "name" => "new name",
        "resource" => resource,
        "validation" => [clause],
        "df_type" => "df_type",
        "df_content" => %{"foo" => "bar"},
        "status" => "not_changed",
        "version" => 10,
        "domain_ids" => [5, 6]
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
               "df_content" => %{"foo" => "bar"},
               "resource" => ^resource,
               "validation" => [^clause]
             } = json_response(conn, 200)["data"]
    end

    @tag authentication: [role: "admin"]
    test "renders errors when name is duplicated", %{conn: conn} do
      insert(:quality_control_version, name: "name1")
      %{quality_control_id: qc_id} = insert(:quality_control_version, name: "name2")

      params = %{"name" => "name1"}
      conn = patch(conn, ~p"/api/quality_controls/#{qc_id}/draft", quality_control: params)

      assert %{"name" => ["duplicated_name"]} = json_response(conn, 422)["errors"]
    end

    @tag authentication: [role: "admin"]
    test "renders errors when name is empty", %{conn: conn} do
      %{quality_control_id: qc_id} = insert(:quality_control_version, name: "name0")

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
        insert(:quality_control_version, name: "name0", status: "pending_approval")

      params = %{"name" => ""}
      conn = patch(conn, ~p"/api/quality_controls/#{qc_id}/draft", quality_control: params)
      assert "invalid action update_draft not a draft" = json_response(conn, 422)["errors"]
    end

    @tag authentication: [
           role: "user",
           permissions: ["view_quality_controls", "create_quality_controls"]
         ]
    test "user with permission can update quality control draft", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{quality_control_id: qc_id} =
        insert(:quality_control_version,
          status: "draft",
          quality_control: build(:quality_control, domain_ids: [domain_id])
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
           permissions: ["view_quality_controls", "create_quality_controls"]
         ]
    test "user with permission cant update quality control draft in different domain", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{quality_control_id: qc_id} =
        insert(:quality_control_version,
          status: "draft",
          quality_control: build(:quality_control, domain_ids: [domain_id + 1])
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
end
