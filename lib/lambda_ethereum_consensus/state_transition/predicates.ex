defmodule LambdaEthereumConsensus.StateTransition.Predicates do
  @moduledoc """
  Functions that verify state and return a `boolean`
  """

  alias SszTypes.Validator

  @doc """
  Check if ``validator`` is active.
  """
  @spec is_active_validator(Validator.t(), SszTypes.epoch()) :: boolean()
  def is_active_validator(validator, epoch) do
    validator.activation_epoch <= epoch and epoch < validator.exit_epoch
  end
end
