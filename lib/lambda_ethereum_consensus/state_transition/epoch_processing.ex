defmodule LambdaEthereumConsensus.StateTransition.EpochProcessing do
  @moduledoc """
  This module contains utility functions for handling epoch processing
  """

  alias LambdaEthereumConsensus.StateTransition.Accessors
  alias SszTypes.BeaconBlockHeader
  alias SszTypes.BeaconBlock
  alias SszTypes.BeaconState

  @spec process_eth1_data_reset(BeaconState.t()) :: {:ok, BeaconState.t()}
  def process_eth1_data_reset(state) do
    next_epoch = Accessors.get_current_epoch(state) + 1
    epochs_per_eth1_voting_period = ChainSpec.get("EPOCHS_PER_ETH1_VOTING_PERIOD")

    new_state =
      if rem(next_epoch, epochs_per_eth1_voting_period) == 0 do
        %BeaconState{state | eth1_data_votes: []}
      else
        state
      end

    {:ok, new_state}
  end

  @spec process_randao_mixes_reset(BeaconState.t()) :: {:ok, BeaconState.t()}
  def process_randao_mixes_reset(%BeaconState{randao_mixes: randao_mixes} = state) do
    current_epoch = Accessors.get_current_epoch(state)
    next_epoch = current_epoch + 1
    epochs_per_historical_vector = ChainSpec.get("EPOCHS_PER_HISTORICAL_VECTOR")
    random_mix = Accessors.get_randao_mix(state, current_epoch)
    index = rem(next_epoch, epochs_per_historical_vector)
    new_randao_mixes = List.replace_at(randao_mixes, index, random_mix)
    new_state = %BeaconState{state | randao_mixes: new_randao_mixes}
    {:ok, new_state}
  end

  @spec process_block_header(BeaconState.t(), BeaconBlock.t()) ::
          {:ok, BeaconState.t()} | {:error, String.t()}
  def process_block_header(state, block) do
    #   # Verify that the slots match
    #   assert block.slot == state.slot
    #   # Verify that the block is newer than latest block header
    #   assert block.slot > state.latest_block_header.slot
    #   # Verify that proposer index is the correct index
    #   assert block.proposer_index == get_beacon_proposer_index(state)
    #   # Verify that the parent matches
    #   assert block.parent_root == hash_tree_root(state.latest_block_header)
    #   # Cache current block as the new latest block
    #   state.latest_block_header = BeaconBlockHeader(
    #       slot=block.slot,
    #       proposer_index=block.proposer_index,
    #       parent_root=block.parent_root,
    #       state_root=Bytes32(),  # Overwritten in the next process_slot call
    #       body_root=hash_tree_root(block.body),
    #   )
    #
    #   # Verify proposer is not slashed
    #   proposer = state.validators[block.proposer_index]
    #   assert not proposer.slashed

    cond do
      # Verify that the slots match
      block.slot != state.slot ->
        {:error, "Block and State slots do not match."}

      # Verify that the block is newer than latest block header
      block.slot < state.latest_block_header.slot ->
        {:error, "Block is older than latest block header."}

      # Verify that proposer index is the correct index
      # TODO:
      # block.proposer_index != Accessors

      # Verify that the parent matches
      block.parent_root != Ssz.hash_tree_root(state.latest_block_header) ->
        {:error, "Parent does not match"}

      true ->
        # Cache current block as the new latest block
        %BeaconState{
          state
          | latest_block_header: %BeaconBlockHeader{
              slot: block.slot,
              proposer_index: block.proposer_index,
              parent_root: block.parent_root,
              # TODO: should be a default Bytes32
              state_root: 0,
              body_root: Ssz.hash_tree_root(block.body)
            }
        }
    end
  end
end
