defmodule PryIn.MetricValueStore do
  use GenServer
  require Logger
  alias PryIn.MetricValue

  @moduledoc false

  defstruct stored_metric_values: []

  def start_link() do
    GenServer.start_link(__MODULE__, %__MODULE__{}, name: __MODULE__)
  end

  def add_metric_value(label, value, start_time, opts) do
    GenServer.cast(__MODULE__, {:add_metric_value, label, value, start_time, opts})
  end

  def pop_metric_values do
    GenServer.call(__MODULE__, :pop_metric_values)
  end

  def init(args) do
    {:ok, args}
  end

  def handle_cast({:add_metric_value, label, value, start_time, opts}, state) do
    if length(state.stored_metric_values) >= max_tracked_metric_values_limit() do
      Logger.info("[PryIn] Dropping tracked metric value for #{label} because buffer is full.")
      {:noreply, state}
    else
      metric_value =
        MetricValue.new(
          label: label,
          value: value,
          start_time: start_time,
          context: normalize_metric_value_context(opts[:context])
        )

      {:noreply, %{state | stored_metric_values: [metric_value | state.stored_metric_values]}}
    end
  end

  def handle_call(:pop_metric_values, _from, state) do
    {:reply, state.stored_metric_values, %{state | stored_metric_values: []}}
  end

  defp normalize_metric_value_context(nil), do: []

  defp normalize_metric_value_context(context_map) do
    for {key, value} <- context_map, do: {to_string(key), to_string(value)}
  end

  defp max_tracked_metric_values_limit do
    Application.get_env(:pryin, :max_tracked_metric_values_for_interval, 10_000)
  end
end
