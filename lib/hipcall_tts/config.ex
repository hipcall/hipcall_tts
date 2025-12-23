defmodule HipcallTts.Config do
  @moduledoc """
  Configuration helper module for HipcallTts.

  This module provides functions to read and resolve configuration values
  from application environment, with support for:
  - Reading from application env
  - Runtime overrides
  - System environment variable resolution via `{:system, "ENV_VAR"}` tuples
  - Graceful handling of missing configuration

  ## Examples

      # In config/config.exs:
      config :hipcall_tts, :providers,
        openai: [
          api_key: {:system, "OPENAI_API_KEY"},
          base_url: "https://api.openai.com"
        ]

      # Usage:
      config = HipcallTts.Config.get_provider_config(:openai)
      # => [api_key: "actual-key-value", base_url: "https://api.openai.com"]

      # With runtime overrides:
      config = HipcallTts.Config.get_provider_config(:openai, api_key: "override-key")
      # => [api_key: "override-key", base_url: "https://api.openai.com"]
  """

  @doc """
  Gets the configuration for a specific provider.

  Reads the provider configuration from application environment, resolves
  system environment variables, and merges with any runtime overrides.

  ## Parameters

  - `provider` - The atom identifier for the provider (e.g., `:openai`, `:aws_polly`)
  - `opts` - Optional keyword list of runtime overrides that will be merged
    into the configuration (default: `[]`)

  ## Returns

  A keyword list containing the resolved provider configuration.

  ## Examples

      # Basic usage
      config = HipcallTts.Config.get_provider_config(:openai)

      # With runtime overrides
      config = HipcallTts.Config.get_provider_config(:openai, api_key: "custom-key")

      # Missing provider returns empty list
      config = HipcallTts.Config.get_provider_config(:nonexistent)
      # => []
  """
  def get_provider_config(provider, opts \\ []) do
    app_config = Application.get_env(:hipcall_tts, :providers, [])
    provider_config = Keyword.get(app_config, provider, [])

    provider_config
    |> resolve_system_vars()
    |> Keyword.merge(opts)
  end

  @doc """
  Resolves system environment variables in a configuration keyword list.

  Recursively processes the configuration and replaces `{:system, "ENV_VAR"}`
  tuples with the actual environment variable value. If the environment
  variable is not set, it raises an error.

  Also handles nested keyword lists and maps.

  ## Parameters

  - `config` - A keyword list or map containing configuration values

  ## Returns

  A keyword list or map with all `{:system, "ENV_VAR"}` tuples resolved
  to their actual values.

  ## Examples

      config = [api_key: {:system, "API_KEY"}, timeout: 5000]
      resolved = HipcallTts.Config.resolve_system_vars(config)
      # => [api_key: "actual-env-value", timeout: 5000]

      # Handles nested structures
      config = [
        provider: [
          api_key: {:system, "API_KEY"},
          options: %{base_url: {:system, "BASE_URL"}}
        ]
      ]
      resolved = HipcallTts.Config.resolve_system_vars(config)
  """
  def resolve_system_vars(config) when is_list(config) do
    Enum.map(config, fn
      {key, {:system, env_var}} ->
        {key, resolve_env_var(env_var)}

      {key, value} when is_list(value) ->
        {key, resolve_system_vars(value)}

      {key, value} when is_map(value) ->
        {key, resolve_system_vars(value)}

      {key, value} ->
        {key, value}
    end)
  end

  def resolve_system_vars(config) when is_map(config) do
    Enum.into(config, %{}, fn
      {key, {:system, env_var}} ->
        {key, resolve_env_var(env_var)}

      {key, value} when is_list(value) ->
        {key, resolve_system_vars(value)}

      {key, value} when is_map(value) ->
        {key, resolve_system_vars(value)}

      {key, value} ->
        {key, value}
    end)
  end

  def resolve_system_vars(value), do: value

  @doc false
  defp resolve_env_var(env_var) do
    case System.get_env(env_var) do
      nil ->
        raise ArgumentError,
              "Environment variable #{inspect(env_var)} is not set. " <>
                "Please set it or provide a default value in your configuration."

      value ->
        value
    end
  end
end
