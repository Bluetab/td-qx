defmodule TdQxWeb.ResultCriteriaJSON do
  alias TdQx.QualityControls.QualityControlVersion
  alias TdQx.QualityControls.ResultCriteria
  alias TdQxWeb.ResultCriteriaDeviationJSON
  alias TdQxWeb.ResultCriteriaErrorsNumberJSON
  alias TdQxWeb.ResultCriteriaPercentageJSON

  def embed_one(%QualityControlVersion{
        result_criteria: %ResultCriteria{} = result_criteria,
        result_type: result_type
      }),
      do: data(result_type, result_criteria)

  def embed_one(_), do: nil

  defp data("deviation", %ResultCriteria{} = result_criteria),
    do: ResultCriteriaDeviationJSON.embed_one(result_criteria)

  defp data("errors_number", %ResultCriteria{} = result_criteria),
    do: ResultCriteriaErrorsNumberJSON.embed_one(result_criteria)

  defp data("percentage", %ResultCriteria{} = result_criteria),
    do: ResultCriteriaPercentageJSON.embed_one(result_criteria)

  defp data(_, %ResultCriteria{}), do: nil
end

defmodule TdQxWeb.ResultCriteriaDeviationJSON do
  alias TdQx.QualityControls.ResultCriteria
  alias TdQx.QualityControls.ResultCriterias.Deviation

  def embed_one(%ResultCriteria{deviation: %Deviation{} = deviation}), do: data(deviation)
  def embed_one(_), do: nil

  defp data(%Deviation{} = deviation) do
    %{
      goal: deviation.goal,
      maximum: deviation.maximum
    }
  end
end

defmodule TdQxWeb.ResultCriteriaErrorsNumberJSON do
  alias TdQx.QualityControls.ResultCriteria
  alias TdQx.QualityControls.ResultCriterias.ErrorsNumber

  def embed_one(%ResultCriteria{errors_number: %ErrorsNumber{} = errors_number}),
    do: data(errors_number)

  def embed_one(_), do: nil

  defp data(%ErrorsNumber{} = errors_number) do
    %{
      goal: errors_number.goal,
      maximum: errors_number.maximum
    }
  end
end

defmodule TdQxWeb.ResultCriteriaPercentageJSON do
  alias TdQx.QualityControls.ResultCriteria
  alias TdQx.QualityControls.ResultCriterias.Percentage

  def embed_one(%ResultCriteria{percentage: %Percentage{} = percentage}), do: data(percentage)
  def embed_one(_), do: nil

  defp data(%Percentage{} = percentage) do
    %{
      goal: percentage.goal,
      minimum: percentage.minimum
    }
  end
end
