import React from 'react'
import ReactDOM from 'react-dom/client'
import { WagmiProvider, createConfig, http } from 'wagmi'
import { arbitrumSepolia, baseSepolia, optimismSepolia } from 'wagmi/chains'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { metaMask } from 'wagmi/connectors'
import App from './App'

export const config = createConfig({
  chains: [arbitrumSepolia, baseSepolia, optimismSepolia],
  connectors: [metaMask()],
  transports: {
    [arbitrumSepolia.id]: http(),
    [baseSepolia.id]: http(),
    [optimismSepolia.id]: http(),
  },
})

const queryClient = new QueryClient()

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <App />
      </QueryClientProvider>
    </WagmiProvider>
  </React.StrictMode>
)
