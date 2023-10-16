defmodule LambdaEthereumConsensus.StateTransition.Operations do
  alias SszTypes.BeaconBlockHeader
  alias SszTypes.BeaconBlock
  alias SszTypes.BeaconState

  @spec process_block_header(BeaconState.t(), BeaconBlock.t()) ::
          {:ok, BeaconState.t()} | {:error, String.t()}
  def process_block_header(state, block) do
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
