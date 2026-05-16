import { BigInt } from "@graphprotocol/graph-ts"
import {
  ProposalCreated as ProposalCreatedEvent,
  ProposalExecuted as ProposalExecutedEvent,
  VoteCast as VoteCastEvent
} from "../generated/ProtocolGovernor/ProtocolGovernor"
import { Proposal } from "../generated/schema"

export function handleProposalCreated(event: ProposalCreatedEvent): void {
  let proposal = new Proposal(event.params.proposalId.toString())
  proposal.proposalId = event.params.proposalId
  proposal.description = event.params.description
  proposal.proposer = event.params.proposer
  proposal.startBlock = event.params.startBlock
  proposal.endBlock = event.params.endBlock
  proposal.forVotes = BigInt.zero()
  proposal.againstVotes = BigInt.zero()
  proposal.abstainVotes = BigInt.zero()
  proposal.executed = false
  proposal.createdAt = event.block.timestamp
  proposal.save()
}

export function handleProposalExecuted(event: ProposalExecutedEvent): void {
  let proposal = Proposal.load(event.params.proposalId.toString())
  if (proposal) {
    proposal.executed = true
    proposal.save()
  }
}

export function handleVoteCast(event: VoteCastEvent): void {
  let proposal = Proposal.load(event.params.proposalId.toString())
  if (!proposal) return

  if (event.params.support == 1) {
    proposal.forVotes = proposal.forVotes.plus(event.params.weight)
  } else if (event.params.support == 0) {
    proposal.againstVotes = proposal.againstVotes.plus(event.params.weight)
  } else {
    proposal.abstainVotes = proposal.abstainVotes.plus(event.params.weight)
  }
  proposal.save()
}
