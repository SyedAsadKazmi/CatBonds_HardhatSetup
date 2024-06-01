# Catastrophe Bonds Protocol

To setup this protocol, you mainly have to deploy 2 smart contracts:

1. **`CatastropheBondsCollateralPool`**: That acts as a **pool** containing and managing the collateral for the created Catastrophe Bonds and their respective posiions.

2. **`CatastropheBondsFactory`**: That acts as a **factory** for deployment/creation of Catastrophe Bonds with different specifications.

And, in order to serve its functionality cross-chain, you need to deploy these contracts to **Avalanche Fuji** (having ETH-ChainId as `43113`) and **Polygon Amoy** (having ETH-ChainId as `80002`) networks.

---

### Deployment using Hardhat

##### 1. Deploy & Verify CatastropheBondsCollateralPool contract

**On Avalanche Fuji:**

```shell
npx hardhat deployCollateralPool --network avalancheFujiTestnet
npx hardhat verify ${CatastropheBondsCollateralPool_Address} --network avalancheFujiTestnet
```

**On Polygon Amoy:**

```shell
npx hardhat deployCollateralPool --network polygonAmoy
npx hardhat verify ${CatastropheBondsCollateralPool_Address} --network polygonAmoy
```

##### 2. Deploy & Verify CatastropheBondsFactory contract

**On Avalanche Fuji:**

```shell
npx hardhat deployFactory ${CatastropheBondsCollateralPool_Address} --network avalancheFujiTestnet
npx hardhat verify ${CatastropheBondsFactory_Address} ${CatastropheBondsCollateralPool_Address} --network avalancheFujiTestnet
```

**On Polygon Amoy:**

```shell
npx hardhat deployFactory ${CatastropheBondsCollateralPool_Address} --network polygonAmoy
npx hardhat verify ${CatastropheBondsFactory_Address} ${CatastropheBondsCollateralPool_Address} --network polygonAmoy
```

---

### Deployment using Remix 

You can open and interact with this protocol in **Remix IDE**:

<a href="https://remix.ethereum.org/#version=soljson-v0.8.24+commit.e11b9ed9.js&optimize=true&runs=200&gist=fa0e55ccee5febf5441cf3fa44dc2577&lang=en&evmVersion=null" target="_blank">
  <img src="https://amaranth-secondary-primate-517.mypinata.cloud/ipfs/QmS7z2Aw6eKhzdyLXxutVSF3NcLB2SE6MpgRm4ER9tHjie" alt="Open In Remix" width="100" height="30">
</a>

---

### Detailed walkthrough video showcasing the deployment and interaction using Remix:

[![Deployment and Interaction with CatBonds Protocol using Remix IDE](https://img.youtube.com/vi/12u8Hgg77rg/maxresdefault.jpg)](https://youtu.be/MH3IFZZaGY4)

---

### CatBonds dApp UI

You can also use the [minimal dApp](https://cat-bonds.netlify.app/) to interact with the **Catastrophe Bonds Protocol**.

The dApp is using the following deployed and verified **`CatastropheBondsCollateralPool`** and **`CatastropheBondsFactory`** contracts:

**On Avalanche Fuji:**
    <br><br>
    - [CatastropheBondsCollateralPool](https://testnet.snowtrace.io/address/0x7e2F65C4f45Ad93065284Ce75830166211c7eC3b)
    <br><br>
    - [CatastropheBondsFactory](https://testnet.snowtrace.io/address/0x26D9E84527D1FED9eA3eC680366E4f9A69530e16)
    <br><br>
**On Polygon Amoy:**
    <br><br>
    - [CatastropheBondsCollateralPool](https://amoy.polygonscan.com/address/0xec2B803E708F5bCcEA23d16CB74a97237600d17B)
    <br><br>
    - [CatastropheBondsFactory](https://amoy.polygonscan.com/address/0xDCe893395b07FBE2D546631304F1C552092245b7)
    <br><br>

And, the corresponding **`CatastropheBondsFactory`**  contract has been registered as [Custom Logic Upkeep](https://docs.chain.link/chainlink-automation/guides/register-upkeep) at [automation.chain.link](https://automation.chain.link) and [added as consumer](https://docs.chain.link/chainlink-functions/getting-started#add-a-consumer-to-your-subscription) to the respective subscriptions at [functions.chain.link](https://functions.chain.link) on both the networks, so as to utilise the automated request sending to the oracle and contract settlement based on the value received from the oracle.

Also, the **`CatastropheBondsFactory`** contract is utilising [CCIP](https://docs.chain.link/ccip) to create the **Catastrophe Bonds** across chains i.e., if one Catastrophe Bond contract is being created and deployed on **Avalanche Fuji**, then a copy of the same will be created and deployed on **Polygon Amoy** and vice versa, and the same can be explored on [ccip.chain.link](https://ccip.chain.link) using the corresponding message id or transaction hash.

And, similarly the **`CatastropheBondsCollateralPool`** contract is utilising [CCIP](https://docs.chain.link/ccip) for cross-chain **minting** and **redeeming** of position tokens for **Catastrophe Bonds**, as well as for moving **USDC Collateral** back and forth across chains depending on the requirement in terms of the favour of settlement.

---

### Detailed walkthrough videos showcasing the interaction with the UI of the CatBonds dApp

**Part-1** | Showcasing the "**WILD FIRE**" being detected in "**Tshuapa, Democratic Republic of the Congo**":

[![Part-1](https://img.youtube.com/vi/DQqXipq4QjU/maxresdefault.jpg)](https://youtu.be/DQqXipq4QjU)

---

**Part-2** | Showcasing the "**WILD FIRE**" not being detected in "**Marsabit, Kenya**":

[![Part-2](https://img.youtube.com/vi/oPhWVyCRdOM/maxresdefault.jpg)](https://youtu.be/oPhWVyCRdOM)

---

**Part-3** | Showcasing the "**HEATWAVE**" being detected in "**Delhi, India**":

[![Part-3](https://img.youtube.com/vi/bJm9My4fuAI/maxresdefault.jpg)](https://youtu.be/bJm9My4fuAI)