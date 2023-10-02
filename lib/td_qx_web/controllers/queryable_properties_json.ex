defmodule TdQxWeb.QueryablePropertiesJSON do
  alias TdQx.DataViews.Queryable
  alias TdQx.DataViews.QueryableProperties
  alias TdQxWeb.QueryablePropertiesFromJSON
  alias TdQxWeb.QueryablePropertiesGroupByJSON
  alias TdQxWeb.QueryablePropertiesJoinJSON
  alias TdQxWeb.QueryablePropertiesSelectJSON
  alias TdQxWeb.QueryablePropertiesWhereJSON

  def embed_one(%Queryable{properties: %QueryableProperties{} = properties, type: type}),
    do: data(type, properties)

  def embed_one(_), do: nil

  defp data("from", %QueryableProperties{} = properties),
    do: QueryablePropertiesFromJSON.embed_one(properties)

  defp data("group_by", %QueryableProperties{} = properties),
    do: QueryablePropertiesGroupByJSON.embed_one(properties)

  defp data("join", %QueryableProperties{} = properties),
    do: QueryablePropertiesJoinJSON.embed_one(properties)

  defp data("select", %QueryableProperties{} = properties),
    do: QueryablePropertiesSelectJSON.embed_one(properties)

  defp data("where", %QueryableProperties{} = properties),
    do: QueryablePropertiesWhereJSON.embed_one(properties)

  defp data(_, %QueryableProperties{}), do: nil
end

defmodule TdQxWeb.ResourceJSON do
  alias TdQx.DataViews.Resource

  def embed_one(%{resource: %Resource{} = resource}), do: data(resource)
  def embed_one(%Resource{} = resource), do: data(resource)

  def embed_one(_), do: []

  def data(%Resource{} = resource) do
    %{
      id: resource.id,
      type: resource.type
    }
    |> with_embedded(resource)
  end

  defp with_embedded(json, %{embedded: %{} = embedded}), do: Map.put(json, :embedded, embedded)
  defp with_embedded(json, _), do: json
end

defmodule TdQxWeb.QueryablePropertiesFromJSON do
  alias TdQx.DataViews.QueryableProperties
  alias TdQx.DataViews.QueryableProperties.From
  alias TdQxWeb.ResourceJSON

  def embed_one(%QueryableProperties{from: %From{} = from}), do: data(from)
  def embed_one(_), do: nil

  defp data(%From{} = from) do
    %{
      resource: ResourceJSON.embed_one(from)
    }
  end
end

defmodule TdQxWeb.QueryablePropertiesJoinJSON do
  alias TdQx.DataViews.QueryableProperties
  alias TdQx.DataViews.QueryableProperties.Join
  alias TdQxWeb.ClauseJSON
  alias TdQxWeb.ResourceJSON

  def embed_one(%QueryableProperties{join: %Join{} = join}), do: data(join)
  def embed_one(_), do: nil

  defp data(%Join{} = join) do
    %{
      resource: ResourceJSON.embed_one(join),
      clauses: ClauseJSON.embed_many(join),
      type: join.type
    }
  end
end

defmodule TdQxWeb.QueryablePropertiesSelectFieldJSON do
  alias TdQx.DataViews.QueryableProperties
  alias TdQx.DataViews.QueryableProperties.Select
  alias TdQx.DataViews.QueryableProperties.SelectField
  alias TdQxWeb.ExpressionJSON

  def embed_many(%Select{fields: [%SelectField{} | _] = fields}),
    do: for(field <- fields, do: data(field))

  def embed_many([%SelectField{} | _] = fields),
    do: for(field <- fields, do: data(field))

  def embed_many(_), do: []

  defp data(%SelectField{} = field) do
    %{
      id: field.id,
      alias: field.alias,
      expression: ExpressionJSON.embed_one(field.expression)
    }
  end
end

defmodule TdQxWeb.QueryablePropertiesSelectJSON do
  alias TdQx.DataViews.QueryableProperties
  alias TdQx.DataViews.QueryableProperties.Select
  alias TdQxWeb.QueryablePropertiesSelectFieldJSON

  def embed_one(%QueryableProperties{select: %Select{} = select}), do: data(select)
  def embed_one(_), do: nil

  defp data(%Select{} = select) do
    %{
      fields: QueryablePropertiesSelectFieldJSON.embed_many(select)
    }
  end
end

defmodule TdQxWeb.QueryablePropertiesGroupByJSON do
  alias TdQx.DataViews.QueryableProperties
  alias TdQx.DataViews.QueryableProperties.GroupBy
  alias TdQxWeb.QueryablePropertiesSelectFieldJSON

  def embed_one(%QueryableProperties{group_by: %GroupBy{} = group_by}), do: data(group_by)
  def embed_one(_), do: nil

  defp data(%GroupBy{} = group_by) do
    %{
      group_fields: QueryablePropertiesSelectFieldJSON.embed_many(group_by.group_fields),
      aggregate_fields: QueryablePropertiesSelectFieldJSON.embed_many(group_by.aggregate_fields)
    }
  end
end

defmodule TdQxWeb.QueryablePropertiesWhereJSON do
  alias TdQx.DataViews.QueryableProperties
  alias TdQx.DataViews.QueryableProperties.Where
  alias TdQxWeb.ClauseJSON

  def embed_one(%QueryableProperties{where: %Where{} = where}), do: data(where)
  def embed_one(_), do: nil

  defp data(%Where{} = where) do
    %{
      clauses: ClauseJSON.embed_many(where)
    }
  end
end
