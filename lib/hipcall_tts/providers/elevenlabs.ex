defmodule HipcallTts.Providers.ElevenLabs do
  @behaviour HipcallTts.Provider

  @moduledoc """
  ElevenLabs provider.

  This provider is **not implemented yet**.

  """

  @capabilities %{
    # ElevenLabs supports streaming, but this provider is not implemented yet.
    streaming: false,
    formats: ["mp3"],
    sample_rates: [],
    max_text_length: 5000
  }

  @impl HipcallTts.Provider
  @spec generate(HipcallTts.Provider.params()) ::
          {:ok, HipcallTts.Provider.result()} | {:error, any()}
  def generate(_params), do: not_implemented()

  @impl HipcallTts.Provider
  @spec stream(HipcallTts.Provider.params()) :: {:ok, Enumerable.t()} | {:error, any()}
  def stream(_params), do: not_implemented()

  @impl HipcallTts.Provider
  @spec validate_params(HipcallTts.Provider.params()) :: :ok | {:error, String.t()}
  def validate_params(_params), do: not_implemented()

  @impl HipcallTts.Provider
  @spec models() :: [HipcallTts.Provider.model()]
  def models, do: []

  @impl HipcallTts.Provider
  @spec voices() :: [HipcallTts.Provider.voice()]
  def voices, do: []

  @impl HipcallTts.Provider
  @spec languages() :: [HipcallTts.Provider.language()]
  def languages, do: []

  @impl HipcallTts.Provider
  @spec capabilities() :: HipcallTts.Provider.capabilities()
  def capabilities, do: @capabilities

  defp not_implemented do
    {:error,
     %{
       code: :not_implemented,
       message: "ElevenLabs provider is not implemented yet",
       provider: :elevenlabs
     }}
  end
end
