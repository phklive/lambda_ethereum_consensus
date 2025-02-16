defmodule Fixtures.Block do
  @moduledoc """
  Fixtures for blocks.
  """

  alias Fixtures.Random

  @spec signed_beacon_block :: SszTypes.SignedBeaconBlock.t()
  def signed_beacon_block do
    %SszTypes.SignedBeaconBlock{
      message: beacon_block(),
      signature: Random.bls_signature()
    }
  end

  @spec beacon_block :: SszTypes.BeaconBlock.t()
  def beacon_block do
    %SszTypes.BeaconBlock{
      parent_root: Random.root(),
      slot: Random.uint64(),
      proposer_index: Random.uint64(),
      state_root: Random.root(),
      body: beacon_block_body()
    }
  end

  @spec beacon_block_body :: SszTypes.BeaconBlockBody.t()
  def beacon_block_body do
    %SszTypes.BeaconBlockBody{
      randao_reveal: Random.bls_signature(),
      eth1_data: eth1_data(),
      graffiti: Random.hash32(),
      proposer_slashings: [],
      attester_slashings: [],
      attestations: [],
      deposits: [],
      voluntary_exits: [],
      sync_aggregate: sync_aggregate(),
      execution_payload: execution_payload(),
      bls_to_execution_changes: []
    }
  end

  @spec eth1_data :: SszTypes.Eth1Data.t()
  def eth1_data do
    %SszTypes.Eth1Data{
      deposit_root: Random.root(),
      deposit_count: Random.uint64(),
      block_hash: Random.hash32()
    }
  end

  @spec sync_aggregate :: SszTypes.SyncAggregate.t()
  def sync_aggregate do
    %SszTypes.SyncAggregate{
      sync_committee_bits: Random.sync_committee_bits(),
      sync_committee_signature: Random.bls_signature()
    }
  end

  @spec execution_payload :: SszTypes.ExecutionPayload.t()
  def execution_payload do
    %SszTypes.ExecutionPayload{
      parent_hash: Random.hash32(),
      fee_recipient: Random.execution_address(),
      state_root: Random.root(),
      receipts_root: Random.root(),
      logs_bloom: Random.binary(256),
      prev_randao: Random.hash32(),
      block_number: Random.uint64(),
      gas_limit: Random.uint64(),
      gas_used: Random.uint64(),
      timestamp: Random.uint64(),
      extra_data: Random.binary(30),
      base_fee_per_gas: Random.uint64(),
      block_hash: Random.binary(32),
      transactions: [],
      withdrawals: []
    }
  end
end
