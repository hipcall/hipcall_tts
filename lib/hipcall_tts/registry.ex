defmodule HipcallTts.Registry do
  @moduledoc """
  Provider registry for HipcallTts.

  This module maintains a registry of available TTS providers and provides
  functions to retrieve provider modules and delegate introspection calls.

  ## Providers

  The following providers are registered:
  - `:openai` - OpenAI TTS API
  - `:elevenlabs` - ElevenLabs TTS API
  - `:polly` - AWS Polly TTS service

  ## Examples

      # Get list of available providers
      HipcallTts.Registry.providers()
      # => [:openai, :elevenlabs, :polly]

      # Get provider module
      {:ok, module} = HipcallTts.Registry.get_provider(:openai)
      # => {:ok, HipcallTts.Providers.OpenAI}

      # Get models for a provider
      {:ok, models} = HipcallTts.Registry.models(:openai)
      # => {:ok, [%{id: "tts-1", name: "TTS-1", ...}, ...]}

      # Get voices for a provider
      {:ok, voices} = HipcallTts.Registry.voices(:openai)
      # => {:ok, [%{id: "alloy", name: "Alloy", ...}, ...]}
  """

  @providers [
    {:openai, HipcallTts.Providers.OpenAI},
    {:elevenlabs, HipcallTts.Providers.ElevenLabs},
    {:polly, HipcallTts.Providers.Polly}
  ]

  @doc """
  Returns a list of all registered provider names as atoms.

  ## Returns

  A list of provider atoms.

  ## Examples

      HipcallTts.Registry.providers()
      # => [:openai, :elevenlabs, :polly]
  """
  @spec providers() :: [atom()]
  def providers, do: Keyword.keys(@providers)

  @doc """
  Gets the module for a given provider name.

  ## Parameters

  - `name` - The provider name as an atom (e.g., `:openai`, `:elevenlabs`, `:polly`)

  ## Returns

  - `{:ok, module}` - If the provider is found
  - `{:error, message}` - If the provider is not found

  ## Examples

      {:ok, module} = HipcallTts.Registry.get_provider(:openai)
      # => {:ok, HipcallTts.Providers.OpenAI}

      {:error, message} = HipcallTts.Registry.get_provider(:invalid)
      # => {:error, "Unknown provider: invalid"}
  """
  @spec get_provider(atom()) :: {:ok, module()} | {:error, String.t()}
  def get_provider(name) do
    # Allow overriding provider modules (useful for testing and custom deployments).
    overrides = Application.get_env(:hipcall_tts, :provider_modules, [])

    case Keyword.fetch(overrides, name) do
      {:ok, module} ->
        {:ok, module}

      :error ->
        case Keyword.fetch(@providers, name) do
          {:ok, module} -> {:ok, module}
          :error -> {:error, "Unknown provider: #{name}"}
        end
    end
  end

  @doc """
  Returns a list of available models for the given provider.

  Delegates to the provider module's `models/0` function.

  ## Parameters

  - `provider` - The provider name as an atom

  ## Returns

  - `{:ok, [model]}` - List of model maps on success
  - `{:error, message}` - Error if the provider is invalid

  ## Examples

      {:ok, models} = HipcallTts.Registry.models(:openai)
      # => {:ok, [%{id: "tts-1", name: "TTS-1", ...}, ...]}

      {:error, message} = HipcallTts.Registry.models(:invalid)
      # => {:error, "Unknown provider: invalid"}
  """
  @spec models(atom()) :: {:ok, list()} | {:error, String.t()}
  def models(provider) do
    case get_provider(provider) do
      {:ok, module} -> {:ok, module.models()}
      {:error, message} -> {:error, message}
    end
  end

  @doc """
  Returns a list of available voices for the given provider.

  Delegates to the provider module's `voices/0` function.

  ## Parameters

  - `provider` - The provider name as an atom

  ## Returns

  - `{:ok, [voice]}` - List of voice maps on success
  - `{:error, message}` - Error if the provider is invalid

  ## Examples

      {:ok, voices} = HipcallTts.Registry.voices(:openai)
      # => {:ok, [%{id: "alloy", name: "Alloy", gender: :neutral, ...}, ...]}

      {:error, message} = HipcallTts.Registry.voices(:invalid)
      # => {:error, "Unknown provider: invalid"}
  """
  @spec voices(atom()) :: {:ok, list()} | {:error, String.t()}
  def voices(provider) do
    case get_provider(provider) do
      {:ok, module} -> {:ok, module.voices()}
      {:error, message} -> {:error, message}
    end
  end

  @doc """
  Returns a list of supported languages for the given provider.

  Delegates to the provider module's `languages/0` function.

  ## Parameters

  - `provider` - The provider name as an atom

  ## Returns

  - `{:ok, [language]}` - List of language maps on success
  - `{:error, message}` - Error if the provider is invalid

  ## Examples

      {:ok, languages} = HipcallTts.Registry.languages(:openai)
      # => {:ok, [%{code: "en", name: "English", ...}, ...]}

      {:error, message} = HipcallTts.Registry.languages(:invalid)
      # => {:error, "Unknown provider: invalid"}
  """
  @spec languages(atom()) :: {:ok, list()} | {:error, String.t()}
  def languages(provider) do
    case get_provider(provider) do
      {:ok, module} -> {:ok, module.languages()}
      {:error, message} -> {:error, message}
    end
  end

  @doc """
  Returns the capabilities of the given provider.

  Delegates to the provider module's `capabilities/0` function.

  ## Parameters

  - `provider` - The provider name as an atom

  ## Returns

  - `{:ok, capabilities}` - Capabilities map on success
  - `{:error, message}` - Error if the provider is invalid

  ## Examples

      {:ok, caps} = HipcallTts.Registry.capabilities(:openai)
      # => {:ok, %{streaming: true, formats: ["mp3", "wav"], ...}}

      {:error, message} = HipcallTts.Registry.capabilities(:invalid)
      # => {:error, "Unknown provider: invalid"}
  """
  @spec capabilities(atom()) :: {:ok, map()} | {:error, String.t()}
  def capabilities(provider) do
    case get_provider(provider) do
      {:ok, module} -> {:ok, module.capabilities()}
      {:error, message} -> {:error, message}
    end
  end
end
