defmodule LambdaEthereumConsensus.StateTransition.Operations do
  @moduledoc """
  This module contains functions for handling state transition
  """

  alias LambdaEthereumConsensus.StateTransition.Accessors
  alias LambdaEthereumConsensus.Engine
  alias LambdaEthereumConsensus.StateTransition.Misc
  alias LambdaEthereumConsensus.StateTransition.Mutators
  alias LambdaEthereumConsensus.StateTransition.Predicates
  alias SszTypes
  alias SszTypes.Attestation
  alias SszTypes.BeaconState
  alias SszTypes.ExecutionPayload
  alias SszTypes.Validator
  alias SszTypes.Withdrawal

  @doc """
  State transition function managing the processing & validation of the `ExecutionPayload`
  """
  @spec process_execution_payload(BeaconState.t(), ExecutionPayload.t(), boolean()) ::
          {:ok, BeaconState.t()} | {:error, String.t()}

  def process_execution_payload(_state, _payload, false) do
    {:error, "Invalid execution payload"}
  end

  def process_execution_payload(state, payload, _execution_valid) do
    cond do
      # Verify consistency of the parent hash with respect to the previous execution payload header
      SszTypes.BeaconState.is_merge_transition_complete(state) and
          payload.parent_hash != state.latest_execution_payload_header.block_hash ->
        {:error, "Inconsistency in parent hash"}

      # Verify prev_randao
      payload.prev_randao != Accessors.get_randao_mix(state, Accessors.get_current_epoch(state)) ->
        {:error, "Prev_randao verification failed"}

      # Verify timestamp
      payload.timestamp != Misc.compute_timestamp_at_slot(state, state.slot) ->
        {:error, "Timestamp verification failed"}

      # Verify the execution payload is valid if not mocked
      Engine.Execution.verify_and_notify_new_payload(payload) != {:ok, true} ->
        {:error, "Invalid execution payload"}

      # Cache execution payload header
      true ->
        with {:ok, transactions_root} <-
               Ssz.hash_list_tree_root_typed(
                 payload.transactions,
                 ChainSpec.get("MAX_TRANSACTIONS_PER_PAYLOAD"),
                 SszTypes.Transaction
               ),
             {:ok, withdrawals_root} <-
               Ssz.hash_list_tree_root(
                 payload.withdrawals,
                 ChainSpec.get("MAX_WITHDRAWALS_PER_PAYLOAD")
               ) do
          {:ok,
           %BeaconState{
             state
             | latest_execution_payload_header: %SszTypes.ExecutionPayloadHeader{
                 parent_hash: payload.parent_hash,
                 fee_recipient: payload.fee_recipient,
                 state_root: payload.state_root,
                 receipts_root: payload.receipts_root,
                 logs_bloom: payload.logs_bloom,
                 prev_randao: payload.prev_randao,
                 block_number: payload.block_number,
                 gas_limit: payload.gas_limit,
                 gas_used: payload.gas_used,
                 timestamp: payload.timestamp,
                 extra_data: payload.extra_data,
                 base_fee_per_gas: payload.base_fee_per_gas,
                 block_hash: payload.block_hash,
                 transactions_root: transactions_root,
                 withdrawals_root: withdrawals_root
               }
           }}
        end
    end
  end

  @doc """
  Apply withdrawals to the state.
  """
  @spec process_withdrawals(BeaconState.t(), ExecutionPayload.t()) ::
          {:ok, BeaconState.t()} | {:error, String.t()}
  def process_withdrawals(
        %BeaconState{
          validators: validators
        } = state,
        %ExecutionPayload{withdrawals: withdrawals}
      ) do
    expected_withdrawals = get_expected_withdrawals(state)

    length_of_validators = length(validators)

    with {:ok, state} <- decrease_balances(state, withdrawals, expected_withdrawals) do
      {:ok,
       state
       |> update_next_withdrawal_index(expected_withdrawals)
       |> update_next_withdrawal_validator_index(expected_withdrawals, length_of_validators)}
    end
  end

  @spec update_next_withdrawal_index(BeaconState.t(), list(Withdrawal.t())) :: BeaconState.t()
  defp update_next_withdrawal_index(state, expected_withdrawals) do
    # Update the next withdrawal index if this block contained withdrawals
    length_of_expected_withdrawals = length(expected_withdrawals)

    case length_of_expected_withdrawals != 0 do
      true ->
        latest_withdrawal = List.last(expected_withdrawals)
        %BeaconState{state | next_withdrawal_index: latest_withdrawal.index + 1}

      false ->
        state
    end
  end

  @spec update_next_withdrawal_validator_index(BeaconState.t(), list(Withdrawal.t()), integer) ::
          BeaconState.t()
  defp update_next_withdrawal_validator_index(state, expected_withdrawals, length_of_validators) do
    length_of_expected_withdrawals = length(expected_withdrawals)

    case length_of_expected_withdrawals == ChainSpec.get("MAX_WITHDRAWALS_PER_PAYLOAD") do
      # Update the next validator index to start the next withdrawal sweep
      true ->
        latest_withdrawal = List.last(expected_withdrawals)
        next_validator_index = rem(latest_withdrawal.validator_index + 1, length_of_validators)
        %BeaconState{state | next_withdrawal_validator_index: next_validator_index}

      # Advance sweep by the max length of the sweep if there was not a full set of withdrawals
      false ->
        next_index =
          state.next_withdrawal_validator_index +
            ChainSpec.get("MAX_VALIDATORS_PER_WITHDRAWALS_SWEEP")

        next_validator_index = rem(next_index, length_of_validators)
        %BeaconState{state | next_withdrawal_validator_index: next_validator_index}
    end
  end

  @spec decrease_balances(BeaconState.t(), list(Withdrawal.t()), list(Withdrawal.t())) ::
          {:ok, BeaconState.t()} | {:error, String.t()}
  defp decrease_balances(_state, withdrawals, expected_withdrawals)
       when length(withdrawals) !== length(expected_withdrawals) do
    {:error, "expected withdrawals don't match the state withdrawals in length"}
  end

  @spec decrease_balances(BeaconState.t(), list(Withdrawal.t()), list(Withdrawal.t())) ::
          {:ok, BeaconState.t()} | {:error, String.t()}
  defp decrease_balances(state, withdrawals, expected_withdrawals) do
    Enum.zip(expected_withdrawals, withdrawals)
    |> Enum.reduce_while({:ok, state}, &decrease_or_halt/2)
  end

  defp decrease_or_halt({expected_withdrawal, withdrawal}, _)
       when expected_withdrawal !== withdrawal do
    {:halt, {:error, "withdrawal != expected_withdrawal"}}
  end

  defp decrease_or_halt({_, withdrawal}, {:ok, state}) do
    {:cont,
     {:ok, BeaconState.decrease_balance(state, withdrawal.validator_index, withdrawal.amount)}}
  end

  @spec get_expected_withdrawals(BeaconState.t()) :: list(Withdrawal.t())
  defp get_expected_withdrawals(
         %BeaconState{
           next_withdrawal_index: next_withdrawal_index,
           next_withdrawal_validator_index: next_withdrawal_validator_index,
           validators: validators,
           balances: balances
         } = state
       ) do
    # Compute the next batch of withdrawals which should be included in a block.
    epoch = Accessors.get_current_epoch(state)
    withdrawal_index = next_withdrawal_index
    validator_index = next_withdrawal_validator_index
    max_validators_per_withdrawals_sweep = ChainSpec.get("MAX_VALIDATORS_PER_WITHDRAWALS_SWEEP")
    bound = min(length(validators), max_validators_per_withdrawals_sweep)

    {withdrawals, _, _} =
      Enum.reduce_while(0..(bound - 1), {[], validator_index, withdrawal_index}, fn _,
                                                                                    {withdrawals,
                                                                                     validator_index,
                                                                                     withdrawal_index} ->
        validator = Enum.fetch!(validators, validator_index)
        balance = Enum.fetch!(balances, validator_index)
        %Validator{withdrawal_credentials: withdrawal_credentials} = validator

        {withdrawals, withdrawal_index} =
          cond do
            Validator.is_fully_withdrawable_validator(validator, balance, epoch) ->
              <<_::binary-size(12), execution_address::binary>> = withdrawal_credentials

              withdrawal = %Withdrawal{
                index: withdrawal_index,
                validator_index: validator_index,
                address: execution_address,
                amount: balance
              }

              withdrawals = [withdrawal | withdrawals]
              withdrawal_index = withdrawal_index + 1

              {withdrawals, withdrawal_index}

            Validator.is_partially_withdrawable_validator(validator, balance) ->
              <<_::binary-size(12), execution_address::binary>> = withdrawal_credentials
              max_effective_balance = ChainSpec.get("MAX_EFFECTIVE_BALANCE")

              withdrawal = %Withdrawal{
                index: withdrawal_index,
                validator_index: validator_index,
                address: execution_address,
                amount: balance - max_effective_balance
              }

              withdrawals = [withdrawal | withdrawals]
              withdrawal_index = withdrawal_index + 1

              {withdrawals, withdrawal_index}

            true ->
              {withdrawals, withdrawal_index}
          end

        max_withdrawals_per_payload = ChainSpec.get("MAX_WITHDRAWALS_PER_PAYLOAD")

        if length(withdrawals) == max_withdrawals_per_payload do
          {:halt, {withdrawals, validator_index, withdrawal_index}}
        else
          validator_index = rem(validator_index + 1, length(validators))
          {:cont, {withdrawals, validator_index, withdrawal_index}}
        end
      end)

    Enum.reverse(withdrawals)
  end

  @doc """
  Process attestations during state transition.
  """
  @spec process_attestation(BeaconState.t(), Attestation.t()) ::
          {:ok, BeaconState.t()} | {:error, binary()}
  def process_attestation(state, attestation) do
    case verify_attestation_for_process(state, attestation) do
      {:ok, _} ->
        data = attestation.data
        aggregation_bits = attestation.aggregation_bits

        case process_attestation(state, data, aggregation_bits) do
          {:ok, updated_state} -> {:ok, updated_state}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp process_attestation(state, data, aggregation_bits) do
    with {:ok, participation_flag_indices} <-
           Accessors.get_attestation_participation_flag_indices(
             state,
             data,
             state.slot - data.slot
           ),
         {:ok, attesting_indices} <-
           Accessors.get_attesting_indices(state, data, aggregation_bits) do
      is_current_epoch = data.target.epoch == Accessors.get_current_epoch(state)
      initial_epoch_participation = get_initial_epoch_participation(state, is_current_epoch)

      {proposer_reward_numerator, updated_epoch_participation} =
        update_epoch_participation(
          state,
          attesting_indices,
          initial_epoch_participation,
          participation_flag_indices
        )

      proposer_reward = compute_proposer_reward(proposer_reward_numerator)

      {:ok, bal_updated_state} =
        Mutators.increase_balance(
          state,
          Accessors.get_beacon_proposer_index(state),
          proposer_reward
        )

      updated_state =
        update_state(bal_updated_state, is_current_epoch, updated_epoch_participation)

      {:ok, updated_state}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_initial_epoch_participation(state, true), do: state.current_epoch_participation
  defp get_initial_epoch_participation(state, false), do: state.previous_epoch_participation

  defp update_epoch_participation(
         state,
         attesting_indices,
         initial_epoch_participation,
         participation_flag_indices
       ) do
    Enum.reduce(attesting_indices, {0, initial_epoch_participation}, fn index, {acc, ep} ->
      update_participation_for_index(state, index, acc, ep, participation_flag_indices)
    end)
  end

  defp update_participation_for_index(state, index, acc, ep, participation_flag_indices) do
    Enum.reduce_while(
      0..(length(Constants.participation_flag_weights()) - 1),
      {acc, ep},
      fn flag_index, {inner_acc, inner_ep} ->
        if flag_index in participation_flag_indices &&
             not Predicates.has_flag(Enum.at(inner_ep, index), flag_index) do
          updated_ep =
            List.replace_at(inner_ep, index, Misc.add_flag(Enum.at(inner_ep, index), flag_index))

          acc_delta =
            Accessors.get_base_reward(state, index) *
              Enum.at(Constants.participation_flag_weights(), flag_index)

          {:cont, {inner_acc + acc_delta, updated_ep}}
        else
          {:cont, {inner_acc, inner_ep}}
        end
      end
    )
  end

  defp compute_proposer_reward(proposer_reward_numerator) do
    proposer_reward_denominator =
      ((Constants.weight_denominator() - Constants.proposer_weight()) *
         Constants.weight_denominator())
      |> div(Constants.proposer_weight())

    div(proposer_reward_numerator, proposer_reward_denominator)
  end

  defp update_state(state, true, updated_epoch_participation),
    do: %{state | current_epoch_participation: updated_epoch_participation}

  defp update_state(state, false, updated_epoch_participation),
    do: %{state | previous_epoch_participation: updated_epoch_participation}

  def verify_attestation_for_process(state, attestation) do
    data = attestation.data

    beacon_committee = fetch_beacon_committee(state, data)
    indexed_attestation = fetch_indexed_attestation(state, attestation)

    if has_invalid_conditions?(data, state, beacon_committee, indexed_attestation, attestation) do
      {:error, get_error_message(data, state, beacon_committee, indexed_attestation, attestation)}
    else
      {:ok, "Valid"}
    end
  end

  defp has_invalid_conditions?(data, state, beacon_committee, indexed_attestation, attestation) do
    invalid_target_epoch?(data, state) ||
      epoch_mismatch?(data) ||
      invalid_slot_range?(data, state) ||
      exceeds_committee_count?(data, state) ||
      !beacon_committee || !indexed_attestation ||
      mismatched_aggregation_bits_length?(attestation, beacon_committee) ||
      invalid_signature?(state, indexed_attestation)
  end

  defp get_error_message(data, state, beacon_committee, indexed_attestation, attestation) do
    cond do
      invalid_target_epoch?(data, state) ->
        "Invalid target epoch"

      epoch_mismatch?(data) ->
        "Epoch mismatch"

      invalid_slot_range?(data, state) ->
        "Invalid slot range"

      exceeds_committee_count?(data, state) ->
        "Index exceeds committee count"

      !beacon_committee || !indexed_attestation ->
        "Indexing error at beacon committee"

      mismatched_aggregation_bits_length?(attestation, beacon_committee) ->
        "Mismatched aggregation bits length"

      invalid_signature?(state, indexed_attestation) ->
        "Invalid signature"
    end
  end

  defp fetch_beacon_committee(state, data) do
    case Accessors.get_beacon_committee(state, data.slot, data.index) do
      {:ok, committee} -> committee
      {:error, _reason} -> nil
    end
  end

  defp fetch_indexed_attestation(state, attestation) do
    case Accessors.get_indexed_attestation(state, attestation) do
      {:ok, indexed_attestation} -> indexed_attestation
      {:error, _reason} -> nil
    end
  end

  defp invalid_target_epoch?(data, state) do
    data.target.epoch < Accessors.get_previous_epoch(state) ||
      data.target.epoch > Accessors.get_current_epoch(state)
  end

  defp epoch_mismatch?(data) do
    data.target.epoch != Misc.compute_epoch_at_slot(data.slot)
  end

  defp invalid_slot_range?(data, state) do
    state.slot < data.slot + ChainSpec.get("MIN_ATTESTATION_INCLUSION_DELAY") ||
      state.slot > data.slot + ChainSpec.get("SLOTS_PER_EPOCH")
  end

  defp exceeds_committee_count?(data, state) do
    data.index >= Accessors.get_committee_count_per_slot(state, data.target.epoch)
  end

  defp mismatched_aggregation_bits_length?(attestation, beacon_committee) do
    length_of_bitstring(attestation.aggregation_bits) - 1 != length(beacon_committee)
  end

  defp invalid_signature?(state, indexed_attestation) do
    Predicates.is_valid_indexed_attestation(state, indexed_attestation) != {:ok, true}
  end

  defp length_of_bitstring(binary) when is_binary(binary) do
    binary
    |> :binary.bin_to_list()
    |> Enum.reduce("", fn byte, acc ->
      acc <> Integer.to_string(byte, 2)
    end)
    |> String.length()
  end
end
