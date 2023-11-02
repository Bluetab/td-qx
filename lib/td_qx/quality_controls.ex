defmodule TdQx.QualityControls do
  @moduledoc """
  The QualityControls context.
  """

  import Ecto.Query, warn: false
  alias TdCache.TaxonomyCache
  alias TdQx.DataViews
  alias TdQx.Repo

  alias TdQx.QualityControls.QualityControl
  alias TdQx.QualityControls.QualityControlVersion

  defdelegate authorize(action, user, params), to: __MODULE__.Policy

  @doc """
  Returns the list of quality_controls.

  ## Examples

      iex> list_quality_controls()
      [%QualityControl{}, ...]

  """
  def list_quality_controls do
    QualityControl
    |> preload(:published_version)
    |> Repo.all()
  end

  def quality_control_latest_versions_query do
    latest_version_query =
      from v in QualityControlVersion,
        where: parent_as(:quality_control).id == v.quality_control_id,
        order_by: [desc: :version],
        limit: 1

    from c in QualityControl,
      as: :quality_control,
      inner_lateral_join: v in subquery(latest_version_query),
      on: true,
      select_merge: %{latest_version: v}
  end

  def list_quality_control_latest_versions do
    quality_control_latest_versions_query()
    |> Repo.all()
  end

  @doc """
  Gets a single quality_control.

  Raises `Ecto.NoResultsError` if the Quality control does not exist.

  ## Examples

      iex> get_quality_control!(123)
      %QualityControl{}

      iex> get_quality_control!(456)
      ** (Ecto.NoResultsError)

  """
  def get_quality_control!(id, opts \\ []),
    do:
      opts
      |> Enum.reduce(QualityControl, fn
        {:preload, value}, query -> preload(query, ^value)
        _, query -> query
      end)
      |> where(id: ^id)
      |> join(:left, [q], v in subquery(latest_version_query(id)), on: true)
      |> select_merge([q, v], %{latest_version: v})
      |> Repo.one!()
      |> enrich(Keyword.get(opts, :enrich, []))

  def latest_version_query(id) do
    QualityControlVersion
    |> where([q], q.quality_control_id == ^id)
    |> order_by(desc: :version)
    |> limit(1)
  end

  defp enrich(%QualityControl{} = qc, enrich_opts),
    do: Enum.reduce(enrich_opts, qc, &enrich_step/2)

  defp enrich(error, _), do: error

  defp enrich_step(:domains, %{domain_ids: domain_ids} = quality_control),
    do:
      domain_ids
      |> Enum.map(&TaxonomyCache.get_domain/1)
      |> then(&Map.put(quality_control, :domains, &1))

  defp enrich_step(
         :resource,
         %{latest_version: %{resource: resource}} = quality_control
       ),
       do:
         resource
         |> DataViews.enrich_resource()
         |> then(fn resource ->
           Map.update!(
             quality_control,
             :latest_version,
             &Map.update!(&1, :resource, fn _ -> resource end)
           )
         end)

  defp enrich_step(_, quality_control), do: quality_control

  @doc """
  Creates a quality_control.

  ## Examples

      iex> create_quality_control(%{field: value})
      {:ok, %QualityControl{}}

      iex> create_quality_control(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_quality_control(attrs \\ %{}) do
    %QualityControl{}
    |> QualityControl.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a quality_control.

  ## Examples

      iex> update_quality_control(quality_control, %{field: new_value})
      {:ok, %QualityControl{}}

      iex> update_quality_control(quality_control, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_quality_control(%QualityControl{} = quality_control, attrs) do
    quality_control
    |> QualityControl.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a quality_control.

  ## Examples

      iex> delete_quality_control(quality_control)
      {:ok, %QualityControl{}}

      iex> delete_quality_control(quality_control)
      {:error, %Ecto.Changeset{}}

  """
  def delete_quality_control(%QualityControl{} = quality_control) do
    Repo.delete(quality_control)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking quality_control changes.

  ## Examples

      iex> change_quality_control(quality_control)
      %Ecto.Changeset{data: %QualityControl{}}

  """
  def change_quality_control(%QualityControl{} = quality_control, attrs \\ %{}) do
    QualityControl.changeset(quality_control, attrs)
  end

  @doc """
  Returns the list of quality_control_versions.

  ## Examples

      iex> list_quality_control_versions()
      [%QualityControlVersion{}, ...]

  """
  def list_quality_control_versions(quality_control_id) do
    QualityControlVersion
    |> where([v], v.quality_control_id == ^quality_control_id)
    |> preload(:quality_control)
    |> Repo.all()
  end

  @doc """
  Gets a single quality_control_version.

  Raises `Ecto.NoResultsError` if the Quality control version does not exist.

  ## Examples

      iex> get_quality_control_version!(123)
      %QualityControlVersion{}

      iex> get_quality_control_version!(456)
      ** (Ecto.NoResultsError)

  """
  def get_quality_control_version!(id), do: Repo.get!(QualityControlVersion, id)

  @doc """
  Creates a quality_control_version.

  ## Examples

      iex> create_quality_control_version(%QualityControl{} = quality_control, %{field: value}, version)
      {:ok, %QualityControlVersion{}}

      iex> create_quality_control_version(nil, %{field: bad_value}, nil)
      {:error, %Ecto.Changeset{}}

  """

  def create_quality_control_version(
        %QualityControl{} = quality_control,
        attrs,
        version \\ 1
      ) do
    quality_control
    |> QualityControlVersion.create_changeset(attrs, version)
    |> Repo.insert()
  end

  @doc """
  Deletes a quality_control_version.

  ## Examples

      iex> delete_quality_control_version(quality_control_version)
      {:ok, %QualityControlVersion{}}

      iex> delete_quality_control_version(quality_control_version)
      {:error, %Ecto.Changeset{}}

  """
  def delete_quality_control_version(%QualityControlVersion{} = quality_control_version) do
    Repo.delete(quality_control_version)
  end

  def count_unique_name(name, quality_control_id) do
    QualityControlVersion
    |> where(
      [v],
      v.name == ^name and v.quality_control_id != ^quality_control_id and
        v.status not in ["deprecated", "versioned"]
    )
    |> select([v], count(v.id))
    |> Repo.one!()
  end
end
