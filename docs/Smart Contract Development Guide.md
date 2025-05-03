# IOTA Move Smart Contract Development Guide

This guide explains step-by-step how to set up a local development environment, build and deploy Move-based smart contracts on IOTA’s testnet, and integrate them into a Next.js + Tailwind frontend using the IOTA CLI and TypeScript SDK.

## 1. Setup Development Environment

1. **Install the IOTA CLI tools.** The easiest way is to download the latest binary from the [IOTA Rebased GitHub releases](https://github.com/iotaledger/iota/releases) or use Homebrew:

   ```bash
   brew install iotaledger/tap/iota
   ```

   Ensure the CLI is in your PATH, then verify:

   ```bash
   iota --version
   ```

   If it prints a version, you have successfully installed the IOTA CLI.

2. **Configure the CLI for the IOTA Testnet.** The first time you run `iota client` you’ll be prompted to create a config file. Accept the defaults to connect to the IOTA Testnet (the CLI will use `https://api.testnet.iota.cafe` by default). You can also manually add an environment:

   ```bash
   iota client new-env --alias testnet --rpc https://api.testnet.iota.cafe
   iota client switch --env testnet
   ```

   This sets your active network to the Testnet. Ensure you have an active address (private key) configured; the CLI will generate a keypair and recovery phrase if none exists.

3. **Get test tokens from the faucet.** On testnet you need “gas” tokens to pay for transactions. With your active address set, request test IOTA:

   ```bash
   iota client faucet
   ```

   This will send some testnet IOTA to your address (no real value). You can also use the web faucet or curl:

   ```bash
   curl -X POST 'https://faucet.testnet.iota.cafe/gas' -d '{"address":"<your_address>"}'
   ```

4. **Ensure MoveVM compatibility.** The IOTA CLI includes MoveVM support out of the box. When creating packages, use the 2024 Move edition and link the IOTA framework at its `framework/testnet` revision to match the testnet runtime. In your `Move.toml`, the `[dependencies]` section should reference the IOTA framework repo, e.g.:

   ```toml
   [dependencies]
   Iota = { git = "https://github.com/iotaledger/iota.git", subdir = "crates/iota-framework/packages/iota-framework", rev = "framework/testnet" }
   ```

   This ensures your contract uses the same standard library as the testnet.

## 2. Create Project Structure

1. **Generate a Move package skeleton.** Use the IOTA Move CLI to scaffold your contract:

   ```bash
   iota move new my_contract
   ```

   This creates a new directory `my_contract/` with the following structure:

   ```
   my_contract/
     Move.toml
     sources/
     tests/
   ```

   * **Move.toml** – The package manifest (metadata, edition, dependencies).
   * **sources/** – Directory for your Move `.move` module files.
   * **tests/** – Directory for Move unit tests.

2. **Review Move.toml.** Open `my_contract/Move.toml`:

   ```toml
   [package]
   name = "my_contract"
   edition = "2024.beta"  # using Move 2024 edition

   [dependencies]
   Iota = { git = "https://github.com/iotaledger/iota.git",
            subdir = "crates/iota-framework/packages/iota-framework",
            rev = "framework/testnet" }

   [addresses]
   my_contract = "0x0"
   ```

   The `[package]` section names the package, and `[dependencies]` links the IOTA framework (as above). The `[addresses]` section initializes your package address (here `0x0`) which is updated upon publish. Dev dependencies and addresses sections allow test-mode overrides.

3. **Folder structure.** The typical folder layout is:

   ```
   my_contract/
     Move.toml      # Package manifest
     sources/
       my_contract.move   # Your module file(s)
     tests/
       my_contract_test.move  # (Optional) unit tests
   ```

   The `sources/` folder holds one or more `.move` files with your contract logic; `tests/` holds Move test scripts (functions marked with `#[test]`). The `Move.toml` manifest ties it all together.

## 3. Writing Move Contracts

1. **Create a Move module.** Inside `sources/`, create a file, e.g. `my_contract.move`, and define your module:

   ```move
   module my_contract::my_contract {
       // Define a resource or struct
       struct Counter has key, store { value: u64 }

       /// Initialize or increment the counter
       public fun increment(ctx: &mut TxContext) {
           let obj = object::new(ctx);
           object::write(ctx, &obj, &Counter { value: 1 });
       }

       /// Get the counter value (read-only)
       public entry fun get(ctx: &mut TxContext) {
           // (example code)
       }
   }
   ```

   Start your module with `module <package>::<module> { ... }`. Use `public` functions and `struct` definitions to implement your logic. Each public function takes a `&mut TxContext` (for transactions) and can create or modify objects. Comments in Move use `//` (as shown in the example above).

2. **(Optional) Add unit tests.** Under `tests/`, you can write Move functions annotated with `#[test]`. For example:

   ```move
   #[test]
   public fun test_increment() {
       let mut ctx = tx_context::dummy();
       increment(&mut ctx);
       // Add assertions on objects or values
   }
   ```

   The CLI will recognize `#[test]` functions (they must be `public`, take no parameters, return nothing). This lets you simulate calls at compile time.

## 4. Build and Test the Move Package

1. **Compile the package.** From the project root (where `Move.toml` is), run:

   ```bash
   iota move build
   ```

   This invokes the Move compiler and fetches any git dependencies. If successful, you will see output like:

   ```
   UPDATING GIT DEPENDENCY https://github.com/iotaledger/iota.git
   INCLUDING DEPENDENCY IOTA
   INCLUDING DEPENDENCY MoveStdlib
   BUILDING my_contract
   ```

   If there are errors, the CLI will display them. You can debug using the \[Move LSP or CLI output].

2. **Run unit tests.** With `iota move test`, the CLI builds and runs any `#[test]` functions in `tests/`:

   ```bash
   iota move test
   ```

   Example (no tests written) output:

   ```
   UPDATING GIT DEPENDENCY https://github.com/iotaledger/iota.git
   INCLUDING DEPENDENCY IOTA
   INCLUDING DEPENDENCY MoveStdlib
   BUILDING my_contract
   Running Move unit tests
   Test result: OK. Total tests: 0; passed: 0; failed: 0
   ```

   Write actual test functions to validate your logic, then re-run this command. Tests use a dummy `TxContext` for in-memory checks.

## 5. Deploying to IOTA Testnet

1. **Publish the package.** After building successfully, publish your contract to the network with the IOTA client:

   ```bash
   iota client publish --gas-budget 1000000
   ```

   (Include a `--gas-budget` high enough to cover execution costs.) This command takes the compiled bytecode from `Move.toml` and sends it to the testnet. You will see output showing the transaction’s object changes. Look for the **PackageID** under “Published Objects”. For example:

   ```
   Published Objects:
     PackageID: 0x2...ABC
     Version: 1
     Modules: my_contract
   ```

   The CLI will return the new package address (PackageID). Your active address now owns the new contract’s Forge object and an UpgradeCap.

2. **Verify published objects.** You can list all on-chain objects owned by your address:

   ```bash
   iota client objects
   ```

   This will show entries for: your `Coin` (from the faucet), the newly created `Forge` (from `init`), and an `UpgradeCap` tied to the package. The `Forge` object (e.g. `my_contract::Forge`) is where contract resources live.

3. **Invoke contract functions (transactions).** To call a Move function on-chain, use `iota client call` with the package and module:

   ```bash
   iota client call --package 0x2...ABC --module my_contract --function increment --gas <COIN_ID>
   ```

   This builds and executes a programmable transaction that invokes `increment`. The CLI will output changes to objects. (Under the hood this uses the programmable transaction builder; the `--gas` option selects which coin pays the gas. If omitted, a suitable coin is chosen automatically.)

   *Advanced:* You can simulate or prepare transactions without executing by using `--serialize-unsigned-transaction` or `--serialize-signed-transaction`. This outputs a base64 transaction blob, which you can later send with `iota client execute-signed-tx` or `execute-combined-signed-tx`. This is useful for external signing.

## 6. Wallet Connection and Signing Configuration

1. **CLI Key management.** The CLI uses the active address’s key for signing. You can import/export keys via `iota keytool`. For example, to import a raw private key (exported from the IOTA Wallet) into the CLI:

   ```bash
   iota keytool import --private-key <hex-key>
   ```

   The keytool can convert key formats and store them with an alias. Once imported, the address is available in `iota client addresses` and can sign transactions (like `publish`, `call`, etc.) automatically.

2. **DApp (web) wallet integration.** For frontend integration, use the official **IOTA Wallet** browser extension and the IOTA dApp Toolkit. In React/Next.js you’ll wrap your app in providers so it can connect to the wallet:

   * Install the dApp toolkit and SDK:

     ```bash
     npm install @iota/iota-sdk @iota/dapp-kit @tanstack/react-query
     ```

     (See \[IOTA TypeScript SDK docs] for details.)
   * In your `_app.js` or main render, wrap the app with:

     ```jsx
     import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
     import { IotaClientProvider, WalletProvider } from '@iota/dapp-kit';
     import { getFullnodeUrl } from '@iota/iota-sdk/client';

     const queryClient = new QueryClient();
     const networks = {
       devnet: { url: getFullnodeUrl('devnet') },
       testnet: { url: getFullnodeUrl('testnet') }
     };

     <QueryClientProvider client={queryClient}>
       <IotaClientProvider networks={networks} defaultNetwork="testnet">
         <WalletProvider>
           <Component {...pageProps} />
         </WalletProvider>
       </IotaClientProvider>
     </QueryClientProvider>
     ```

     This configures the TS SDK to use IOTA endpoints and enables wallet integration.

3. **Connect and sign with dApp Kit.** In your UI, use the `<ConnectButton />` from `@iota/dapp-kit` to let users connect their wallet. For example:

   ```jsx
   import { ConnectButton, useCurrentAccount } from '@iota/dapp-kit';

   function App() {
     const account = useCurrentAccount();
     return (
       <div>
         <ConnectButton />
         {account && <p>Connected: {account.address}</p>}
       </div>
     );
   }
   ```

   Once connected, `useCurrentAccount()` provides the user’s address and signing capability. All TS SDK calls (described next) will use this wallet to sign transactions.

## 7. Frontend Integration (Next.js + Tailwind)

1. **Create a Next.js project with Tailwind.** Scaffold a new Next.js app and set up Tailwind CSS (following [Tailwind docs](https://tailwindcss.com/docs/guides/nextjs)). For example:

   ```bash
   npx create-next-app my-dapp
   cd my-dapp
   npm install -D tailwindcss postcss autoprefixer
   npx tailwindcss init -p
   ```

   Configure `tailwind.config.js` and add Tailwind directives to your CSS. (Standard Next/Tailwind setup is beyond our scope; see \[Tailwind NextJS guide].)

2. **Install IOTA libraries:**

   ```bash
   npm install @iota/iota-sdk @iota/dapp-kit @tanstack/react-query
   ```

   These provide the TypeScript SDK and dApp components. Ensure your app entry wraps providers as above.

3. **Use the dApp Toolkit components:** In your React components, you can use hooks and components from `@iota/dapp-kit`. For example, add `<ConnectButton />` to allow wallet connection. You can then use hooks such as `useCurrentAccount()` and `useIotaClient()` (if provided) to get the connected wallet and an `IotaClient` instance.

## 8. Calling Move Contracts from the Frontend

With the TS SDK and dApp Kit set up, you can invoke Move contracts from React/Next. Below is an example of building and submitting a transaction that calls a Move function, using `@iota/iota-sdk`:

```ts
import { Client, MnemonicSecretManager, Transaction } from '@iota/iota-sdk';

// Initialize the IOTA client (using localPoW if needed)
const client = new Client({ nodes: [{ url: 'https://api.testnet.iota.cafe:443' }], localPow: true });

// Suppose the wallet provides a secretManager or keypair; here we use a mnemonic
const secretManager = new MnemonicSecretManager({ mnemonic: 'your 24-word-seed' });

// Build a programmable transaction to call a Move function
const tx = new Transaction();
tx.moveCall({
  target: '0x2::my_contract::increment',
  arguments: [tx.pure.u64(1)],
});

// Sign and submit the transaction
async function callIncrement() {
  const result = await client.signAndExecuteTransaction({ signer: secretManager, transaction: tx });
  // Wait for confirmation
  await client.waitForTransaction({ digest: result.digest });
  console.log('Transaction confirmed', result);
}
```

This code constructs a Move call transaction (`tx.moveCall`) to the `increment` function in your contract (replace package address and names appropriately). It then uses `client.signAndExecuteTransaction` to send it. You can await `client.waitForTransaction({ digest })` to know when it’s finalized.

For read-only queries (displaying contract state), use the TS SDK or GraphQL: e.g., fetch objects or dynamic fields from the ledger and render them. The TS SDK also provides a `client.callReadOnlyFunction` (or similar) to call view-only Move functions if defined. Alternatively, query the GraphQL API via `IotaClient` or `IotaGraphQLClient` for on-chain resources. For example, you could use `client.getObject({ objectId })` to fetch a resource (such as your contract’s stored data) and then display its fields in the UI.

## References

* IOTA CLI and Move CLI documentation (installation, commands)
* IOTA Move package tutorial (Move.toml, modules, build/test)
* IOTA client (publish, call, objects) guide
* IOTA TypeScript SDK and dApp Kit docs (client setup, `Transaction`, providers, ConnectButton)
