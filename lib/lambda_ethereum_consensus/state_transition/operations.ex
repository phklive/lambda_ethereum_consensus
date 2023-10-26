defmodule LambdaEthereumConsensus.StateTransition.Operations do
  @moduledoc """
  State transition Operations related functions
  """

  alias LambdaEthereumConsensus.StateTransition.Accessors
  alias SszTypes.BeaconBlock
  alias SszTypes.BeaconState
  alias SszTypes.BeaconBlockHeader

  @spec process_block_header(BeaconState.t(), BeaconBlock.t()) ::
          {:ok, BeaconState.t()} | {:error, String.t()}
  def process_block_header(state, block) do
    proposer = Enum.at(state.validators, block.proposer_index)

    cond do
      # Verify that the slots match
      block.slot != state.slot ->
        {:error, "Block and State slots do not match"}

      # Verify that the block is newer than latest block header
      block.slot < state.latest_block_header.slot ->
        {:error, "Block is older than latest block header"}

      # Verify that proposer index is the correct index
      block.proposer_index != Accessors.get_beacon_proposer_index(state) ->
        {:error, "Invalid proposer index"}

      # IO.puts("Block proposer index:")
      # IO.inspect(block.proposer_index)
      # IO.puts("My function:")
      # IO.inspect(Accessors.get_beacon_proposer_index(state))

      # Verify that the parent matches
      {:ok, block.parent_root} != Ssz.hash_tree_root(state.latest_block_header) ->
        {:error, "Parent does not match"}

      # Verify proposer is not slashed
      proposer.slashed ->
        {:error, "Proposer has been slashed"}

      true ->
        # Cache current block as the new latest block
        with {:ok, root} <- Ssz.hash_tree_root(block.body) do
          %BeaconState{
            state
            | latest_block_header: %BeaconBlockHeader{
                slot: block.slot,
                proposer_index: block.proposer_index,
                parent_root: block.parent_root,
                state_root: <<0::256>>,
                body_root: root
              }
          }
        end
    end
  end
end
