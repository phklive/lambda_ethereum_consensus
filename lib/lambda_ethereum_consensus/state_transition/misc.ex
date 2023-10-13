defmodule LambdaEthereumConsensus.StateTransition.Misc do
  @moduledoc """
  Misc functions
  """

  @doc """
  Returns the epoch number at slot.
  """
  @spec compute_epoch_at_slot(SszTypes.slot()) :: SszTypes.epoch()
  def compute_epoch_at_slot(slot) do
    slots_per_epoch = ChainSpec.get("SLOTS_PER_EPOCH")
    div(slot, slots_per_epoch)
  end

  # TODO: Implement uint to bytes
  # @doc """
  # Turns uint64 to bytes
  # """
  # @spec uint64_to_bytes(SszTypes.uint64()) :: SszTypes.bytes48
  # def uint64_to_bytes(uint64)
  #     when is_integer(uint64) and uint64 >= 0 and uint64 <= 18_446_744_073_709_551_615 do
  #   <<uint64::unsigned-big-integer-size(64)>>
  # end
end
