defmodule LambdaEthereumConsensus.StateTransition.Misc do
  @moduledoc """
  Misc functions
  """
  alias SszTypes.BeaconState

  @doc """
  Returns the epoch number at slot.
  """
  @spec compute_epoch_at_slot(SszTypes.slot()) :: SszTypes.epoch()
  def compute_epoch_at_slot(slot) do
    slots_per_epoch = ChainSpec.get("SLOTS_PER_EPOCH")
    div(slot, slots_per_epoch)
  end

  @doc """
  Return from ``indices`` a random index sampled by effective balance.
  """
  @spec compute_proposer_index(
          BeaconState.t(),
          list(SszTypes.validator_index()),
          SszTypes.bytes32()
        ) :: SszTypes.validator_index()
  def compute_proposer_index(state, indices, seed) do
    if length(indices) < 0, do: {:error, "Indices length is smaller than 0"}
  end
end

# def compute_proposer_index(state: BeaconState, indices: Sequence[ValidatorIndex], seed: Bytes32) -> ValidatorIndex:
#     """
#     Return from ``indices`` a random index sampled by effective balance.
#     """
#     assert len(indices) > 0
#     MAX_RANDOM_BYTE = 2**8 - 1
#     i = uint64(0)
#     total = uint64(len(indices))
#     while True:
#         candidate_index = indices[compute_shuffled_index(i % total, total, seed)]
#         random_byte = hash(seed + uint_to_bytes(uint64(i // 32)))[i % 32]
#         effective_balance = state.validators[candidate_index].effective_balance
#         if effective_balance * MAX_RANDOM_BYTE >= MAX_EFFECTIVE_BALANCE * random_byte:
#             return candidate_index
#         i += 1
