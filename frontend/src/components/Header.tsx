import React from 'react'
import { Link } from 'react-router-dom'
import { useAccount, useConnect, useDisconnect, useChainId, useSwitchChain } from 'wagmi'

const SUPPORTED_CHAINS = [421614, 84532, 11155420]

export default function Header() {
  const { address, isConnected, chainId } = useAccount()
  const { connect, connectors } = useConnect()
  const { disconnect } = useDisconnect()
  const { switchChain } = useSwitchChain()

  const onWrongNetwork = isConnected && chainId && !SUPPORTED_CHAINS.includes(chainId)

  return (
    <>
      {onWrongNetwork && (
        <div className="network-warning">
          Wrong network detected. Please switch to Arbitrum Sepolia, Base Sepolia, or Optimism Sepolia.
          <button onClick={() => switchChain({ chainId: 421614 })}>
            Switch to Arbitrum Sepolia
          </button>
        </div>
      )}
      <header className="header">
        <div style={{ fontWeight: 'bold', fontSize: 18, color: '#aaaaff' }}>
          PredMark
        </div>
        <nav>
          <Link to="/">Home</Link>
          <Link to="/markets">Markets</Link>
          <Link to="/governance">Governance</Link>
          <Link to="/vault">Vault</Link>
        </nav>
        <div>
          {isConnected ? (
            <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <span style={{ fontSize: 13, color: '#8888cc' }}>
                {address?.slice(0, 6)}...{address?.slice(-4)}
              </span>
              <button onClick={() => disconnect()} style={{ padding: '6px 12px', fontSize: 12 }}>
                Disconnect
              </button>
            </div>
          ) : (
            <button onClick={() => connect({ connector: connectors[0] })}>
              Connect Wallet
            </button>
          )}
        </div>
      </header>
    </>
  )
}
