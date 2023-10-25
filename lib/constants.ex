defmodule Constants do
  @moduledoc """
  Constants module with 0-arity functions.
  """

  @spec genesis_epoch() :: integer
  def genesis_epoch, do: 0

  @spec max_random_byte() :: integer
  def max_random_byte, do: 2 ** 8 - 1

  @spec timely_target_flag_index() :: integer
  def timely_target_flag_index, do: 1

  @spec far_future_epoch() :: integer
  def far_future_epoch, do: 2 ** 64 - 1
end
