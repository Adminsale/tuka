import { BigInt, Bytes } from "@graphprotocol/graph-ts"
import {
  TokensPurchased as TokensPurchasedEvent,
  TokensSold as TokensSoldEvent,
  LiquidityAdded as LiquidityAddedEvent,
  LiquidityRemoved as LiquidityRemovedEvent,
  MarketResolved as MarketResolvedEvent,
  PredictionMarket
} from "../generated/PredictionMarket/PredictionMarket"
import { Market, Trade, LiquidityChange } from "../generated/schema"

export function handleTokensPurchased(event: TokensPurchasedEvent): void {
  let market = Market.load(event.address.toHexString())
  if (!market) return

  let trade = new Trade(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  )
  trade.market = market.id
  trade.trader = event.params.buyer
  trade.outcome = event.params.outcome
  trade.amountIn = event.params.amountIn
  trade.amountOut = event.params.amountOut
  trade.timestamp = event.block.timestamp
  trade.save()
}

export function handleTokensSold(event: TokensSoldEvent): void {
  let market = Market.load(event.address.toHexString())
  if (!market) return

  let trade = new Trade(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  )
  trade.market = market.id
  trade.trader = event.params.seller
  trade.outcome = event.params.outcome
  trade.amountIn = event.params.amountIn
  trade.amountOut = event.params.amountOut
  trade.timestamp = event.block.timestamp
  trade.save()
}

export function handleLiquidityAdded(event: LiquidityAddedEvent): void {
  let marketId = event.address.toHexString()
  let market = Market.load(marketId)
  if (!market) return

  market.reserveYes = market.reserveYes.plus(event.params.amountYes)
  market.reserveNo = market.reserveNo.plus(event.params.amountNo)
  market.totalLpShares = market.totalLpShares.plus(event.params.shares)
  market.save()

  let lc = new LiquidityChange(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  )
  lc.market = marketId
  lc.provider = event.params.lp
  lc.amountYes = event.params.amountYes
  lc.amountNo = event.params.amountNo
  lc.shares = event.params.shares
  lc.isAdd = true
  lc.timestamp = event.block.timestamp
  lc.save()
}

export function handleLiquidityRemoved(event: LiquidityRemovedEvent): void {
  let marketId = event.address.toHexString()
  let market = Market.load(marketId)
  if (!market) return

  market.reserveYes = market.reserveYes.minus(event.params.amountYes)
  market.reserveNo = market.reserveNo.minus(event.params.amountNo)
  market.totalLpShares = market.totalLpShares.minus(event.params.shares)
  market.save()

  let lc = new LiquidityChange(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  )
  lc.market = marketId
  lc.provider = event.params.lp
  lc.amountYes = event.params.amountYes
  lc.amountNo = event.params.amountNo
  lc.shares = event.params.shares
  lc.isAdd = false
  lc.timestamp = event.block.timestamp
  lc.save()
}

export function handleMarketResolved(event: MarketResolvedEvent): void {
  let market = Market.load(event.address.toHexString())
  if (!market) return

  market.resolved = true
  market.winner = event.params.winner
  market.save()
}
