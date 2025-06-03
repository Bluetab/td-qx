defmodule TdQxWeb.FlopErrorsJSON do
  @doc """
  Renders changeset errors.
  """

  def error(%{changeset: %Flop.Meta{errors: errors}}) do
    translated_errors = Enum.map(errors, fn elm -> translate_error(elm) end)

    %{errors: translated_errors}
  end

  defp translate_error({key, error}) do
    detail =
      error
      |> hd()
      |> elem(0)

    %{field: key, error: detail}
  end
end
