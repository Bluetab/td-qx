defmodule TdQx.DataViews.QueryableProperties.Where do
  @moduledoc """
  Ecto Schema module for DataViews QueryablesProperties Where
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdQx.Expressions.Clause

  @primary_key false
  embedded_schema do
    embeds_many(:clauses, Clause, on_replace: :delete)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [])
    |> cast_embed(:clauses, with: &Clause.changeset/2, required: true)
  end

  def to_json(%__MODULE__{clauses: clauses}) do
    %{clauses: Clause.to_json(clauses)}
  end

  def to_json(_), do: nil

  def unfold(%__MODULE__{clauses: clauses}) do
    %{__type__: "where", clauses: Clause.unfold(clauses)}
  end
end
