defmodule LambdaEthereumConsensus.StateTransition.Accessors do
  @moduledoc """
  Functions accessing the current beacon state
  """
  alias LambdaEthereumConsensus.StateTransition.Misc
  alias SszTypes.BeaconState

  @doc """
  Return the current epoch.
  """
  @spec get_current_epoch(BeaconState.t()) :: SszTypes.epoch()
  def get_current_epoch(%BeaconState{slot: slot} = _state) do
    Misc.compute_epoch_at_slot(slot)
  end

  @doc """
  Return the randao mix at a recent epoch.
  """
  @spec get_randao_mix(BeaconState.t(), SszTypes.epoch()) :: SszTypes.bytes32()
  def get_randao_mix(%BeaconState{randao_mixes: randao_mixes}, epoch) do
    epochs_per_historical_vector = ChainSpec.get("EPOCHS_PER_HISTORICAL_VECTOR")
    Enum.fetch!(randao_mixes, rem(epoch, epochs_per_historical_vector))
  end

  @doc """
  Return the beacon proposer index at the current slot.
  """
  @spec get_beacon_proposer_index(BeaconState.t()) :: SszTypes.uint64()
  def get_beacon_proposer_index(state) do
    epoch = get_current_epoch(state)
    # seed = hash(get_seed(state, epoch, DOMAIN_BEACON_PROPOSER) + uint_to_bytes(state.slot))
    # indices = get_active_validator_indices(state, epoch)
    # return compute_proposer_index(state, indices, seed)
  end

  @doc """
  Return the seed at epoch.
  """
  @spec get_seed(BeaconState.t(), SszTypes.epoch(), SszTypes.domain_type()) :: SszTypes.bytes32()
  def get_seed(state, epoch, domain_type) do
    mix =
      get_randao_mix(
        state,
        epoch + ChainSpec.get("EPOCHS_PER_HISTORICAL_VECTOR") -
          ChainSpec.get("MIN_SEED_LOOKAHEAD") - 1
      )

    # TODO: Hash + add
    # domain_type + epoch + mix
  end
end
