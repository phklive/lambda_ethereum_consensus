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

    max_random_byte = :math.pow(2, 8) - 1
    i = 0
    total = length(indices)
    candidate_index = Enum.at(indices)
  end

  @doc """
  Return the shuffled index corresponding to ``seed`` (and ``index_count``).
  """
  @spec compute_shuffled_index(SszTypes.uint64(), SszTypes.uint64(), SszTypes.bytes32()) ::
          SszTypes.uint64()
  def compute_shuffled_index(index, index_count, seed) do
    unless index < index_count, do: {:error, "The index is greater than the index_count"}

    Enum.reduce_while(0..(ChainSpec.get("SHUFFLE_ROUND_COUNT") - 1), index, fn current_round,
                                                                               index_count ->
      pivot =
        :crypto.hash(:sha256, seed <> uint_to_bytes(<<current_round::8>>))
        |> bytes_to_uint64()
        |> rem(index_count)

      flip = (pivot + index_count - index) |> rem(index_count)

      position = max(index, flip)

      source =
        :crypto.hash(
          :sha256,
          seed <> uint_to_bytes(current_round) <> uint_to_bytes(div(position, 256))
        )
    end)
  end

  @doc """
  uint_to_bytes is a function for serializing the uint type object to bytes in ENDIANNESS-endian.
  The expected length of the output is the byte-length of the uint type.
  """
  @spec uint_to_bytes(SszTypes.uint64()) :: SszTypes.bytes32()
  def uint_to_bytes(n) do
    :binary.encode_unsigned(n, :little)
  end

  @doc """
  Return the integer deserialization of ``data`` interpreted as ``ENDIANNESS``-endian.
  """
  @spec bytes_to_uint64(SszTypes.bytes32()) :: SszTypes.uint64()
  def bytes_to_uint64(data) do
    :binary.decode_unsigned(data, :little)
  end
end
