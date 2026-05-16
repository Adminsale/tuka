import React, { useEffect, useState } from 'react'
import { useAccount, useBalance, useReadContract } from 'wagmi'

export default function Home() {
  const { address, isConnected } = useAccount()
  const [subgraphData, setSubgraphData] = useState<any>(null)

  useEffect(() => {
    async function fetchSubgraph() {
      try {
        const res = await fetch(
          'https://api.studio.thegraph.com/query/0/predmark/version/latest',
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              query: `{
                markets(first: 5) {
                  id
                  question
                  resolved
                  winner
                  reserveYes
                  reserveNo
                }
              }`
            })
          }
        )
        const data = await res.json()
        setSubgraphData(data)
      } catch (e) {
        console.log('Subgraph not available:', e)
      }
    }
    fetchSubgraph()
  }, [])

  return (
    <div>
      <div className="card" style={{ textAlign: 'center', padding: 48 }}>
        <h1 style={{ fontSize: 32, marginBottom: 12 }}>Prediction Market Protocol</h1>
        <p style={{ color: '#8888aa', fontSize: 16, maxWidth: 600, margin: '0 auto' }}>
          Decentralized binary outcome prediction markets powered by CPMM AMM,
          Chainlink oracles, and DAO governance.
        </p>
        {!isConnected && (
          <p style={{ marginTop: 24, color: '#6666aa' }}>
            Connect your wallet to start trading outcomes
          </p>
        )}
      </div>

      {isConnected && (
        <div className="grid">
          <div className="card">
            <h3>Your Account</h3>
            <p>Address: {address}</p>
            <WalletInfo address={address!} />
          </div>

          <div className="card">
            <h3>Subgraph Data</h3>
            {subgraphData ? (
              <pre style={{ fontSize: 12, overflow: 'auto' }}>
                {JSON.stringify(subgraphData, null, 2)}
              </pre>
            ) : (
              <p>Loading subgraph data...</p>
            )}
          </div>
        </div>
      )}
    </div>
  )
}

function WalletInfo({ address }: { address: `0x${string}` }) {
  const { data: balance } = useBalance({ address })

  return (
    <div>
      <p>Balance: {balance ? `${Number(balance.formatted).toFixed(4)} ${balance.symbol}` : '...'}</p>
    </div>
  )
}
