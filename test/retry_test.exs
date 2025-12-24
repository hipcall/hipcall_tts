defmodule HipcallTts.RetryTest do
  use ExUnit.Case, async: true

  alias HipcallTts.Retry

  test "returns ok immediately" do
    assert {:ok, 1} = Retry.with_retry(fn -> {:ok, 1} end, max_attempts: 3, initial_delay: 0)
  end

  test "retries until success" do
    parent = self()

    fun = fn ->
      send(parent, :called)

      receive do
        :fail -> {:error, %{code: :network_error, message: "nope"}}
        :ok -> {:ok, :done}
      after
        0 -> {:error, %{code: :network_error, message: "nope"}}
      end
    end

    # First two calls fail, third succeeds
    send(self(), :fail)
    send(self(), :fail)
    send(self(), :ok)

    assert {:ok, :done} =
             Retry.with_retry(fun,
               max_attempts: 3,
               initial_delay: 0,
               max_delay: 0,
               backoff_factor: 2.0
             )

    assert_received :called
  end

  test "stops after max attempts" do
    fun = fn -> {:error, %{code: :network_error, message: "nope"}} end

    assert {:error, %{code: :network_error}} =
             Retry.with_retry(fun, max_attempts: 2, initial_delay: 0, max_delay: 0)
  end

  test "respects retryable_errors filter" do
    fun = fn -> {:error, %{code: :http_error, message: "nope"}} end

    assert {:error, %{code: :http_error}} =
             Retry.with_retry(fun,
               max_attempts: 3,
               initial_delay: 0,
               max_delay: 0,
               # http_error is not retryable now
               retryable_errors: [:network_error]
             )
  end

  test "returns invalid_return error when retry fun returns unexpected value" do
    assert {:error, err} =
             Retry.with_retry(fn -> :ok end, max_attempts: 1, initial_delay: 0, max_delay: 0)

    assert err.code == :invalid_return
  end

  test "uses Retry-After header branch (no sleep when max_delay is 0)" do
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    fun = fn ->
      n = Agent.get_and_update(counter, fn n -> {n, n + 1} end)

      if n == 0 do
        {:error,
         %{
           code: :http_error,
           status: 429,
           message: "rate limited",
           headers: [{"Retry-After", "2"}]
         }}
      else
        {:ok, :done}
      end
    end

    assert {:ok, :done} =
             Retry.with_retry(fun,
               max_attempts: 1,
               initial_delay: 999,
               max_delay: 0,
               backoff_factor: 2.0
             )
  end

  test "safe_error handles non-binary/non-map errors on retry attempts" do
    fun = fn -> {:error, :timeout} end

    assert {:error, :timeout} =
             Retry.with_retry(fun,
               max_attempts: 1,
               initial_delay: 0,
               max_delay: 0
             )
  end
end
