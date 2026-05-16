import React, { useState } from 'react'
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { parseUnits } from 'viem'

const MARKET_ABI = [
  { type: 'function', name: 'buyOutcome', inputs: [{ type: 'uint8' }, { type: 'uint256' }, { type: 'uint256' }], outputs: [{ type: 'uint256' }], stateMutability: 'nonpayable' },
  { type: 'function', name: 'sellOutcome', inputs: [{ type: 'uint8' }, { type: 'uint256' }, { type: 'uint256' }], outputs: [{ type: 'uint256' }], stateMutability: 'nonpayable' },
  { type: 'function', name: 'splitBase', inputs: [{ type: 'uint256' }], outputs: [], stateMutability: 'nonpayable' },
  { type: 'function', name: 'getPrice', inputs: [{ type: 'uint8' }], outputs: [{ type: 'uint256' }], stateMutability: 'view' },
  { type: 'function', name: 'getReserves', inputs: [], outputs: [{ type: 'uint256' }, { type: 'uint256' }], stateMutability: 'view' },
  { type: 'function', name: 'question', inputs: [], outputs: [{ type: 'string' }], stateMutability: 'view' },
  { type: 'function', name: 'resolved', inputs: [], outputs: [{ type: 'bool' }], stateMutability: 'view' },
  { type: 'function', name: 'winner', inputs: [], outputs: [{ type: 'uint8' }], stateMutability: 'view' },
]

export default function Markets() {
  const { isConnected } = useAccount()
  const [marketAddress, setMarketAddress] = useState('')
  const [amount, setAmount] = useState('')
  const [outcome, setOutcome] = useState<'1' | '2'>('1')
  const [error, setError] = useState('')
  const [txHash, setTxHash] = useState<`0x${string}` | null>(null)

  const { writeContract, isPending } = useWriteContract({
    mutation: {
      onSuccess: (hash) => setTxHash(hash),
      onError: (err: Error) => {
        const msg = err.message.includes('rejected') ? 'Transaction rejected by user'
          : err.message.includes('insufficient') ? 'Insufficient balance'
          : err.message.includes('network') ? 'Wrong network - please switch'
          : `Transaction failed: ${err.message.slice(0, 100)}`
        setError(msg)
      },
    },
  })

  const { isLoading: isConfirming } = useWaitForTransactionReceipt({ hash: txHash })

  const handleBuy = async () => {
    setError('')
    setTxHash(null)
    if (!marketAddress || !amount) { setError('Fill all fields'); return }
    try {
      writeContract({
        address: marketAddress as `0x${string}`,
        abi: MARKET_ABI,
        functionName: 'buyOutcome',
        args: [parseInt(outcome), parseUnits(amount, 6), BigInt(0)],
      })
    } catch (e: any) { setError(e.message) }
  }

  const handleSplit = async () => {
    setError('')
    setTxHash(null)
    if (!marketAddress || !amount) { setError('Fill all fields'); return }
    try {
      writeContract({
        address: marketAddress as `0x${string}`,
        abi: MARKET_ABI,
        functionName: 'splitBase',
        args: [parseUnits(amount, 6)],
      })
    } catch (e: any) { setError(e.message) }
  }

  return (
    <div>
      <h2 style={{ margin: '16px 0', color: '#aaaaff' }}>Markets</h2>

      {error && <div className="error">{error}</div>}
      {txHash && <div className="success">Tx submitted: {txHash.slice(0, 10)}...</div>}
      {(isPending || isConfirming) && <div className="success">Transaction pending...</div>}

      {!isConnected ? (
        <div className="card"><p>Connect your wallet to trade.</p></div>
      ) : (
        <div className="grid">
          <div className="card">
            <h3>Trade</h3>
            <label>Market Address</label>
            <input value={marketAddress} onChange={e => setMarketAddress(e.target.value)} placeholder="0x..." />
            <label>Amount (USDC)</label>
            <input value={amount} onChange={e => setAmount(e.target.value)} type="number" placeholder="100" />
            <label>Outcome</label>
            <select value={outcome} onChange={e => setOutcome(e.target.value as '1' | '2')}>
              <option value="1">YES</option>
              <option value="2">NO</option>
            </select>
            <div className="flex" style={{ marginTop: 16 }}>
              <button onClick={handleBuy} disabled={isPending}>Buy</button>
              <button onClick={handleSplit} disabled={isPending}>Split</button>
            </div>
          </div>

          <div className="card">
            <h3>Market Info</h3>
            <p style={{ color: '#6666aa', fontSize: 13 }}>
              Enter a market address above and connect to see its details.
            </p>
          </div>
        </div>
      )}
    </div>
  )
}
