import React, { useState, useEffect } from 'react';
import { useIotaClient, useCurrentAccount } from '@iota/dapp-kit';
import { AssetCard } from './AssetCard';
import { LoadingSpinner } from './LoadingSpinner';

interface Asset {
  id: string;
  assetId: string;
  assetType: string;
  title: string;
  description: string;
  metadata: {
    location?: string;
    size?: string;
    [key: string]: any;
  };
  owner: string;
  spvAddress: string;
  tokenSymbol?: string;
  tokenSupply?: number;
  price?: number;
}

export const AssetListing: React.FC = () => {
  const [assets, setAssets] = useState<Asset[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);
  const [filter, setFilter] = useState<string>('all');
  
  const iotaClient = useIotaClient();
  const account = useCurrentAccount();

  useEffect(() => {
    const fetchAssets = async () => {
      if (!iotaClient) return;
      
      try {
        setLoading(true);
        
        // In a real implementation, we would fetch assets from the blockchain
        // For now, we'll use mock data
        const mockAssets: Asset[] = [
          {
            id: '0x1',
            assetId: 'ASSET001',
            assetType: 'real_estate',
            title: 'Luxury Apartment in New York',
            description: 'A beautiful luxury apartment in downtown Manhattan with stunning views.',
            metadata: {
              location: 'New York, NY',
              size: '2000 sqft',
              bedrooms: 3,
              bathrooms: 2,
              yearBuilt: 2018
            },
            owner: '0xSPV1',
            spvAddress: '0xSPV1',
            tokenSymbol: 'LAT',
            tokenSupply: 1000000,
            price: 250
          },
          {
            id: '0x2',
            assetId: 'ASSET002',
            assetType: 'real_estate',
            title: 'Commercial Building in San Francisco',
            description: 'Prime commercial real estate in the heart of San Francisco\'s financial district.',
            metadata: {
              location: 'San Francisco, CA',
              size: '10000 sqft',
              floors: 5,
              yearBuilt: 2010
            },
            owner: '0xSPV2',
            spvAddress: '0xSPV2',
            tokenSymbol: 'CBT',
            tokenSupply: 5000000,
            price: 500
          },
          {
            id: '0x3',
            assetId: 'ASSET003',
            assetType: 'equity',
            title: 'TechStart Inc. Equity',
            description: 'Equity shares in TechStart, a promising AI startup with significant growth potential.',
            metadata: {
              industry: 'Technology',
              founded: 2020,
              employees: 45,
              revenue: '$2.5M'
            },
            owner: '0xSPV1',
            spvAddress: '0xSPV1',
            tokenSymbol: 'TSI',
            tokenSupply: 10000000,
            price: 50
          }
        ];
        
        setAssets(mockAssets);
        setError(null);
      } catch (err) {
        console.error('Error fetching assets:', err);
        setError('Failed to load assets. Please try again later.');
      } finally {
        setLoading(false);
      }
    };
    
    fetchAssets();
  }, [iotaClient]);

  const filteredAssets = filter === 'all' 
    ? assets 
    : assets.filter(asset => asset.assetType === filter);

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="flex justify-between items-center mb-8">
        <h1 className="text-3xl font-bold text-gray-900">Available Assets</h1>
        <div className="flex space-x-2">
          <button 
            onClick={() => setFilter('all')}
            className={`px-4 py-2 rounded-md ${filter === 'all' ? 'bg-blue-600 text-white' : 'bg-gray-200 text-gray-800'}`}
          >
            All
          </button>
          <button 
            onClick={() => setFilter('real_estate')}
            className={`px-4 py-2 rounded-md ${filter === 'real_estate' ? 'bg-blue-600 text-white' : 'bg-gray-200 text-gray-800'}`}
          >
            Real Estate
          </button>
          <button 
            onClick={() => setFilter('equity')}
            className={`px-4 py-2 rounded-md ${filter === 'equity' ? 'bg-blue-600 text-white' : 'bg-gray-200 text-gray-800'}`}
          >
            Equity
          </button>
        </div>
      </div>
      
      {loading ? (
        <div className="flex justify-center items-center h-64">
          <LoadingSpinner />
        </div>
      ) : error ? (
        <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded relative" role="alert">
          <strong className="font-bold">Error!</strong>
          <span className="block sm:inline"> {error}</span>
        </div>
      ) : filteredAssets.length === 0 ? (
        <div className="text-center py-10">
          <p className="text-gray-500 text-lg">No assets found.</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {filteredAssets.map(asset => (
            <AssetCard key={asset.id} asset={asset} />
          ))}
        </div>
      )}
    </div>
  );
};
