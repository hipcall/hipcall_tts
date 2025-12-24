defmodule HipcallTts.ConfigTest do
  use ExUnit.Case, async: true

  alias HipcallTts.Config

  test "resolve_system_vars resolves nested keyword lists and maps" do
    env_key = "HIPCALL_TTS_TEST_ENV_" <> Integer.to_string(System.unique_integer([:positive]))
    System.put_env(env_key, "secret")
    on_exit(fn -> System.delete_env(env_key) end)

    input = [
      api_key: {:system, env_key},
      nested: [
        inner: %{token: {:system, env_key}}
      ]
    ]

    resolved = Config.resolve_system_vars(input)

    assert Keyword.get(resolved, :api_key) == "secret"
    assert resolved[:nested][:inner][:token] == "secret"
  end

  test "resolve_system_vars raises when env var missing" do
    env_key = "HIPCALL_TTS_TEST_MISSING_" <> Integer.to_string(System.unique_integer([:positive]))
    System.delete_env(env_key)

    assert_raise ArgumentError, fn ->
      Config.resolve_system_vars(api_key: {:system, env_key})
    end
  end

  test "get_provider_config resolves vars and merges overrides" do
    env_key = "HIPCALL_TTS_TEST_ENV_" <> Integer.to_string(System.unique_integer([:positive]))
    System.put_env(env_key, "resolved")
    on_exit(fn -> System.delete_env(env_key) end)

    original = Application.get_env(:hipcall_tts, :providers)

    Application.put_env(
      :hipcall_tts,
      :providers,
      Keyword.merge(original || [],
        testprov: [token: {:system, env_key}, timeout: 100]
      )
    )

    on_exit(fn ->
      if original do
        Application.put_env(:hipcall_tts, :providers, original)
      else
        Application.delete_env(:hipcall_tts, :providers)
      end
    end)

    cfg = Config.get_provider_config(:testprov, timeout: 200)
    assert cfg[:token] == "resolved"
    assert cfg[:timeout] == 200

    assert Config.get_provider_config(:nonexistent) == []
  end

  test "resolve_system_vars supports top-level map and passthrough values" do
    env_key = "HIPCALL_TTS_TEST_ENV_" <> Integer.to_string(System.unique_integer([:positive]))
    System.put_env(env_key, "ok")
    on_exit(fn -> System.delete_env(env_key) end)

    input = %{
      token: {:system, env_key},
      nested: [a: {:system, env_key}],
      keep: 123
    }

    resolved = Config.resolve_system_vars(input)
    assert resolved.token == "ok"
    assert resolved.nested[:a] == "ok"
    assert resolved.keep == 123

    assert Config.resolve_system_vars(123) == 123
  end
end
