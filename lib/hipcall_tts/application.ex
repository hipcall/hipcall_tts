defmodule HipcallTts.Application do
  use Application

  @spec start(:normal | :takeover | :failover, any()) :: {:ok, pid()} | {:error, any()}
  def start(_type, _args) do
    children = [
      {Finch,
       name: HipcallTtsFinch,
       pools: %{
         default: [size: 50, count: 1]
       }}
    ]

    opts = [strategy: :one_for_one, name: HipcallTts.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
