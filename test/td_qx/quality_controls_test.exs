defmodule TdQx.QualityControlsTest do
  use TdQx.DataCase

  import TdQx.TestOperators

  alias TdQx.QualityControls
  alias TdQx.QualityControls.QualityControl
  alias TdQx.QualityControls.QualityControlVersion

  describe "quality_controls" do
    @invalid_attrs %{description: nil, domain_ids: nil, name: nil}

    test "list_quality_controls/0 returns all quality_controls" do
      quality_control = insert(:quality_control)
      assert QualityControls.list_quality_controls() ||| [quality_control]
    end

    test "list_quality_control_latest_versions/0 returns all latest version quality_controls" do
      %{id: qc1_id} = qc1 = insert(:quality_control)
      insert(:quality_control_version, quality_control: qc1, version: 1, status: "published")
      insert(:quality_control_version, quality_control: qc1, version: 2, status: "draft")

      %{id: qc2_id} = qc2 = insert(:quality_control)
      insert(:quality_control_version, quality_control: qc2, version: 1, status: "published")

      %{id: qc3_id} = qc3 = insert(:quality_control)
      insert(:quality_control_version, quality_control: qc3, version: 1, status: "versioned")
      insert(:quality_control_version, quality_control: qc3, version: 2, status: "versioned")
      insert(:quality_control_version, quality_control: qc3, version: 3, status: "deprecated")

      assert [
               %{id: ^qc1_id, latest_version: %{version: 2, status: "draft"}},
               %{id: ^qc2_id, latest_version: %{version: 1, status: "published"}},
               %{id: ^qc3_id, latest_version: %{version: 3, status: "deprecated"}}
             ] = QualityControls.list_quality_control_latest_versions()
    end

    test "get_quality_control!/2 returns the quality_control with given id" do
      quality_control = insert(:quality_control)
      assert QualityControls.get_quality_control!(quality_control.id) == quality_control
    end

    test "get_quality_control!/2 enriched the lastest version" do
      quality_control = insert(:quality_control)

      _version_1 =
        insert(:quality_control_version,
          version: 1,
          status: "published",
          quality_control: quality_control
        )

      %{id: qcv_id} =
        insert(:quality_control_version, version: 2, quality_control: quality_control)

      assert %{
               latest_version: %QualityControlVersion{id: ^qcv_id}
             } = QualityControls.get_quality_control!(quality_control.id)
    end

    test "get_quality_control!/2 enriched the published version" do
      quality_control = insert(:quality_control)

      %{id: qcv_id} =
        insert(:quality_control_version,
          version: 1,
          status: "published",
          quality_control: quality_control
        )

      _not_published_version =
        insert(:quality_control_version, version: 2, quality_control: quality_control)

      assert %{
               published_version: %QualityControlVersion{id: ^qcv_id}
             } =
               QualityControls.get_quality_control!(quality_control.id,
                 preload: :published_version
               )
    end

    test "get_quality_control!/2 enrich domains option" do
      %{id: domain_id, external_id: domain_external_id, name: domain_name} =
        CacheHelpers.insert_domain()

      %{id: id} = insert(:quality_control, domain_ids: [domain_id])

      assert %{
               domains: [
                 %{
                   id: ^domain_id,
                   name: ^domain_name,
                   external_id: ^domain_external_id
                 }
               ]
             } = QualityControls.get_quality_control!(id, enrich: [:domains])
    end

    test "delete_quality_control/1 deletes the quality_control" do
      quality_control = insert(:quality_control)
      assert {:ok, %QualityControl{}} = QualityControls.delete_quality_control(quality_control)

      assert_raise Ecto.NoResultsError, fn ->
        QualityControls.get_quality_control!(quality_control.id)
      end
    end

    test "update_quality_control/1 only update active" do
      %{domain_ids: domain_ids, active: true} = quality_control = insert(:quality_control)

      assert {:ok, %{domain_ids: ^domain_ids, active: false}} =
               QualityControls.update_quality_control(quality_control, %{
                 "active" => false,
                 "domains_ids" => [100]
               })
    end
  end

  describe "quality_control_versions" do
    @invalid_attrs %{
      dynamic_content: nil,
      df_type: nil,
      score_criteria: nil,
      control_mode: nil,
      status: nil,
      control_properties: nil,
      version: nil
    }

    test "list_quality_control_versions/0 returns all quality_control_versions" do
      %{quality_control_id: quality_control_id} =
        quality_control_version =
        insert(:quality_control_version, quality_control: insert(:quality_control))

      insert(:quality_control_version, quality_control: insert(:quality_control))

      assert QualityControls.list_quality_control_versions(quality_control_id) |||
               [
                 quality_control_version
               ]
    end

    test "get_quality_control_version!/1 returns the quality_control_version with given id" do
      quality_control_version =
        insert(:quality_control_version, quality_control: insert(:quality_control))

      assert QualityControls.get_quality_control_version!(quality_control_version.id)
             <~> quality_control_version
    end

    test "create_quality_control_version/1 with valid data creates a quality_control_version" do
      quality_control = insert(:quality_control)

      valid_attrs = %{
        name: "some name",
        dynamic_content: %{},
        df_type: "some df_type",
        score_criteria: params_for(:sc_percentage),
        control_mode: "percentage",
        control_properties: params_for(:cp_ratio_params_for)
      }

      assert {:ok, %QualityControlVersion{} = quality_control_version} =
               QualityControls.create_quality_control_version(quality_control, valid_attrs)

      assert quality_control_version.name == "some name"
      assert quality_control_version.dynamic_content == %{}
      assert quality_control_version.df_type == "some df_type"
      assert quality_control_version.status == "draft"
      assert quality_control_version.version == 1
      assert quality_control_version.control_mode == "percentage"
      assert %{percentage: %{goal: 90.0, minimum: 75.0}} = quality_control_version.score_criteria

      assert %{
               ratio: %{
                 resource: %{id: _, type: "data_view"},
                 validation: [
                   %{
                     expressions: [
                       %{shape: "constant", value: %{constant: %{type: "string", value: _}}}
                     ]
                   }
                 ]
               }
             } = quality_control_version.control_properties
    end

    test "create_quality_control_version/1 handles invalid control_mode" do
      quality_control = insert(:quality_control)

      attrs = params_for(:quality_control_version_params_for, control_mode: "invalid_type")

      assert {:error, changeset} =
               QualityControls.create_quality_control_version(quality_control, attrs)

      assert %{score_criteria: %{control_mode: ["invalid"]}} = errors_on(changeset)
    end

    test "create_quality_control_version/1 handles invalid deviation score_criteria" do
      quality_control = insert(:quality_control)

      attrs = params_for(:quality_control_version_params_for, control_mode: "deviation")

      # Goal < 0
      attrs = Map.put(attrs, :score_criteria, %{goal: -1})

      assert {:error, changeset} =
               QualityControls.create_quality_control_version(quality_control, attrs)

      %{score_criteria: %{deviation: error}} = errors_on(changeset)

      assert %{goal: ["must be greater than or equal to 0"]} = error

      # Goal > 100
      attrs = Map.put(attrs, :score_criteria, %{goal: 101})

      assert {:error, changeset} =
               QualityControls.create_quality_control_version(quality_control, attrs)

      %{score_criteria: %{deviation: error}} = errors_on(changeset)

      assert %{goal: ["must be less than or equal to 100"]} = error

      # Maximum > 100
      attrs = Map.put(attrs, :score_criteria, %{goal: 90, maximum: 101})

      assert {:error, changeset} =
               QualityControls.create_quality_control_version(quality_control, attrs)

      %{score_criteria: %{deviation: error}} = errors_on(changeset)

      assert %{maximum: ["must be less than or equal to 100"]} = error

      # Maximum < Goal
      attrs = Map.put(attrs, :score_criteria, %{goal: 50, maximum: 25})

      assert {:error, changeset} =
               QualityControls.create_quality_control_version(quality_control, attrs)

      %{score_criteria: %{deviation: error}} = errors_on(changeset)

      assert %{maximum: ["must be greater than or equal to 50.0"]} = error
    end

    test "create_quality_control_version/1 handles invalid error_count score_criteria" do
      quality_control = insert(:quality_control)

      attrs =
        params_for(:quality_control_version_params_for, control_mode: "error_count")

      # Goal < 0
      attrs = Map.put(attrs, :score_criteria, %{goal: -1})

      assert {:error, changeset} =
               QualityControls.create_quality_control_version(quality_control, attrs)

      %{score_criteria: %{error_count: error}} = errors_on(changeset)

      assert %{goal: ["must be greater than or equal to 0"]} = error

      # Maximum < Goal
      attrs = Map.put(attrs, :score_criteria, %{goal: 50, maximum: 10})

      assert {:error, changeset} =
               QualityControls.create_quality_control_version(quality_control, attrs)

      %{score_criteria: %{error_count: error}} = errors_on(changeset)

      assert %{maximum: ["must be greater than or equal to 50"]} = error
    end

    test "create_quality_control_version/1 handles invalid percentage score_criteria" do
      quality_control = insert(:quality_control)

      attrs = params_for(:quality_control_version_params_for, control_mode: "percentage")

      # Goal < 0
      attrs = Map.put(attrs, :score_criteria, %{goal: -1})

      assert {:error, changeset} =
               QualityControls.create_quality_control_version(quality_control, attrs)

      %{score_criteria: %{percentage: error}} = errors_on(changeset)

      assert %{goal: ["must be greater than or equal to 0"]} = error

      # Goal > 100
      attrs = Map.put(attrs, :score_criteria, %{goal: 101})

      assert {:error, changeset} =
               QualityControls.create_quality_control_version(quality_control, attrs)

      %{score_criteria: %{percentage: error}} = errors_on(changeset)

      assert %{goal: ["must be less than or equal to 100"]} = error

      # Minimum < 0
      attrs = Map.put(attrs, :score_criteria, %{goal: 90, minimum: -1})

      assert {:error, changeset} =
               QualityControls.create_quality_control_version(quality_control, attrs)

      %{score_criteria: %{percentage: error}} = errors_on(changeset)

      assert %{minimum: ["must be greater than or equal to 0"]} = error

      # Minimum > Goal
      attrs = Map.put(attrs, :score_criteria, %{goal: 50, minimum: 75})

      assert {:error, changeset} =
               QualityControls.create_quality_control_version(quality_control, attrs)

      %{score_criteria: %{percentage: error}} = errors_on(changeset)

      assert %{minimum: ["must be less than or equal to 50.0"]} = error
    end

    test "create_quality_control_version/1 with invalid data returns error changeset" do
      quality_control = insert(:quality_control)

      assert {:error, %Ecto.Changeset{}} =
               QualityControls.create_quality_control_version(quality_control, @invalid_attrs)
    end

    test "delete_quality_control_version/1 deletes the quality_control_version" do
      quality_control_version =
        insert(:quality_control_version, quality_control: insert(:quality_control))

      assert {:ok, %QualityControlVersion{}} =
               QualityControls.delete_quality_control_version(quality_control_version)

      assert_raise Ecto.NoResultsError, fn ->
        QualityControls.get_quality_control_version!(quality_control_version.id)
      end
    end
  end
end
