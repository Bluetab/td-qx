defmodule TdQxWeb.ScoreController do
  use TdQxWeb, :controller

  alias Ecto.Changeset
  alias TdQx.QualityControls
  alias TdQx.QualityControls.QualityControl
  alias TdQx.QualityControlTransformer
  alias TdQx.Scores
  alias TdQx.Scores.Score
  alias TdQx.Search

  action_fallback(TdQxWeb.FallbackController)

  def search_with_pagination(conn, %{"quality_control_id" => quality_control_id} = params) do
    claims = conn.assigns[:current_resource]
    preload = [status: ["FAILED", "SUCCEEDED"]]

    with {:qc, %QualityControl{} = quality_control} <-
           {:qc, QualityControls.get_quality_control(quality_control_id)},
         :ok <- Bodyguard.permit(Scores, :index, claims, quality_control),
         {:ok, scores} <- Scores.search_scores(params, preload),
         {:last_execution_result, last_execution_result} <-
           QualityControls.get_quality_control_with_latest_result(quality_control) do
      render(conn, :index,
        search: %{scores: scores, last_execution_result: last_execution_result}
      )
    else
      {key, nil} when key in [:qc, :last_execution_result] ->
        {:error, :not_found}

      error ->
        error
    end
  end

  def show(conn, %{"id" => id}) do
    claims = conn.assigns[:current_resource]

    with {:score, %Score{} = score} <-
           {:score,
            Scores.get_score(id,
              preload: [:status, :events, quality_control_version: :quality_control]
            )},
         :ok <- Bodyguard.permit(Scores, :show, claims, score) do
      render(conn, :show, score: score)
    else
      {:score, _} -> {:error, :not_found}
      error -> error
    end
  end

  def fetch_pending(conn, params) do
    claims = conn.assigns[:current_resource]

    filter_params =
      Map.get(params, "filter_params", %{})

    params =
      params
      |> Map.delete("filter_params")
      |> Map.put("status", "PENDING")
      |> Map.put("preload", quality_control_version: :quality_control)

    with :ok <- Bodyguard.permit(Scores, :fetch_pending, claims),
         results <- maybe_do_search(filter_params, claims),
         params <- maybe_add_ids_to_params(params, results),
         {:ok, opts} <- cast_params(:fetch_pending, params) do
      scores = Scores.list_scores(opts)
      opts = Keyword.put(opts, :user_id, claims.user_id)
      Scores.update_scores_quality_control_properties(opts)
      Scores.insert_event_for_scores(scores, %{type: "QUEUED"}, user_id: claims.user_id)

      enriched_scores = QualityControlTransformer.enrich_scores_queries(scores)

      resources_lookup =
        enriched_scores
        |> Enum.flat_map(fn
          %{quality_control_version: %{queries: nil}} -> []
          %{quality_control_version: %{queries: queries}} -> queries
          _ -> []
        end)
        |> QualityControlTransformer.build_resources_lookup()

      render(conn, :fetch_pending,
        scores: enriched_scores,
        resources_lookup: resources_lookup
      )
    end
  end

  def success(conn, %{"score_id" => score_id} = params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(Scores, :success, claims),
         {:score, %Score{} = score} <- {:score, Scores.get_score(score_id)},
         {:ok, %{score: score}} <-
           Scores.updated_succeeded_score(score, params, user_id: claims.user_id) do
      render(conn, :show, score: score)
    else
      {:score, _} -> {:error, :not_found}
      error -> error
    end
  end

  def fail(conn, %{"score_id" => score_id} = params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(Scores, :fail, claims),
         {:score, %Score{} = score} <- {:score, Scores.get_score(score_id)},
         {:ok, %{score: score}} <-
           Scores.updated_failed_score(score, params, user_id: claims.user_id) do
      render(conn, :show, score: score)
    else
      {:score, _} -> {:error, :not_found}
      error -> error
    end
  end

  def delete(conn, %{"id" => id}) do
    claims = conn.assigns[:current_resource]

    with {:score,
          %Score{
            quality_control_version: %{quality_control: quality_control}
          } = score} <-
           {:score,
            Scores.get_score(
              id,
              preload: [:status, quality_control_version: :quality_control]
            )},
         {:valid_status, true} <-
           {:valid_status, score.status in ["PENDING", "SUCCEEDED", "FAILED"]},
         :ok <- Bodyguard.permit(Scores, :delete, claims, quality_control),
         {:ok, %Score{}} <- Scores.delete_score(score, user_id: claims.user_id) do
      send_resp(conn, :no_content, "")
    else
      {:score, _} -> {:error, :not_found}
      {:valid_status, _} -> {:error, :unprocessable_entity}
      error -> error
    end
  end

  defp maybe_do_search(%{} = filter_params, claims) when map_size(filter_params) !== 0 do
    %{results: results} = Search.search_score_groups(filter_params, claims)
    results
  end

  defp maybe_do_search(_filter_params, _claims), do: []

  defp maybe_add_ids_to_params(params, []), do: params

  defp maybe_add_ids_to_params(params, results) do
    group_ids = Enum.map(results, &Map.get(&1, "id"))
    Map.put(params, "group_ids", group_ids)
  end

  def cast_params(:fetch_pending, %{} = params) do
    types = %{
      sources: {:array, :integer},
      status: :string,
      preload: :any,
      group_ids: {:array, :integer}
    }

    {%{}, types}
    |> Changeset.cast(params, Map.keys(types))
    |> Changeset.update_change(:status, &String.upcase/1)
    |> case do
      %{valid?: true} = changeset ->
        {:ok,
         changeset
         |> Changeset.apply_changes()
         |> Keyword.new()}

      error_changeset ->
        {:error, error_changeset}
    end
  end
end
