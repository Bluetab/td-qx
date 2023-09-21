defmodule TdQx.DataViewsTest do
  use TdQx.DataCase

  import ExUnit.CaptureLog
  import QueryableHelpers

  alias TdCluster.TestHelpers.TdDdMock
  alias TdQx.DataViews

  describe "data_views" do
    alias TdQx.DataViews.DataView

    @invalid_attrs %{name: nil}

    test "list_data_views/0 returns all data_views" do
      %{id: id, name: name} = insert(:data_view)

      assert [%{id: ^id, name: ^name}] = DataViews.list_data_views()
    end

    test "list_data_views/0 returns enriched reference_dataset resources" do
      reference_dataset1 =
        %{
          id: ref_ds_id1,
          name: ref_ds_name1
        } = build(:reference_dataset)

      reference_dataset2 =
        %{
          id: ref_ds_id2,
          name: ref_ds_name2
        } = build(:reference_dataset)

      %{
        id: id,
        name: name
      } =
        insert(:data_view,
          queryables: [
            build(:data_view_queryable,
              type: "from",
              properties: %{
                from:
                  build(:qp_from,
                    resource:
                      build(:resource,
                        id: ref_ds_id1,
                        type: "reference_dataset"
                      )
                  )
              }
            ),
            build(:data_view_queryable,
              type: "join",
              properties: %{
                join:
                  build(:qp_join,
                    resource:
                      build(:resource,
                        id: ref_ds_id2,
                        type: "reference_dataset"
                      )
                  )
              }
            )
          ]
        )

      TdDdMock.get_reference_dataset(&Mox.expect/4, ref_ds_id1, {:ok, reference_dataset1})
      TdDdMock.get_reference_dataset(&Mox.expect/4, ref_ds_id2, {:ok, reference_dataset2})

      assert [
               %{
                 id: ^id,
                 name: ^name,
                 queryables: [
                   %{
                     properties: %{
                       from: %{
                         resource: %{
                           type: "reference_dataset",
                           embedded: %{
                             id: ^ref_ds_id1,
                             name: ^ref_ds_name1,
                             fields: [
                               %{
                                 name: "header1",
                                 parent_name: ^ref_ds_name1,
                                 type: "string"
                               },
                               %{
                                 name: "header2",
                                 parent_name: ^ref_ds_name1,
                                 type: "string"
                               }
                             ]
                           }
                         }
                       }
                     }
                   },
                   %{
                     properties: %{
                       join: %{
                         resource: %{
                           type: "reference_dataset",
                           embedded: %{
                             id: ^ref_ds_id2,
                             name: ^ref_ds_name2,
                             fields: [
                               %{
                                 name: "header1",
                                 parent_name: ^ref_ds_name2,
                                 type: "string"
                               },
                               %{
                                 name: "header2",
                                 parent_name: ^ref_ds_name2,
                                 type: "string"
                               }
                             ]
                           }
                         }
                       }
                     }
                   }
                 ]
               }
             ] = DataViews.list_data_views(enrich: true)
    end

    test "list_data_views/0 returns enriched data_structure resources" do
      ds_id = 8

      data_structure_version = %{
        data_structure_id: ds_id,
        name: "data_structure_name",
        data_fields: [
          %{
            data_structure_id: 1,
            name: "field_name",
            metadata: %{
              "data_type_class" => "number"
            }
          }
        ]
      }

      %{
        id: id,
        name: name
      } =
        insert(:data_view,
          queryables: [
            build(:data_view_queryable,
              type: "from",
              properties: %{
                from:
                  build(:qp_from,
                    resource:
                      build(:resource,
                        id: ds_id,
                        type: "data_structure"
                      )
                  )
              }
            )
          ]
        )

      TdDdMock.get_latest_structure_version(&Mox.expect/4, ds_id, {:ok, data_structure_version})

      assert [
               %{
                 id: ^id,
                 name: ^name,
                 queryables: [
                   %{
                     properties: %{
                       from: %{
                         resource: %{
                           type: "data_structure",
                           embedded: %{
                             id: ^ds_id,
                             name: "data_structure_name",
                             fields: [
                               %{
                                 name: "field_name",
                                 parent_name: "data_structure_name",
                                 type: "number"
                               }
                             ]
                           }
                         }
                       }
                     }
                   }
                 ]
               }
             ] = DataViews.list_data_views(enrich: true)
    end

    test "list_data_views/0 returns enriched data_view resources" do
      %{
        id: resource_id,
        name: resource_name,
        select: %{
          properties: %{
            select: %{
              fields: [
                %{
                  alias: field_alias,
                  expression: %{
                    value: %{
                      constant: %{
                        type: field_type
                      }
                    }
                  }
                }
              ]
            }
          }
        }
      } = insert(:data_view)

      %{
        id: id,
        name: name
      } =
        insert(:data_view,
          queryables: [
            build(:data_view_queryable,
              type: "from",
              properties: %{
                from:
                  build(:qp_from,
                    resource:
                      build(:resource,
                        id: resource_id,
                        type: "data_view"
                      )
                  )
              }
            )
          ]
        )

      assert [
               _,
               %{
                 id: ^id,
                 name: ^name,
                 queryables: [
                   %{
                     properties: %{
                       from: %{
                         resource: %{
                           type: "data_view",
                           embedded: %{
                             id: ^resource_id,
                             name: ^resource_name,
                             fields: [
                               %{
                                 name: ^field_alias,
                                 parent_name: ^resource_name,
                                 type: ^field_type
                               }
                             ]
                           }
                         }
                       }
                     }
                   }
                 ]
               }
             ] = Enum.sort_by(DataViews.list_data_views(enrich: true), & &1.id)
    end

    test "list_data_views/0 does not fail to enrich when cluster is not available" do
      ref_ds_id = 1

      %{
        id: id,
        name: name
      } =
        insert_data_view_with_from_resource(
          build(:resource,
            id: ref_ds_id,
            type: "reference_dataset"
          )
        )

      TdDdMock.get_reference_dataset(&Mox.expect/4, ref_ds_id, {:error, nil})

      {result, log} = with_log(fn -> DataViews.list_data_views(enrich: true) end)

      assert [
               %{
                 id: ^id,
                 name: ^name,
                 queryables: [
                   %{
                     properties: %{
                       from: %{
                         resource: %{
                           type: "reference_dataset",
                           embedded: nil
                         }
                       }
                     }
                   }
                 ]
               }
             ] = result

      assert log =~
               "[warning] Failed to enrich %ReferenceDataset{id: #{ref_ds_id}} from cluster"
    end

    test "get_data_view!/1 returns the data_view with given id" do
      %{id: data_view_id, name: data_view_name} = insert(:data_view)

      assert %{id: ^data_view_id, name: ^data_view_name} = DataViews.get_data_view!(data_view_id)
    end

    test "create_data_view/1 with valid data creates a data_view" do
      %{
        name: name,
        description: description,
        created_by_id: created_by_id
      } = valid_attrs = params_for(:data_view_params_for)

      assert {:ok, %DataView{} = data_view} = DataViews.create_data_view(valid_attrs)

      assert data_view.name == name
      assert data_view.description == description
      assert data_view.created_by_id == created_by_id
    end

    test "create_data_view/1 with queryable properties" do
      %{
        resource: %{
          id: resource_id,
          type: resource_type
        },
        clauses: [
          %{
            expressions: [
              %{
                shape: shape
              }
            ]
          }
        ]
      } = properties = params_for(:qp_join_params_for)

      valid_attrs = %{
        name: "data_view",
        created_by_id: 1,
        queryables: [
          %{
            id: 1,
            type: "join",
            properties: properties
          }
        ],
        select:
          params_for(:data_view_queryable,
            type: "select",
            properties: params_for(:qp_select_params_for)
          )
      }

      assert {:ok, %DataView{} = data_view} = DataViews.create_data_view(valid_attrs)

      assert %{
               queryables: [
                 %{
                   properties: %{
                     join: %{
                       resource: %{
                         id: ^resource_id,
                         type: ^resource_type
                       },
                       clauses: [
                         %{
                           expressions: [
                             %{
                               shape: ^shape
                             }
                           ]
                         }
                       ]
                     }
                   }
                 }
               ]
             } = data_view
    end

    test "create_data_view/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = DataViews.create_data_view(@invalid_attrs)
    end

    test "create_data_view/1 validates duplicated queryable alias" do
      invalid_attrs =
        params_for(:data_view_params_for,
          queryables: [
            build(:data_view_queryable_params_for, alias: "repeated"),
            build(:data_view_queryable_params_for, alias: "repeated")
          ]
        )

      assert {:error, %Ecto.Changeset{errors: errors}} = DataViews.create_data_view(invalid_attrs)
      assert [{:queryables, {"invalid duplicated alias", []}}] = errors
    end

    test "create_data_view/1 ignores duplicated nil alias" do
      valid_attrs =
        params_for(:data_view_params_for,
          queryables: [
            build(:data_view_queryable_params_for, alias: nil),
            build(:data_view_queryable_params_for, alias: nil)
          ]
        )

      assert {:ok, %DataView{}} = DataViews.create_data_view(valid_attrs)
    end

    test "create_data_view/1 validates duplicated resources" do
      resource = build(:resource, id: 1, type: "data_view")

      invalid_attrs =
        params_for(:data_view_params_for,
          queryables: [
            valid_queryable_params_for("from", [alias: nil], resource: resource),
            valid_queryable_params_for("join", [alias: nil], resource: resource)
          ]
        )

      assert {:error, %Ecto.Changeset{errors: errors}} = DataViews.create_data_view(invalid_attrs)
      assert [{:queryables, {"invalid duplicated resources", []}}] = errors
    end

    test "create_data_view/1 validates duplicated resources with valid aliases" do
      resource = build(:resource, id: 1, type: "data_view")

      valid_attrs =
        params_for(:data_view_params_for,
          queryables: [
            valid_queryable_params_for("from", [alias: "alias1"], resource: resource),
            valid_queryable_params_for("join", [alias: "alias2"], resource: resource)
          ]
        )

      assert {:ok, %DataView{}} = DataViews.create_data_view(valid_attrs)
    end

    test "update_data_view/2 with valid data updates the data_view" do
      data_view = insert(:data_view)

      update_attrs = %{name: "updated name", description: "updated description"}

      assert {:ok, %DataView{} = data_view} = DataViews.update_data_view(data_view, update_attrs)

      assert data_view.name == "updated name"
      assert data_view.description == "updated description"
    end

    test "update_data_view/2 with valid data updates queryables" do
      data_view =
        insert(:data_view,
          queryables: [
            build(:data_view_queryable,
              type: "from",
              properties: build(:queryable_properties, from: build(:qp_from))
            )
          ]
        )

      properties = build(:qp_join_params_for)

      update_attrs = %{
        queryables: [
          params_for(:data_view_queryable,
            type: "join",
            properties: properties
          )
        ]
      }

      assert {:ok, %DataView{} = data_view} = DataViews.update_data_view(data_view, update_attrs)

      assert [
               %{
                 type: "join",
                 properties: %{
                   join: %{
                     clauses: [
                       %{
                         expressions: [
                           %{
                             shape: shape,
                             value: %{
                               constant: value,
                               field: nil,
                               function: nil,
                               param: nil
                             }
                           }
                         ]
                       }
                     ],
                     resource: resource,
                     type: "left"
                   }
                 }
               }
             ] = data_view.queryables

      assert %TdQx.DataViews.QueryableProperties.Join{
               clauses: [
                 %TdQx.Expressions.Clause{
                   expressions: [
                     %TdQx.Expressions.Expression{
                       shape: shape,
                       value: value
                     }
                   ]
                 }
               ],
               resource: resource,
               type: "left"
             } == properties
    end

    test "update_data_view/2 with valid data updates queryables properties" do
      data_view =
        insert(:data_view,
          queryables: [
            build(:data_view_queryable,
              type: "from",
              properties:
                build(:queryable_properties,
                  from: build(:qp_from, resource: build(:resource, id: 1, type: "data_view"))
                )
            )
          ]
        )

      properties = build(:qp_from, resource: build(:resource, id: 2, type: "data_structure"))

      update_attrs = %{
        queryables: [
          params_for(:data_view_queryable,
            type: "from",
            properties: properties
          )
        ]
      }

      assert {:ok, %DataView{} = data_view} = DataViews.update_data_view(data_view, update_attrs)

      assert [
               %{
                 type: "from",
                 properties: %{
                   from: result_properties
                 }
               }
             ] = data_view.queryables

      assert result_properties == properties
    end

    test "update_data_view/2 with invalid data returns error changeset" do
      %{id: id, name: name} = data_view = insert(:data_view)

      assert {:error, %Ecto.Changeset{}} = DataViews.update_data_view(data_view, @invalid_attrs)

      assert %{id: ^id, name: ^name} = DataViews.get_data_view!(id)
    end

    test "delete_data_view/1 deletes the data_view" do
      data_view = insert(:data_view)
      assert {:ok, %DataView{}} = DataViews.delete_data_view(data_view)
      assert_raise Ecto.NoResultsError, fn -> DataViews.get_data_view!(data_view.id) end
    end

    test "change_data_view/1 returns a data_view changeset" do
      data_view = insert(:data_view)
      assert %Ecto.Changeset{} = DataViews.change_data_view(data_view)
    end
  end
end
