import React, { useState } from 'react'
import { useAccount, useWriteContract, useReadContract, useWaitForTransactionReceipt } from 'wagmi'
import { parseUnits } from 'viem'

const VAULT_ABI = [
  { type: 'function', name: 'asset', inputs: [], outputs: [{ type: 'address' }], stateMutability: 'view' },
  { type: 'function', name: 'totalAssets', inputs: [], outputs: [{ type: 'uint256' }], stateMutability: 'view' },
  { type: 'function', name: 'totalSupply', inputs: [], outputs: [{ type: 'uint256' }], stateMutability: 'view' },
  { type: 'function', name: 'balanceOf', inputs: [{ type: 'address' }], outputs: [{ type: 'uint256' }], stateMutability: 'view' },
  { type: 'function', name: 'deposit', inputs: [{ type: 'uint256' }, { type: 'address' }], outputs: [{ type: 'uint256' }], stateMutability: 'nonpayable' },
  { type: 'function', name: 'withdraw', inputs: [{ type: 'uint256' }, { type: 'address' }, { type: 'address' }], outputs: [{ type: 'uint256' }], stateMutability: 'nonpayable' },
  { type: 'function', name: 'convertToShares', inputs: [{ type: 'uint256' }], outputs: [{ type: 'uint256' }], stateMutability: 'view' },
]

export default function Vault() {
  const { address, isConnected } = useAccount()
  const [vaultAddress, setVaultAddress] = useState('')
  const [amount, setAmount] = useState('')
  const [error, setError] = useState('')
  const [txHash, setTxHash] = useState<`0x${string}` | null>(null)

  const { writeContract, isPending } = useWriteContract({
    mutation: {
      onSuccess: (hash) => setTxHash(hash),
      onError: (err: Error) => {
        setError(err.message.includes('rejected') ? 'Transaction rejected'
          : err.message.includes('balance') ? 'Insufficient balance'
          : `Error: ${err.message.slice(0, 80)}`)
      },
    },
  })

  const { data: totalAssets } = useReadContract({
    address: vaultAddress as `0x${string}`,
    abi: VAULT_ABI, functionName: 'totalAssets',
    query: { enabled: !!vaultAddress },
  })

  const { data: userBalance } = useReadContract({
    address: vaultAddress as `0x${string}`,
    abi: VAULT_ABI, functionName: 'balanceOf',
    args: [address as `0x${string}`],
    query: { enabled: !!vaultAddress && !!address },
  })

  const handleDeposit = async () => {
    setError(''); setTxHash(null)
    if (!vaultAddress || !amount) { setError('Fill all fields'); return }
    try {
      writeContract({
        address: vaultAddress as `0x${string}`,
        abi: VAULT_ABI, functionName: 'deposit',
        args: [parseUnits(amount, 6), address as `0x${string}`],
      })
    } catch (e: any) { setError(e.message) }
  }

  return (
    <div>
      <h2 style={{ margin: '16px 0', color: '#aaaaff' }}>Fee Vault</h2>

      {error && <div className="error">{error}</div>}
      {txHash && <div className="success">Tx: {txHash.slice(0, 10)}...</div>}
      {isPending && <div className="success">Transaction pending...</div>}

      {!isConnected ? (
        <div className="card"><p>Connect wallet to interact with the vault.</p></div>
      ) : (
        <div className="grid">
          <div className="card">
            <h3>Vault Info</h3>
            <label>Vault Address</label>
            <input value={vaultAddress} onChange={e => setVaultAddress(e.target.value)} placeholder="0x..." />
            {totalAssets !== undefined && (
              <p>Total Assets: {totalAssets.toString()}</p>
            )}
            {userBalance !== undefined && (
              <p>Your Shares: {userBalance.toString()}</p>
            )}
          </div>

          <div className="card">
            <h3>Deposit</h3>
            <label>Amount (USDC)</label>
            <input value={amount} onChange={e => setAmount(e.target.value)} type="number" placeholder="1000" />
            <button onClick={handleDeposit} disabled={!vaultAddress || !amount}>
              Deposit
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
