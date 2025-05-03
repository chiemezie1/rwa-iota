import React from 'react';
import Link from 'next/link';
import Image from 'next/image';

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

interface AssetCardProps {
  asset: Asset;
}

export const AssetCard: React.FC<AssetCardProps> = ({ asset }) => {
  const {
    id,
    assetId,
    assetType,
    title,
    description,
    metadata,
    tokenSymbol,
    tokenSupply,
    price
  } = asset;

  // Determine the image based on asset type
  const imageSrc = assetType === 'real_estate'
    ? '/images/real-estate-placeholder.jpg'
    : '/images/equity-placeholder.jpg';

  // Format price with commas
  const formattedPrice = price?.toLocaleString('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: 2
  });

  // Format token supply with commas
  const formattedSupply = tokenSupply?.toLocaleString('en-US');

  return (
    <div className="bg-white rounded-lg shadow-md overflow-hidden transition-transform duration-300 hover:shadow-lg hover:-translate-y-1">
      <div className="relative h-48 w-full">
        <div className="absolute top-0 right-0 bg-blue-600 text-white px-3 py-1 rounded-bl-lg z-10">
          {assetType === 'real_estate' ? 'Real Estate' : 'Equity'}
        </div>
        <Image
          src={imageSrc}
          alt={title}
          fill
          className="object-cover"
        />
      </div>
      
      <div className="p-4">
        <h3 className="text-xl font-semibold text-gray-900 mb-2">{title}</h3>
        <p className="text-gray-600 text-sm mb-4 line-clamp-2">{description}</p>
        
        <div className="grid grid-cols-2 gap-2 mb-4">
          {assetType === 'real_estate' && (
            <>
              <div className="text-sm">
                <span className="text-gray-500">Location:</span>
                <p className="text-gray-900 font-medium">{metadata.location}</p>
              </div>
              <div className="text-sm">
                <span className="text-gray-500">Size:</span>
                <p className="text-gray-900 font-medium">{metadata.size}</p>
              </div>
            </>
          )}
          
          {assetType === 'equity' && (
            <>
              <div className="text-sm">
                <span className="text-gray-500">Industry:</span>
                <p className="text-gray-900 font-medium">{metadata.industry}</p>
              </div>
              <div className="text-sm">
                <span className="text-gray-500">Founded:</span>
                <p className="text-gray-900 font-medium">{metadata.founded}</p>
              </div>
            </>
          )}
          
          <div className="text-sm">
            <span className="text-gray-500">Token:</span>
            <p className="text-gray-900 font-medium">{tokenSymbol}</p>
          </div>
          <div className="text-sm">
            <span className="text-gray-500">Supply:</span>
            <p className="text-gray-900 font-medium">{formattedSupply}</p>
          </div>
        </div>
        
        <div className="flex justify-between items-center">
          <div className="text-blue-600 font-bold text-lg">
            {formattedPrice} <span className="text-sm font-normal">per token</span>
          </div>
          <Link 
            href={`/assets/${id}`}
            className="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-md text-sm font-medium transition-colors duration-300"
          >
            View Details
          </Link>
        </div>
      </div>
    </div>
  );
};
